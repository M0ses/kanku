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
package Kanku::Cli::rguest;

use MooseX::App::Command;
use Moose::Util::TypeConstraints;
extends qw(Kanku::Cli);

with 'Kanku::Cli::Roles::Remote';
with 'Kanku::Cli::Roles::RemoteCommand';
with 'Kanku::Cli::Roles::View';

use Try::Tiny;

use Kanku::YAML;

command_short_description  "list guests on your remote kanku instance";

command_long_description  "
This command lists guests on your remote kanku instance.

" . $_[0]->description_footer;

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

BEGIN {
  Kanku::Config->initialize;
}

sub run {
  my ($self) = @_;
  my $logger = $self->logger;

  #my $data = $self->_get_filtered_guest_list();
  #$self->view('rguest/list.tt', $data);
  return 0;
}

__PACKAGE__->meta->make_immutable;

1;
