package Kanku::ReleaseTools::Changelog;

use strict;
use warnings;
use Moose;
use YAML::PP;
use Build::Rpm;

with 'Kanku::ReleaseTools::Role';

has '+outfile' => (default => 'CHANGELOG.md');

has 'blog_releases' => (
  is      => 'rw',
  isa     => 'HashRef',
  lazy    => 1,
  default => sub {
    my ($self) = @_;
    my @files  = glob($self->blog_dir."/*/*/*/release-*/index.md");
    my %rnotes;

    my $pattern = '.*/release-(.*)/index.md';
    for my $f (@files) {
      print STDERR "Found file: $f\n" if $::ENV{DEBUG};
      if ( $f =~ m#$pattern#) {
	$rnotes{$1} = $f;
      }
    }
    return \%rnotes,
  },
);

has 'new_releases' => (
  is      => 'rw',
  isa     => 'ArrayRef',
  lazy    => 1,
  default => sub {
    my ($self) = @_;
    my @new_revs;
    my $changelog_rev = $self->find_latest_release_in_changelog;
    for my $r (@{$self->current_releases}) {
      if (&Build::Rpm::verscmp($r, $changelog_rev) > 0) {
	push @new_revs, $r;
      }
    }
    return \@new_revs;
  },
);

has 'current_releases' => (
  is      => 'rw',
  isa     => 'ArrayRef',
  lazy    => 1,
  default => sub {
    my ($self) = @_;
    my $rnotes = $self->blog_releases;
    return [sort { &Build::Rpm::verscmp($a, $b) } keys %{$rnotes}];
  },
);

has '_current_changelog_content' => (
  is      => 'rw',
  isa     => 'ArrayRef',
  lazy    => 1,
  default => sub {
    [$_[0]->git(0, 1, 'show', $_[0]->destination_branch.':'.$_[0]->outfile)]
  },
);

sub current_changelog_content{
  my ($self) = @_;
  my $b = $self->destination_branch;
  my @cl = @{$self->_current_changelog_content};
  return wantarray ? @cl : "@cl";
}

sub find_latest_release_in_changelog {
  my ($self) = @_;
  for ($self->current_changelog_content) {
    return $+{release} if (m/^# \[(?<release>\d+\.\d+\.\d+)\]/);
  }
}

sub write_new_changelog {
  my ($self, $log) = @_;
  my $fn = $self->outpath;
  open(my $f, '>', $fn) || die "Cannot open $fn: $!\n";
  print $f $log;
  close $f || die "Could not close $fn: $!\n";
  return $self->outfile;
}

sub create_new_changelog_entries {
  my ($self)   = @_;
  my $rnotes   = $self->blog_releases();
  my $log;
  for my $ver (@{$self->new_releases}) {
    my $yaml = YAML::PP::LoadFile($rnotes->{$ver});
    my $d    = $yaml->{data};
    my ($date, $time) = split(/\s+/, $yaml->{date});
    my $news = "# [$d->{release}] - $date\n\n";
    for my $section ('features', 'fixes') {
      next unless @{$d->{$section}||[]};
      $news .= '## '.$self->headers->{$section}."\n\n";
      for my $entry (@{$d->{$section}||[]}) {
        print STDERR "$entry\n" if $::ENV{DEBUG};
        $news .= $self->gen_entries($entry, 0);
      }
      $news .= "\n\n";
    }
    $log = $news . $log;
  }
  return $log;
}

1;
