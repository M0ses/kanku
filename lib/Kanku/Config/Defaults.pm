# Copyright (c) 2023 SUSE LLC
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
package Kanku::Config::Defaults;

use Moose;

use Kanku::Config;

my $defaults = {
  'Kanku::Util::IPTables' =>
  {
    'iptables_chain' => 'KANKU_HOSTS',
    'start_port'     => 49001,
  },
  'Kanku::Handler::CreateDomain' => {
    network_name => 'kanku-devel',
    pool_name    => 'default',
  },
  'Kanku::Handler::CopyProfile' => {
    users => [],
    tasks => [],
  },
};

sub get {
  my ($self, $pkg, $var) = @_;
  my $cfg = Kanku::Config->instance->cf;
  return ($cfg->{$pkg} || $defaults->{$pkg})  unless $var;
  return $cfg->{$pkg}->{$var} || $defaults->{$pkg}->{$var};
}
__PACKAGE__->meta->make_immutable;
1;
