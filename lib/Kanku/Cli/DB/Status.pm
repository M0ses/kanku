# Copyright (c) 2024 SUSE LLC
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
package Kanku::Cli::DB::Status;

use MooseX::App::Command;
extends qw(Kanku::Cli);

with 'Kanku::Cli::Roles::DB';

use DBIx::Class::Migration;

command_short_description 'Status of database';

command_long_description '
This command shows the current version of the database and the schema.

';

sub run {
  my ($self)  = @_;
  my $logger  = $self->logger;

  $logger->debug('Using dsn: '.$self->dsn);
  $logger->debug('Using share_dir: '.$self->share_dir);

  # prepare database setup
  my $migration = DBIx::Class::Migration->new(
    schema_class   => 'Kanku::Schema',
    schema_args	   => [$self->dsn, $self->dbuser, $self->dbpass],
    target_dir	   => $self->share_dir,
  );

  $migration->status();

  return;
}

__PACKAGE__->meta->make_immutable();

1;
