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
package Kanku::Cli::setup; ## no critic (NamingConventions::Capitalization)

use strict;
use warnings;

use MooseX::App::Command;
extends qw(Kanku::Cli);

with 'Kanku::Cli::Roles::Schema';
with 'Kanku::Roles::Logger';

use Path::Class qw/file dir/;
use File::HomeDir;
use Term::ReadKey;
use Cwd;
use DBIx::Class::Migration;
use Sys::Virt;
use Sys::Hostname;
use Net::Domain qw/hostfqdn/;
use Carp;

use Kanku::Schema;
use Kanku::Setup::Devel;
use Kanku::Setup::Server::Distributed;
use Kanku::Setup::Server::Standalone;
use Kanku::Setup::Worker;

command_short_description  'Setup local environment to work as server or developer mode.';

command_long_description "\nSetup local environment to work as server or developer mode.\n"
  . "Installation wizard which asks you several questions,\n"
  . "how to configure your machine.\n\n";

option 'server' => (
    isa           => 'Bool',
    is            => 'rw',
    cmd_aliases   => ['distributed'],
    documentation => 'Run setup in server mode',
);

option 'devel' => (
    isa           => 'Bool',
    is            => 'rw',
    documentation => 'Run setup in developer mode',
);

option 'worker' => (
    isa           => 'Bool',
    is            => 'rw',
    documentation => 'Run setup in worker mode',
);

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

option 'osc_user' => (
    isa           => 'Str',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'login user for obs api',
    lazy          => 1,
    default       => q{},
);

option 'osc_pass' => (
    isa           => 'Str',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'login password obs api',
    lazy          => 1,
    default       => q{},
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
    default       => sub {
       my @alphanumeric = ('a'..'z', 'A'..'Z', 0..9);
       my $pass = join q{}, map { $alphanumeric[rand @alphanumeric] } 0..12;
       return $pass
    },
);

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

option 'master' => (
    isa           => 'Str|Undef',
    is            => 'rw',
    documentation => 'IP address of the master server',
);

sub run {
  my ($self)  = @_;
  my $logger  = $self->logger;

  # effective user id
  if ( $> != 0 ) { ## no critic (Variables::ProhibitPunctuationVars)
    $logger->fatal('Please start setup as root');
    return 1;
  }

  ### Get information
  # ask for mode
  $self->_ask_for_install_mode() unless ($self->devel or $self->server or $self->worker);

  my $setup;

  if ($self->server) {
    $setup = Kanku::Setup::Server::Distributed->new(
      images_dir      => $self->images_dir,
      apiurl          => $self->apiurl,
      _ssl            => $self->ssl,
      _apache         => $self->apache,
      _devel          => 0,
      mq_user         => $self->mq_user,
      mq_vhost        => $self->mq_vhost,
      mq_pass         => $self->mq_pass,
      dns_domain_name => $self->dns_domain_name,
    );
    $setup->ovs_ip_prefix($self->ovs_ip_prefix) if $self->ovs_ip_prefix;
  } elsif ($self->devel) {
    $setup = Kanku::Setup::Devel->new(
      user            => $self->user,
      images_dir      => $self->images_dir,
      apiurl          => $self->apiurl,
      osc_user        => $self->osc_user,
      osc_pass        => $self->osc_pass,
      _ssl            => $self->ssl,
      _apache         => $self->apache,
      _devel          => 1,
      interactive     => $self->interactive,
      dns_domain_name => $self->dns_domain_name,
    );
  } elsif ($self->worker) {
    $setup = Kanku::Setup::Worker->new(
      master          => $self->master,
#      user            => $self->user,
#      images_dir      => $self->images_dir,
#      apiurl          => $self->apiurl,
#      osc_user        => $self->osc_user,
#      osc_pass        => $self->osc_pass,
#      _ssl            => $self->ssl,
#      _apache         => $self->apache,
#      _devel          => 1,
#      interactive     => $self->interactive,
#      dns_domain_name => $self->dns_domain_name,
    );
  } else {
    croak('No valid setup mode found');
  }

  $setup->dsn($self->dsn) if $self->dsn;

  return $setup->setup();
}

sub _ask_for_install_mode {
  my $self  = shift;

  print <<'EOF';
Please select installation mode :

(1) server
(2) devel
(3) worker

(9) Quit setup
EOF

  while (1) {
    my $answer = <STDIN>;
    chomp $answer;
    exit 0 if ( $answer == 9 );

    if ( $answer == 1 ) {
      $self->server(1);
      last;
    }

    if ( $answer == 2 ) {
      $self->devel(1);
      last;
    }

    if ( $answer == 3 ) {
      $self->worker(1);
      last;
    }
  }
  return;
}

__PACKAGE__->meta->make_immutable();

1;
