package Kanku::ReleaseTools::Role;

use strict;
use warnings;
use Moose::Role;

has 'release' => (
  is       => 'ro',
  isa      => 'Str',
);

has 'destination_branch' => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
);

has 'blog_dir' => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
);

has 'outdir' => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
);

has 'outfile' => (
  is       => 'ro',
  isa      => 'Str',
  required => 1,
);

has 'outpath' => (
  is       => 'ro',
  isa      => 'Str',
  lazy     => 1,
  default  => sub {
    my ($s) = @_;
    my $f = $s->outdir.'/'.$s->outfile;
    $f =~ s#/+#/#g;
    return $f
  },
);

has 'dry_run' => (
  is       => 'ro',
  isa      => 'Bool',
  default  => 0,
);

has 'debug' => (
  is       => 'ro',
  isa      => 'Bool',
  default  => 0,
);

has 'headers' => (
  is      => 'ro',
  isa     => 'HashRef',
  default => sub {
    return {
      warnings => '',
      features => 'FEATURES',
      fixes    => 'BUGFIXES',
      examples => '',
    };
  },
);

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
      $self->printlog("Found file: $f");
      if ( $f =~ m#$pattern#) {
	$rnotes{$1} = $f;
      }
    }
    return \%rnotes,
  },
);

sub printlog {
  print STDOUT "$_[1]\n" if $_[0]->debug;
};

sub git {
    my ($self, $verbose, $critical, @cmd) = @_;
    my $redirect=q{};# = ($verbose) ? '' ; ' 2>/dev/null'
    my $cmd = "\\git @cmd".$redirect;
    $self->printlog("Running command: '$cmd'");
    my @result = `$cmd`;
    if ($?) {
      warn "Failed to run command '$cmd': $?\n";
      if ($critical) {
        print "Please check if this was a critical error!\n";
        print "Would you like to proceed? [yN]\n";
	my $answer = <STDIN>;
	chomp($answer);
        if ($answer !~ /^y(es)?$/) {
	  die "Exiting ....\n";
	}
	print "Proceeding ...\n";
      }
    }
    return @result;
}


sub gen_entries {
  my ($self, $entry, $indent) = @_;
  if ((ref($entry)||q{}) eq 'ARRAY') {
    my $result = q{};
    for my $sub_entry (@{$entry}) {
      $result .= $self->gen_entries($sub_entry, $indent+2);
    }
    return $result;
  } else {
    return q{ } x $indent . "* $entry\n";
  }
}

sub current_branch {
  my ($self) = @_;
  my ($current_branch) = $self->git(0, 1, 'branch', '--show-current');
  chomp($current_branch);
  return $current_branch;
}

sub stash_and_commit {
  my ($self, $file, $msg) = @_;
  my $dst_branch          = $self->destination_branch;
  my $current_branch      = $self->current_branch;

  my $cmds=[
    ["add", $file],
    ["stash", "push", "-m", "'STASH: $msg'"],
    ["checkout", $self->destination_branch],
    ["commit", "-m", "'$msg'"],
    ["checkout", $current_branch],
  ];

  $self->git(0, 1, @{$_}) for (@{$cmds});

  return;
}

1;
