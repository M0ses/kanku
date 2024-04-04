package Kanku::ReleaseTools::ReleaseNotes;

use Moose;

use FindBin;

with 'Kanku::ReleaseTools::Role';

has '+release' => (required => 1);
has '+outfile' => (default => sub { 'RELEASE-NOTES-'.$self->release.'.md'});

sub create {
  my ($self, $yaml) = @_;
  my $data          = $yaml->{data};
  my $header        = {
    warnings => '',
    features => 'FEATURES',
    fixes    => 'BUGFIXES',
    examples => '',
  };

  my $content = {warnings=>$data->{warnings},examples=>$data->{examples}};

  for my $section ('features', 'fixes') {
    for my $entry (@{$data->{$section}||[]}) {
      $content->{$section} .= $self->gen_entries($entry, 0);
    }
  }

  for my $section ('warnings','features', 'fixes', 'examples') {
    if ($content->{$section}) {
      my $headline = ($header->{$section}) ? "## $header->{$section}\n" : q{};
      $content->{$section} = <<EOF;
$headline
$content->{$section}

EOF
    }
  }

  open(my $F, '>', $self->outpath) || die 'Could not open '.$self->outpath.": $!\n";
  print $F <<EOF;
# $yaml->{title}

$content->{warnings}$content->{features}$content->{fixes}$content->{examples}
EOF
  close $F || die 'Could not close '.$self->outpath.": $!\n";
  return $self->outfile;
}

1;
