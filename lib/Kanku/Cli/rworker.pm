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
package Kanku::Cli::rworker; ## no critic (NamingConventions::Capitalization)

use strict;
use warnings;

use Try::Tiny;
use JSON::XS;

use MooseX::App::Command;
extends qw(Kanku::Cli);

with 'Kanku::Roles::Logger';
with 'Kanku::Cli::Roles::Remote';
with 'Kanku::Cli::Roles::RemoteCommand';
with 'Kanku::Cli::Roles::View';

command_short_description  'information about worker';

command_long_description "Show information about the remote worker status\n\n"
  . $_[0]->description_footer;

option 'list' => (
  is            => 'rw',
  isa           => 'Bool',
  cmd_aliases	=> 'l',
  documentation => 'list all worker information',
);

BEGIN {
  Kanku::Config->initialize();
}

sub run {
  my ($self)  = @_;
  my $logger  = $self->logger;
  my $ret     = 0;

  if ( $self->list) {
    my $kr;
    try {
      my $kr = $self->connect_restapi();
      my $data = $kr->get_json(path => 'worker/list');
      $self->view('rworker.tt', $data);
    } catch {
      $logger->error($_);
      $ret = 1;
    };
  } else {
    $logger->error('You must at least add the option "-l" to list information about worker');
    $ret = 1;
  }
  return $ret;
}

__PACKAGE__->meta->make_immutable;

1;
