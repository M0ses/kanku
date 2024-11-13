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
package Kanku::Cli::Setup::Devel;

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
use Kanku::Setup::Devel;

command_short_description  'Setup local environment to work in developer mode.';

command_long_description   '
Setup local environment to work in developer mode:
Installation wizard which asks you several questions,
how to configure your machine.

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

sub run {
  my ($self)  = @_;
  my $logger  = $self->logger;

  # effective user id
  if ( $> != 0 ) { ## no critic (Variables::ProhibitPunctuationVars)
    $logger->fatal('Please start setup as root');
    return 1;
  }

  my $setup = Kanku::Setup::Devel->new(
    user            => $self->user,
    images_dir      => $self->images_dir,
    apiurl          => $self->apiurl,
    osc_user        => $self->osc_user,
    osc_pass        => $self->osc_pass,
    interactive     => $self->interactive,
    dns_domain_name => $self->dns_domain_name,
  );

  $setup->dsn($self->dsn) if $self->dsn;

  return $setup->setup();
}

__PACKAGE__->meta->make_immutable();

1;
