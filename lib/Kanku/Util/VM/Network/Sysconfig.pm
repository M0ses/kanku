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
package Kanku::Util::VM::Network::Sysconfig;

use Moose;

with 'Kanku::Util::VM::Network::Role';

#
# Adapter for traditional SUSE/RHEL sysconfig network scripts
# (/etc/sysconfig/network).
#
sub name {
  return 'sysconfig';
}

sub tool_candidates {
  return qw(ifdown wicked ip);
}

#
# Interface restart via ifdown/ifup scripts.
#
sub restart {
  my ($self, $interface) = @_;
  $self->cmd("ifdown $interface;ifup $interface");
  return;
}

__PACKAGE__->meta->make_immutable;

1;
