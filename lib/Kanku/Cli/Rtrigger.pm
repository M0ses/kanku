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
package Kanku::Cli::Rtrigger;

use MooseX::App::Command;
extends qw(Kanku::Cli);

with 'Kanku::Cli::Roles::Remote';
with 'Kanku::Cli::Roles::RemoteCommand';
with 'Kanku::Cli::Roles::View';

use Try::Tiny;
use JSON::XS;

command_short_description  'trigger a remote job or job group';

command_long_description   '
Trigger a specified job or job group on your remote instance.
Either job name or job group name is required.

';

option 'job' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases	=> 'j',
  documentation => '(*) Remote job name',
);

option 'job_group' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases	=> 'J',
  documentation => '(*) Remote job group name',
);

option 'config' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases	=> 'c',
  documentation => '(*) use given config for remote job. example: -c "[]"',
);

sub run {
  my ($self)  = @_;
  Kanku::Config->initialize;
  my $logger  = $self->logger;
  my $ret     = 0;

  if ( $self->job ) {
    try {
      my $kr = $self->connect_restapi();
      my $json = JSON::XS->new();
      my $data = {
        data     => $self->config || [],
        is_admin => $self->as_admin,
      };
      my $rdata = $kr->post_json(
        # path is only subpath, rest is added by post_json
        path => 'job/trigger/'.$self->job,
        data => $json->encode($data),
      );

      $self->view('rtrigger.tt', $rdata);
    } catch {
      $logger->error($_);
      $ret = 1;
    };
  } elsif ( $self->job_group) {
    try {
      my $kr = $self->connect_restapi();
      my $json = JSON::XS->new();
      my $data = {
	data     => $self->config || [],
	is_admin => 1,
      };
      my $rdata = $kr->post_json(
	# path is only subpath, rest is added by post_json
	path => 'job_group/trigger/'.$self->job_group,
	data => $json->encode($data),
      );

      $self->view('rtrigger.tt', $rdata);
    } catch {
      $logger->error($_);
      $ret = 1;
    };
  } else {
    $logger->error('You must at least specify a job name (<-j|--job>) or job group name (<-J|--job_group>) to trigger');
    $ret = 1;
  }

  return $ret;
}

__PACKAGE__->meta->make_immutable;

1;
