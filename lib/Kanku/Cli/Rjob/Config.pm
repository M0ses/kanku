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
package Kanku::Cli::Rjob::Config;

use strict;
use warnings;

use MooseX::App::Command;
extends qw(Kanku::Cli);

with 'Kanku::Cli::Roles::Remote';
with 'Kanku::Cli::Roles::RemoteCommand';
with 'Kanku::Cli::Roles::View';

use Term::ReadKey;
use POSIX;
use Try::Tiny;
use Data::Dumper;

command_short_description  'show result of tasks from a specified remote job';

command_long_description   '
show result of tasks from a specified job on your remote instance

';

parameter 'config' => (
  isa           => 'Str',
  is            => 'rw',
  documentation => 'show config of remote job. Remote job name mandatory',
);


option '+format' => (default => 'view');

has template => (
  is   => 'rw',
  isa  => 'Str',
  default => 'rjob/details.tt',
);


sub run {
  my ($self)  = @_;
  my $logger  = $self->logger;
  my $ret     = 0;
  my $data;

  try {
    my $kr = $self->connect_restapi();
    $data = $kr->get_json( path => 'job/config/'.$self->config);
  } catch {
    $logger->fatal($_);
    $ret = 1;
  };

  $self->print_formatted($data->{config});

  return $ret;
}

__PACKAGE__->meta->make_immutable;

1;
