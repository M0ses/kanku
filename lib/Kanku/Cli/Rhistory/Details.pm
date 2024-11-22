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
package Kanku::Cli::Rhistory::Details;

use MooseX::App::Command;
extends qw(Kanku::Cli);

with 'Kanku::Cli::Roles::Remote';
with 'Kanku::Cli::Roles::View';

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

option '+format' => (default=>'view');

has template => (
  isa           => 'Str',
  is            => 'rw',
  default       => 'job.tt',
);

parameter 'job_id' => (
    is            => 'rw',
    isa           => 'Str',
    required      => 1,
    documentation => q[Job id to show details],
);

sub run {
  my ($self)  = @_;
  my $logger  =	$self->logger;

  $self->_details();

  return 0;
}

sub _details {
  my ($self) = @_;
  my $logger = $self->logger;

  my $kr;
  try {
    $kr = $self->connect_restapi();
  } catch {
    exit 1;
  };

  my $data = $kr->get_json(path => 'job/'.$self->job_id);

  $self->_truncate_result($data) if ! $self->full;

  $self->print_formatted($data);

  return;
}

sub _truncate_result {
  my ($self, $data) = @_;
  foreach my $task (@{$data->{subtasks}}) {
    if ( $task->{result}->{error_message} ) {
      my @lines = split /\n/, $task->{result}->{error_message};
      my $max_lines = 10;
      if ( @lines > $max_lines ) {
	my $ml = $max_lines;
	my @tmp;
	while ($max_lines) {
	  my $line = pop @lines;
	  push @tmp, $line;
	  $max_lines--;
	}
	push @tmp, q{}, '...',"TRUNCATING to $ml lines - use --full to see full output";
	$task->{result}->{error_message} = join "\n", reverse @tmp;
        $task->{result}->{error_message} .= "\n";
      }
    }
  }
  return;
}

__PACKAGE__->meta->make_immutable;

1;
