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
package Kanku::Util::VM::Network::Wicked;

use Moose;
use Data::Dumper;

with 'Kanku::Util::VM::Network::Role';

#
# Adapter for openSUSE/SLES wicked managed networks.
# Primary tooling is 'wicked', with 'ifdown'/'ifup' for restarts.
#
sub name {
  return 'wicked';
}

sub tool_candidates {
  return qw(wicked ifdown ip);
}

#
# wicked ifstatus outputs lines like:
#   addr: ipv4 192.168.100.2/24
#
sub get_ipaddress {
  my ($self, $interface) = @_;
  my $bin    = $self->tool;
  my $logger = $self->logger;

  if ($bin->basename ne 'wicked') {
    return $self->generic_get_ipaddress($interface);
  }

  my $result = $self->cmd("LANG=C $bin ifstatus $interface 2>&1|cat");
  $logger->debug("  -- wicked ifstatus output:\n" . Dumper($result));

  my @lines = split(/\R/, $result->[0] || q{});
  my @addr  = map {
    ($_ =~ /^\s+addr:\s+ipv4\s+([0-9.]+)\//) ? $1 : ()
  } @lines;

  return $addr[0];
}

#
# Interface restart on wicked systems uses standard ifdown/ifup
# which delegates to the wicked backends.
#
sub restart {
  my ($self, $interface) = @_;
  $self->cmd("ifdown $interface;ifup $interface");
  return;
}

__PACKAGE__->meta->make_immutable;

1;
