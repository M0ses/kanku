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
package Kanku::Cli::db;    ## no critic (NamingConventions::Capitalization)

use MooseX::App::Command;
extends qw(Kanku::Cli);

with 'Kanku::Cli::Roles::Schema';
with 'Kanku::Roles::Logger';

use File::Path;
use File::HomeDir;
use File::Basename;
use DBIx::Class::Migration;

command_short_description 'Initialize database';

command_long_description '
This command can be used for database maintainance.

';

option 'server' => (
    isa           => 'Bool',
    is            => 'rw',
    documentation => 'Use database from system (/var/lib/kanku/db/kanku-schema.db)',
);

option 'devel' => (
    isa           => 'Bool',
    is            => 'rw',
    cmd_aliases   => 'd',
    documentation => 'Use database in your $HOME/.kanku/kanku-schema.db directory', ## no critic (ValuesAndExpressions::RequireInterpolationOfMetachars)
);

option 'dsn' => (
    isa           => 'Str',
    is            => 'rw',
    documentation => 'dsn for global database',
    lazy          => 1,
    default       => sub {
      return 'dbi:SQLite:dbname='.$_[0]->dbfile;
    },
);

option 'upgrade' => (
    isa           => 'Bool',
    is            => 'rw',
    cmd_aliases   => 'u',
    documentation => 'Run database upgrade',
);

option 'install' => (
    isa           => 'Bool',
    is            => 'rw',
    cmd_aliases   => 'i',
    documentation => 'Run database installation',
);

option 'status' => (
    isa           => 'Bool',
    is            => 'rw',
    cmd_aliases   => 's',
    documentation => 'Print status of database installation (Schema version and installed version)',
);

option 'dbfile' => (
  isa 	  => 'Str',
  is  	  => 'rw',
  lazy    => 1,
  builder => '_build_dbfile',
);
sub _build_dbfile {
  my ($self) = @_;
  return $self->server
    ? '/var/lib/kanku/db/kanku-schema.db'
    : $self->homedir.'/.kanku/kanku-schema.db';
}

option 'homedir' => (
  isa           => 'Str',
  is            => 'rw',
  documentation => 'home directory for user',
  lazy          => 1,
  builder       => '_build_homedir',
);
sub _build_homedir {
      return File::HomeDir->users_home($ENV{USER});
}

option 'share_dir' => (
  isa           => 'Str',
  is            => 'rw',
  documentation => 'directory where migrations and fixtures are stored',
  lazy          => 1,
  default       => '/usr/share/kanku',
);

option 'dbuser' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => [qw/U/],
  documentation => 'User to connect to database',
  lazy          => 1,
  default       => 'kanku',
);

option 'dbpass' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => [qw/P/],
  documentation => 'Password to connect to database',
  lazy          => 1,
  default       => q{},
);

has _dbdir => (
	isa 	=> 'Str',
	is  	=> 'rw',
	lazy	=> 1,
	builder => '_build__dbdir',
);
sub _build__dbdir {
  my ($self) = @_;
  return dirname($self->dbfile);
}

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

  # setup database if needed
  if ($self->install) {
    if (! -d $self->_dbdir) {
      $logger->debug('Creating _dbdir: '.$self->_dbdir);
      File::Path::make_path($self->_dbdir);
    }
    $migration->install_if_needed(default_fixture_sets => ['install']);
  } elsif ($self->upgrade) {
    $migration->upgrade();
  } elsif ($self->status) {
    $migration->status();
  } else {
    $self->logger->error('Please specify one of the commands (--install|--upgrade)');
  }

  return;
}

__PACKAGE__->meta->make_immutable();

1;
