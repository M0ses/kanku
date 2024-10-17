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
package Kanku::Cli::CA::Create;

use strict;
use warnings;

use MooseX::App::Command;
extends qw(Kanku::Cli);

with 'Kanku::Cli::Roles::Schema';

use Kanku::Setup::Server::Distributed;

command_short_description  'Kanku CA management.';

command_long_description "
Manage your local Kanku CA.
";

option 'force' => (
    isa           => 'Bool',
    is            => 'rw',
    cmd_aliases   => ['f'],
    documentation => 'Force overwrite of existing files',
);

option 'ca_path' => (
    isa           => 'Str',
    is            => 'rw',
    cmd_aliases   => ['p'],
    documentation => 'Local path to CA directory',
    default       => '/etc/kanku/ca'
);

option 'server' => (
    isa           => 'Bool',
    is            => 'rw',
    cmd_aliases   => ['s'],
    documentation => 'Create server cert for localhost',
    default       => 1,
);

sub run {
  my ($self)  = @_;
  my $logger  = $self->logger;
  if ($> != 0) { # EUID == 0
    $logger->error("Please start as root or use sudo!");
    return 1;
  }

  my $setup = Kanku::Setup::Server::Distributed->new(
    _ssl     => 1,
    ca_path  => path($self->ca_path),
    _apache  => 0,
  );
  $setup->_create_ca();
  $setup->_create_server_cert() if $self->server;
  $logger->error("CA password: ".$setup->ca_pass);
  return 0;
}

__PACKAGE__->meta->make_immutable();

1;
