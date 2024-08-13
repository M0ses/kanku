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
package Kanku::Cli::Rjob::Details;

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

command_long_description   "
show result of tasks from a specified job on your remote instance

";

option 'config' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases	=> 'c',
  documentation => '(*) show config of remote job. Remote job name mandatory',
);

option 'filter' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases	=> 'f',
  documentation => 'filter job names by pattern',
);

sub run {
  my ($self)  = @_;
  my $logger  = $self->logger;
  my $ret     = 0;

  try {
    my $kr = $self->connect_restapi();
    my $data = $kr->get_json( path => 'gui_config/job');
    my $job_config;
    while ( my $j = shift @{$data->{config}}) {
      if ( $j->{job_name} eq $self->details ) {
	$job_config = $j;
	last;
      }
    }
    $self->print_formatted($self->format, $job_config);
  } catch {
    $logger->fatal($_);
    $ret = 1;
  };

  return $ret;
}

__PACKAGE__->meta->make_immutable;

1;
