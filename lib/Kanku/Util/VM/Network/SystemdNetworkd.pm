# Copyright (c) 2026 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program (see the file COPYING); if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#
package Kanku::Util::VM::Network::SystemdNetworkd;

use Moose;
use Data::Dumper;

with 'Kanku::Util::VM::Network::Role';

#
# Adapter for systemd-networkd managed networks.
# Primary CLI is 'networkctl', falling back to 'ip'.
#
sub name {
  return 'systemd-networkd';
}

sub tool_candidates {
  return qw(networkctl ip);
}

#
# systemd-networkd status outputs lines like:
#   Address: 192.168.101.2 (DHCP4 via 192.168.101.1)
# or just:
#   Address: 192.168.101.2
# If networkctl is not available, we fall back to generic ip tool.
#
sub get_ipaddress {
  my ($self, $interface) = @_;
  my $bin    = $self->tool;
  my $logger = $self->logger;

  if ($bin->basename ne 'networkctl') {
    return $self->generic_get_ipaddress($interface);
  }

  my $result = $self->cmd("LANG=C $bin status $interface 2>&1|cat");
  $logger->debug("  -- networkctl status output:\n" . Dumper($result));

  my @lines = split(/\R/, $result->[0] || q{});
  my @addr  = map {
    $_ =~ qr{^\s*Address:\s+([\d.]+)(\s.*)?$} ? $1 : ()
  } @lines;

  return $addr[0];
}

#
# Interface restart via networkctl down / up commands.
#
sub restart {
  my ($self, $interface) = @_;
  my $bin = $self->tool;

  if ($bin->basename eq 'networkctl') {
    $self->cmd("networkctl down $interface;networkctl up $interface");
  } else {
    $self->cmd(
      "ip link dev $interface down;ip link dev $interface up"
    );
  }
  return;
}

__PACKAGE__->meta->make_immutable;

1;
