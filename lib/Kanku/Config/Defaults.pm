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
use Config;

my ($arch, undef) = split(/-/, $Config{archname});

my $home = $::ENV{HOME} || (getpwuid($<))[7];

my $defaults =    {
  'Kanku::Config::GlobalVars' => {
    cache_dir      => "$home/.cache/kanku",
    images_dir     => '/var/lib/libvirt/images',
    views_dir      => '/usr/share/kanku/views',
    host_interface => 'eth0',
    arch           => $arch,
    obsurl         => 'https://api.opensuse.org/public',
    base_url       => 'http://download.opensuse.org/repositories/',
  },
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
    vagrant_privkey => '-----BEGIN RSA PRIVATE KEY-----
MIIEogIBAAKCAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzI
w+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoP
kcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2
hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NO
Td0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcW
yLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQIBIwKCAQEA4iqWPJXtzZA68mKd
ELs4jJsdyky+ewdZeNds5tjcnHU5zUYE25K+ffJED9qUWICcLZDc81TGWjHyAqD1
Bw7XpgUwFgeUJwUlzQurAv+/ySnxiwuaGJfhFM1CaQHzfXphgVml+fZUvnJUTvzf
TK2Lg6EdbUE9TarUlBf/xPfuEhMSlIE5keb/Zz3/LUlRg8yDqz5w+QWVJ4utnKnK
iqwZN0mwpwU7YSyJhlT4YV1F3n4YjLswM5wJs2oqm0jssQu/BT0tyEXNDYBLEF4A
sClaWuSJ2kjq7KhrrYXzagqhnSei9ODYFShJu8UWVec3Ihb5ZXlzO6vdNQ1J9Xsf
4m+2ywKBgQD6qFxx/Rv9CNN96l/4rb14HKirC2o/orApiHmHDsURs5rUKDx0f9iP
cXN7S1uePXuJRK/5hsubaOCx3Owd2u9gD6Oq0CsMkE4CUSiJcYrMANtx54cGH7Rk
EjFZxK8xAv1ldELEyxrFqkbE4BKd8QOt414qjvTGyAK+OLD3M2QdCQKBgQDtx8pN
CAxR7yhHbIWT1AH66+XWN8bXq7l3RO/ukeaci98JfkbkxURZhtxV/HHuvUhnPLdX
3TwygPBYZFNo4pzVEhzWoTtnEtrFueKxyc3+LjZpuo+mBlQ6ORtfgkr9gBVphXZG
YEzkCD3lVdl8L4cw9BVpKrJCs1c5taGjDgdInQKBgHm/fVvv96bJxc9x1tffXAcj
3OVdUN0UgXNCSaf/3A/phbeBQe9xS+3mpc4r6qvx+iy69mNBeNZ0xOitIjpjBo2+
dBEjSBwLk5q5tJqHmy/jKMJL4n9ROlx93XS+njxgibTvU6Fp9w+NOFD/HvxB3Tcz
6+jJF85D5BNAG3DBMKBjAoGBAOAxZvgsKN+JuENXsST7F89Tck2iTcQIT8g5rwWC
P9Vt74yboe2kDT531w8+egz7nAmRBKNM751U/95P9t88EDacDI/Z2OwnuFQHCPDF
llYOUI+SpLJ6/vURRbHSnnn8a/XG+nzedGH5JGqEJNQsz+xT2axM0/W/CRknmGaJ
kda/AoGANWrLCz708y7VYgAtW2Uf1DPOIYMdvo6fxIB5i9ZfISgcJ/bbCUkFrhoH
+vq/5CIWxCPp0f85R4qxxQ5ihxJ0YDQT9Jpx4TMss4PSavPaBH3RXow5Ohe+bYoQ
NE5OgEXk2wVfZczCZpigBKbKZHNYcelXtTt/nP3rsCuGcM4h53s=
-----END RSA PRIVATE KEY-----
',
  },
  'Kanku::Handler::OBSCheck' => {
    base_url => 'https://cdn.opensuse.org/repositories/',
  },
  'Kanku::Cli::Init' => {
    project       => 'devel:kanku:images',
    package       => 'openSUSE-Leap-15.6-JeOS',
    repository    => 'images_leap_15_6',
    template_path => '/etc/kanku/templates/cmd/init',
    template      => 'default',
    # Kanku::Handler::Vagrant
    box           => 'opensuse/Tumbleweed.x86_64',
    domain_name   => 'kanku-vm',
  },
  'Kanku::Cli::Lsi' => {
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
  'Kanku::Roles::SSH' => {
    logverbosity    => 0,
    privatekey_path => q{},
    publickey_path  => q{},
    auth_type       => 'agent',
  },
};

has 'rcfile' => (
  is      => 'ro',
  isa     =>'Str',
  default => "$home/.kankurc",
);

has 'rc' => (
  is      => 'ro',
  isa     => 'Str',
  builder => '_build_rc',
);

sub _build_rc {
  my ($self) = @_;
  my $rc;
  return (-f $self->rcfile) ? Kanku::YAML::LoadFile($self->rcfile) : {};
}

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
