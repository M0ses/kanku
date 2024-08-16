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
package Kanku::Cli::Rguest::List;

use MooseX::App::Command;
extends qw(Kanku::Cli);

with 'Kanku::Cli::Roles::Remote';
with 'Kanku::Cli::Roles::RemoteCommand';
with 'Kanku::Cli::Roles::View';

use Term::ReadKey;
use Try::Tiny;

use Kanku::YAML;

command_short_description  "list guests on your remote kanku instance";

command_long_description   "
This command lists guests on your remote kanku instance matching the specified
filter.

Possible filters are:

* domain
* state
* host

";

option 'host' => (
  isa           => 'Str',
  is            => 'rw',
  documentation => 'filter list by host (wildcard .)',
);

option 'domain' => (
  isa           => 'Str',
  is            => 'rw',
  documentation => 'filter list by domain (wildcard .)',
);

option 'state' => (
  isa           => 'Int',
  is            => 'rw',
  cmd_aliases   =>  'S',
  documentation => 'filter list by state of domain',
);

option '+format' => (default => 'view');
has 'template' => (
  is            => 'rw',
  isa           => 'Str',
  default       => 'rguest/list.tt',
);

sub run {
  my $self  = shift;

  Kanku::Config->initialize;

  return $self->_list;
}

sub _list {
  my ($self) = @_;

  my $data = $self->_get_filtered_guest_list();

  $self->print_formatted($data);
}

sub _get_filtered_guest_list {
  my ($self) = @_;
  my $kr     = $self->connect_restapi();
  my $params = {};
  my @filters;
  push @filters, "host:".$self->host.".*" if $self->host;
  push @filters, "domain:".$self->domain.".*" if $self->domain;
  push @filters, "state:".$self->state if $self->state;
  $params->{filter} = \@filters if @filters;
  return $kr->get_json(path => "guest/list", params => $params);
}
__PACKAGE__->meta->make_immutable;

1;
