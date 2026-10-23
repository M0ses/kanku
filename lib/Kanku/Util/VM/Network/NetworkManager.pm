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
package Kanku::Util::VM::Network::NetworkManager;

use Moose;
use Data::Dumper;

with 'Kanku::Util::VM::Network::Role';

#
# Adapter for NetworkManager managed environments.
# Primary CLI is 'nmcli', falling back to 'ip'.
#
sub name {
  return 'NetworkManager';
}

sub tool_candidates {
  return qw(nmcli ip);
}

#
# nmcli device show outputs lines like:
#   IP4.ADDRESS[1]: 192.168.100.2/24
#
sub get_ipaddress {
  my ($self, $interface) = @_;
  my $bin    = $self->tool;
  my $logger = $self->logger;

  if ($bin->basename ne 'nmcli') {
    return $self->generic_get_ipaddress($interface);
  }

  my $result = $self->cmd("LANG=C $bin device show $interface 2>&1|cat");
  $logger->debug("  -- nmcli device show output:\n" . Dumper($result));

  my @lines = split(/\R/, $result->[0] || q{});
  my @addr  = map {
    $_ =~ qr{^IP4.ADDRESS\[1\]:\s+([\d.]+)/?.*$} ? $1 : ()
  } @lines;

  return $addr[0];
}

#
# Interface restart via nmcli device disconnect and connect.
#
sub restart {
  my ($self, $interface) = @_;
  $self->cmd(
    "nmcli device disconnect $interface;nmcli device connect $interface"
  );
  return;
}

__PACKAGE__->meta->make_immutable;

1;
