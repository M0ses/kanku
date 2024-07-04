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
package Kanku::Cli::api;

use MooseX::App::Command;
extends qw(Kanku::Cli);

with 'Kanku::Cli::Roles::Remote';
with 'Kanku::Cli::Roles::RemoteCommand';
with 'Kanku::Cli::Roles::View';
with 'Kanku::Roles::Helpers';

use Try::Tiny;

command_short_description  "make (GET) requests to api with arbitrary (sub) uri";

command_long_description "
With this command you can send arbitrary queries to your remote kanku instance.

";

parameter 'uri' => (
  isa           => 'Str',
  is            => 'rw',
  required      => 1,
  documentation => 'uri to send request to',
);

option 'data' => (
  isa           => 'Str',
  is            => 'rw',
  documentation => 'data to send',
);

sub run {
  my ($self) = @_;
  my $ret    = 0;
  my $fmt    = $self->format;

  try {
    my $kr = $self->connect_restapi();
    $self->logger->debug("Raw data from API formatted as `$fmt`:");
    $self->print_formatted(
      $self->format,
      $kr->get_json(path=>$self->uri),
    );
  } catch {
    $self->logger->fatal($_);
    $ret = 1;
  };

  return $ret;
}

__PACKAGE__->meta->make_immutable;

1;
