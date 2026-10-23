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
package Kanku::Util::VM::Network::Generic;

use Moose;

with 'Kanku::Util::VM::Network::Role';

#
# Fallback adapter when no specific network management daemon is active.
# Uses basic iproute2 commands for all network operations.
#
sub name {
  return 'ip';
}

sub tool_candidates {
  return qw(ip);
}

#
# Generic interface toggle using ip link dev <if> down/up.
#
sub restart {
  my ($self, $interface) = @_;
  $self->cmd("ip link dev $interface down;ip link dev $interface up");
  return;
}

__PACKAGE__->meta->make_immutable;

1;
