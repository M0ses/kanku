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
use Try::Tiny;
use Kanku::Config;

my $defaults =    {
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
  'Kanku::Cli::init' => {
    project => 'devel:kanku:images',
    package => 'openSUSE-Leap-15.6-JeOS',
    repository => 'images_leap_15_6',
    apiurl => 'https://api.opensuse.org/public',
  },
  'Kanku::Cli::lsi' => {
    apiurl => 'https://api.opensuse.org/public',
    project => 'devel:kanku:images',
  },
  'Kanku::Util::DoD' => {
    use_oscrrc => 0,
  },
  'Net::OBS::Client' => {
    credentials => {},
  },
  'Kanku::Setup::Devel' => {
    network_name => 'kanku-devel',
    dns_domain_name => 'kanku.devel',
  },
  'Kanku::Setup::Server::Distributed' => {
    network_name => 'kanku-ovs',
    dns_domain_name => 'kanku.ovs',
  },
  'Kanku::Setup::Server::Standalone' => {
    network_name => 'kanku-server',
    dns_domain_name => 'kanku.server',
  },
};

sub get {
  my ($self, $pkg, $var) = @_;
  my $cfg = {};
  try {
    $cfg = Kanku::Config->instance->cf;
  } catch {
    confess($_) unless $pkg =~ /^Kanku::Setup::/;
  };
  my $ret = {%{$defaults->{$pkg}||{}}};
  $ret = {%{$ret}, %{$cfg->{$pkg}}} if ref($cfg->{$pkg}) eq 'HASH';
  return $ret->{$var} if $var;
  return $ret;
}
__PACKAGE__->meta->make_immutable;
1;
