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
package Kanku::Cli::Rworker::List;

use strict;
use warnings;

use Try::Tiny;
use JSON::XS;

use MooseX::App::Command;
extends qw(Kanku::Cli);

with 'Kanku::Cli::Roles::Remote';
with 'Kanku::Cli::Roles::RemoteCommand';
with 'Kanku::Cli::Roles::View';

command_short_description  'information about worker';

command_long_description <<'LONG_DESC';
Show information about the remote worker status

LONG_DESC

option '+format' => (default=>'view');

has template => (
  isa           => 'Str',
  is            => 'rw',
  default       => 'rworker.tt',
);


sub run {
  my ($self)  = @_;
  Kanku::Config->initialize();
  my $logger  = $self->logger;
  my $ret     = 0;
  my $kr      = $self->connect_restapi();
  my $data;

  try {
    $data = $kr->get_json(path => 'worker/list');
  } catch {
    $logger->error($_);
    $ret = 1;
  };

  $self->print_formatted($data);

  return $ret;
}

__PACKAGE__->meta->make_immutable;

1;
