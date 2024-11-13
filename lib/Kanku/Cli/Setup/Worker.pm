# Copyright (c) 2016 SUSE LLC
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
package Kanku::Cli::Setup::Worker;

use MooseX::App::Command;
extends qw(Kanku::Cli);

with 'Kanku::Cli::Roles::Schema';

use Carp;
use Cwd;
use DBIx::Class::Migration;
use Sys::Virt;
use Sys::Hostname;
use Net::Domain qw/hostfqdn/;

use Kanku::Schema;
use Kanku::Setup::Worker;

command_short_description  'Setup local environment as kanku worker';

command_long_description   '
Setup local environment as kanku worker.
';

option 'user' => (
    isa           => 'Str',
    is            => 'rw',
    documentation => 'User who will be running kanku',
);

option 'images_dir' => (
    isa           => 'Str',
    is            => 'rw',
    documentation => 'directory where vm images will be stored',
    default       => '/var/lib/libvirt/images',
);

option 'apiurl' => (
    isa           => 'Str',
    is            => 'rw',
    documentation => 'url to your obs api',
    default       => 'https://api.opensuse.org',
);

option 'dsn' => (
    isa           => 'Str',
    is            => 'rw',
    documentation => 'dsn for global database',
);

option 'ssl' => (
    isa           => 'Bool',
    is            => 'rw',
    lazy          => 1,
    documentation => 'Configure apache with ssl',
    default       => 0,
);

option 'apache' => (
    isa           => 'Bool',
    is            => 'rw',
    lazy          => 1,
    documentation => 'Configure apache',
    default       => 0,
);

option 'mq_host' => (
    isa           => 'Str',
    is            => 'rw',
    lazy          => 1,
    documentation => 'Host for rabbitmq (server setup only)',
    default       => 'localhost',
);

option 'mq_vhost' => (
    isa           => 'Str',
    is            => 'rw',
    lazy          => 1,
    documentation => 'VHost for rabbitmq (server setup only)',
    default       => '/kanku',
);

option 'mq_user' => (
    isa           => 'Str',
    is            => 'rw',
    lazy          => 1,
    documentation => 'Username for rabbitmq (server setup only)',
    default       => 'kanku',
);

option 'mq_pass' => (
    isa           => 'Str',
    is            => 'rw',
    lazy          => 1,
    documentation => 'Password for rabbitmq (server setup only)',
    builder       => '_build_mq_pass',
);

sub _build_mq_pass {
  # Create a random 12 letter alphanumeric password
  my @alphanumeric = ('a'..'z', 'A'..'Z', 0..9);
  my $pass = join q{}, map { $alphanumeric[rand @alphanumeric] } 0..12;
  return $pass
}
option 'interactive' => (
    isa           => 'Bool',
    is            => 'rw',
    lazy          => 1,
    cmd_aliases   => 'i',
    documentation => 'Interactive Mode - more choice/info how to configure your system',
    default       => 0,
);

option 'dns_domain_name' => (
    isa           => 'Str|Undef',
    is            => 'rw',
    lazy          => 1,
    documentation => 'DNS domain name to use in libvirt network configuration',
    default       => 'kanku.site',
);

option 'ovs_ip_prefix' => (
    isa           => 'Str|Undef',
    is            => 'rw',
    documentation => 'IP network prefix for openVSwitch setup (default 192.168.199)',
);

option 'host_interface' => (
    isa           => 'Str',
    is            => 'rw',
    documentation => 'Interface used for port forwarding.',
    default       => 'eth0',
);

sub run {
  my ($self)  = @_;
  my $logger  = $self->logger;

  # effective user id
  if ( $> != 0 ) { ## no critic (Variables::ProhibitPunctuationVars)
    $logger->fatal('Please start setup as root');
    return 1;
  }

  $logger->fatal('Not completly implemented! Use on your own risk!');
  $logger->warn('If you like to proceed type "yes" and press <ENTER>!');
  my $ask = <STDIN>;
  return 1 unless $ask =~ /^yes/i;
  my $setup = Kanku::Setup::Worker->new(
    images_dir      => $self->images_dir,
    apiurl          => $self->apiurl,
    _ssl            => $self->ssl,
    _apache         => $self->apache,
    _devel          => 0,
    mq_user         => $self->mq_user,
    mq_vhost        => $self->mq_vhost,
    mq_pass         => $self->mq_pass,
    dns_domain_name => $self->dns_domain_name,
    host_interface  => $self->host_interface,
  );
  $setup->ovs_ip_prefix($self->ovs_ip_prefix) if $self->ovs_ip_prefix;

  $setup->dsn($self->dsn) if $self->dsn;

  return $setup->setup();
}

#__PACKAGE__->meta->make_immutable();

1;
