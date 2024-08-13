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
package Kanku::Cli::Rhistory::List;

use MooseX::App::Command;
extends qw(Kanku::Cli);


with 'Kanku::Cli::Roles::Remote';
with 'Kanku::Cli::Roles::RemoteCommand';
with 'Kanku::Cli::Roles::View';

use POSIX qw/floor/;
use Try::Tiny;

command_short_description  'list job history on your remote kanku instance';

command_long_description   "
list job history on your remote kanku instance

";

option 'full' => (
  isa           => 'Bool',
  is            => 'rw',
  documentation => 'show full output of error messages',
);

option 'limit' => (
  isa           => 'Int',
  is            => 'rw',
  documentation => 'limit output to X rows',
);

option 'page' => (
  isa           => 'Int',
  is            => 'rw',
  documentation => 'show page X of job history',
);

option 'state' => (
  isa           => 'ArrayRef',
  is            => 'rw',
  documentation => 'filter for states',
);

option 'latest' => (
  isa           => 'Bool',
  is            => 'rw',
  documentation => 'show only the latest result of each job',
);

option 'job_name' => (
  isa           => 'Str',
  is            => 'rw',
  documentation => 'filter list by job_name (wildcard %)',
);

option 'worker' => (
  isa           => 'Str',
  is            => 'rw',
  documentation => 'filter list by workerinfo (wildcard %)',
);

sub run {
  my ($self)  = @_;
  my $logger  =	$self->logger;

  $self->_list();

  return 0;
}

sub _list {
  my $self = shift;
  my $params;
  my $kr;
  try {
	$kr = $self->connect_restapi();
  } catch {
	exit 1;
  };
  $params = {
    limit    => $self->limit || 10,
    page     => $self->page || 1,
    state    => $self->state || [],
    job_name => $self->job_name || q{},
  };
  $params->{filter} = "worker:" . $self->worker if ($self->worker);
  $params->{show_only_latest_results} = 1 if $self->latest;

  my $data = $kr->get_json( path => 'jobs/list' , params => $params );

  foreach my $job ( @{$data->{jobs}} ) {
    if ( $job->{start_time} ) {
      my $et = ($job->{end_time}) ? $job->{end_time} : time;
      $job->{duration} = duration( $et - $job->{start_time});
    } else {
      $job->{duration} = 'Not started yet';
    }
  }
  $self->view('jobs.tt', $data);
  return 0;
};

sub duration {
  my ($t) = @_;
  # Calculate hours
  my $h = floor($t/(60*60));
  # Remove complete hours
  $t = $t - $h*60*60;
  # Calculate minutes
  my $m = floor($t/60);
  # Calculate seconds
  my $s = $t - ( $m * 60 );

  return sprintf '%02d:%02d:%02d', $h, $m, $s;
}

__PACKAGE__->meta->make_immutable;

1;
