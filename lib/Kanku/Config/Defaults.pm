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
    network_name  => 'kanku-devel',
    pool_name     => 'default',
    image_type    => 'kanku',
    memory        => '2G',
    vcpu          => 1,
    mnt_dir_9p    => '/tmp/kanku',
    root_disk_bus => 'virtio',
  },
  'Kanku::Handler::CopyProfile' => {
    users => [],
    tasks => [],
  },
  'Kanku::Handler::Vagrant' => {
    base_url      => 'https://app.vagrantup.com',
    box           => 'opensuse/Tumbleweed.x86_64',
    box_version   => 'latest',
    login_user    => 'vagrant',
    login_pass    => 'vagrant',
  },
  'Kanku::Cli::init' => {
    project       => 'devel:kanku:images',
    package       => 'openSUSE-Leap-15.6-JeOS',
    repository    => 'images_leap_15_6',
    apiurl        => 'https://api.opensuse.org/public',
    template_path => '/etc/kanku/templates/cmd/init',
    template      => 'default',
    # Kanku::Handler::Vagrant
    box           => 'opensuse/Tumbleweed.x86_64',
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
  'Kanku::Config::GlobalVars' => {
    cache_dir  => "$::ENV{'HOME'}/.cache/kanku",
    images_dir => '/var/lib/libvirt/images',
    host_interface => 'eth0',
  },
  'Kanku::Roles::SSH' => {
    logverbosity    => 0,
    privatekey_path => q{},
    publickey_path  => q{},
    auth_type       => 'agent',
  },
};

sub get {
  my ($self, $pkg, $var) = @_;
  my $cfg = {};
  Kanku::Config->initialize();
  try {
    my $kc = Kanku::Config->instance();
    $cfg = $kc->cf;
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
