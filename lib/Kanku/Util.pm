package Kanku::Util;

use strict;
use warnings;

sub get_arch {
  open(my $uname, "uname -p|");
  my $arch = <$uname>;
  close($uname);
  chomp $arch;
  return $arch;
}

1;
