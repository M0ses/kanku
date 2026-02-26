package Kanku::Util;

use strict;
use warnings;
use JSON::MaybeXS;

sub get_arch {
  open(my $uname, "uname -m|");
  my $arch = <$uname>;
  close($uname);
  chomp $arch;
  return $arch;
}

sub get_ipaddress {
  my ($self, $ifname) = @_;
  open(my $ipcmd, "\\ip -json address show $ifname|");
  my $ip = <$ipcmd>;
  close($ipcmd);
  my $json = decode_json($ip);
  return [
    $json->[0]->{addr_info}->[0]->{local},
    $json->[0]->{addr_info}->[0]->{prefixlen},
  ];
}

1;
