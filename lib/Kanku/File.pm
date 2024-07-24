package Kanku::File;

use strict;
use warnings;
use Cwd;
use Carp;
use File::Basename;

sub lookup_file {
  shift @_ if ref($_[0]);
  my ($file) = @_;
  croak("No file given.") unless $file;
  my $bn = basename($file);
  my $dn = dirname($file) || getcwd();
  $dn = File::Spec->catfile(getcwd(), $dn) unless substr($dn, 0, 1) eq q{/};
  my $fp = Cwd::realpath(File::Spec->catfile($dn, $bn));
  return $fp;
}

1;
