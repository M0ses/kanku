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
package Kanku::Cli::Doc;

use MooseX::App::Command;
extends qw(Kanku::Cli);

#with 'Kanku::Cli::Roles::VM';
#with 'Kanku::Cli::Roles::View';

#use Kanku::Util::VM;

command_short_description  'Show documenation for kanku libraries';

command_long_description '
This command shows documenation for kanku libraries
';

#option '+format' => (default=>'view');

#has template => (
#  is   => 'rw',
#  isa  => 'Str',
#  default => 'info.tt',
#);

parameter 'library_name' => (
  isa           => 'Str',
  is            => 'rw',
  required      => 1,
  documentation => 'name of library (e.g. Kanku::Handler).',
);


sub run {
  my ($self)  = @_;
  $::ENV{PERL5LIB} = join ':', @::INC;
  exec "perldoc", $self->library_name
}

__PACKAGE__->meta->make_immutable;

1;
