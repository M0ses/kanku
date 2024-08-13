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
package Kanku::Cli::Retrigger;

use MooseX::App::Command;
extends qw(Kanku::Cli);

with 'Kanku::Cli::Roles::Remote';
with 'Kanku::Cli::Roles::RemoteCommand';
with 'Kanku::Cli::Roles::View';

use Try::Tiny;

command_short_description  'retrigger a remote job given by id';

command_long_description  "
This command retriggers a specified job on your remote instance

";

option 'job' => (
  isa           => 'Int',
  is            => 'rw',
  cmd_aliases	=> 'j',
  documentation => '(*) Remote job id - mandatory',
);

sub run {
  my ($self) = @_;
  my $logger = $self->logger;
  my $ret    = 0;

  if (!$self->job) {
    $logger->error('You must at least specify a job name to trigger');
    return 1;
  }

  try {
    my $kr = $self->connect_restapi();
    my $rdata = $kr->post_json(
      # path is only subpath, rest is added by post_json
      path => 'job/retrigger/'.$self->job,
      data => {is_admin => 1},
    );

    $self->view('retrigger.tt', $rdata);
  } catch {
    $logger->fatal($_);
    $ret = 1;
  };

  return $ret;
}

__PACKAGE__->meta->make_immutable;

1;
