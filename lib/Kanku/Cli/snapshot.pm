# Copyright (c) 2022 SUSE LLC
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
package Kanku::Cli::snapshot; ## no critic (NamingConventions::Capitalization)

use strict;
use warnings;

use MooseX::App::Command;
extends qw(Kanku::Cli);

use Kanku::Util::VM;
use Net::IP;

use Kanku::Job;
use Kanku::Config;

with 'Kanku::Roles::SSH';
with 'Kanku::Cli::Roles::VM';

command_short_description  'manage snapshots for kanku vms';

command_long_description  'manage snapshots for kanku vms';

option 'create' => (
  isa           => 'Bool',
  is            => 'rw',
  cmd_aliases   => 'c',
  documentation => 'create snapshot',
);

option 'revert' => (
  isa           => 'Bool',
  is            => 'rw',
  cmd_aliases   => 'R',
  documentation => 'revert snapshot',
);

option 'remove' => (
  isa           => 'Bool',
  is            => 'rw',
  cmd_aliases   => 'r',
  documentation => 'remove snapshot',
);

option 'list' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'l',
  documentation => 'list snapshots',
);

option 'name' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'n',
  documentation => 'name of snapshot',
  default       => 'current',
);

sub run {
  my ($self) = @_;
  my $logger = $self->logger;
  my $cfg    = $self->cfg;
  my $vm     = Kanku::Util::VM->new(
                 domain_name   => $self->domain_name,
                 snapshot_name => $self->name,
		 login_user    => $self->cfg->{login_user} || 'root',
		 login_pass    => $self->cfg->{login_pass} || 'kankudai',
	       );

  if ($self->create) {
    $vm->create_snapshot;
  } elsif ($self->remove) {
    $vm->remove_snapshot;
  } elsif ($self->revert) {
    $vm->revert_snapshot;
  } elsif ($self->list) {
    for my $domss ($vm->list_snapshots) {
      print STDOUT $domss->get_name . "\n";
    }
  } else {
    $logger->warn('Please specify a command. Run "kanku help snapshot" for further information.');
  }
}

__PACKAGE__->meta->make_immutable;

1;

