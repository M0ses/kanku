# Copyright (c) 2015 SUSE LLC
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
package Kanku::Util::NSpawn;

use Moose;

use Net::IP;
use Net::DBus;
use Try::Tiny;
use Path::Tiny;
use XML::XPath;

use Expect;
use Template;

with 'Kanku::Roles::Logger';

use Kanku::Util;

has '_bus' => (
  is => 'rw',
  isa => 'Object',
  builder => '_build_bus',
);

sub _build_bus {return Net::DBus->system;}

sub list_machines {
  my ($self) = @_;

  my $service = $self->_bus->get_service("org.freedesktop.machine1");
  my $manager = $service->get_object("/org/freedesktop/machine1", "org.freedesktop.machine1.Manager");

  my $machines = $manager->ListMachines();

  return $machines;
}

sub machine_exists {
  my ($self, $name) = @_;
  my @all_by_name = map {$_->[0]} @{$self->list_machines};

  return scalar(grep {$_ eq $name} @all_by_name);
}

1;
