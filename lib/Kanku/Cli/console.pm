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
package Kanku::Cli::console;     ## no critic (NamingConventions::Capitalization)

use MooseX::App::Command;
extends qw(Kanku::Cli);

command_short_description  'Open a serial console to vm';

command_long_description '
With this command you can open a serial console to the domain specified
(as domain_name) in your KankuFile.

';

with 'Kanku::Roles::Logger';
with 'Kanku::Cli::Roles::VM';

option 'virt_uri' => (
  is     => 'rw',
  isa    => 'Str',
  lazy   => 1,
  default => 'qemu:///system',
  documentation => 'libvirt connection uri',
  cmd_aliases   => [qw/v virt-uri/],
);

sub run {
  my ($self) = @_;
  my $cmd    = 'virsh -c '.$self->virt_uri.' console '.$self->domain_name;

  system $cmd;

  $self->logger->error("Failed to execute '$cmd'") if $?;

  return $? >> 8;
}

__PACKAGE__->meta->make_immutable;

1;
