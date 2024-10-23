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
package Kanku::Cli::Roles::DB;

use strict;
use warnings;
use MooseX::App::Role;

use Path::Tiny;

use Kanku::YAML;

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

option 'dbfile' => (
  isa     => 'Str',
  is      => 'rw',
  lazy    => 1,
  builder => '_build_dbfile',
);
sub _build_dbfile {
  my ($self) = @_;
  return $self->server
    ? '/var/lib/kanku/db/kanku-schema.db'
    : path($self->homedir, qw/.kanku kanku-schema.db/)->stringify;
}

option 'homedir' => (
  isa           => 'Str',
  is            => 'rw',
  documentation => 'home directory for user',
  lazy          => 1,
  builder       => '_build_homedir',
);
sub _build_homedir {
  return Kanku::Helpers->my_home;
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
        isa     => 'Str',
        is      => 'rw',
        lazy    => 1,
        builder => '_build__dbdir',
);
sub _build__dbdir {
  my ($self) = @_;
  return path($self->dbfile)->dirname;
}
with 'Kanku::Cli::Roles::Schema';

1;
