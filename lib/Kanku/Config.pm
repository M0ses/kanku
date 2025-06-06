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
package Kanku::Config;

use MooseX::Singleton;

use Kanku::File;

sub initialize {
  my ($self, %args) = @_;
  if ( $args{class} ) {
    with "Kanku::Roles::Config::$args{class}";
  } else {
    with 'Kanku::Roles::Config';
  }

  $self->file(Kanku::File::lookup_file($args{file})->stringify) if $args{file};

  return $self;
}

# TODO:
# Document why the following line is commented out
# (cannot make immutable as `with` statements are not execute
# at compile/start time)
#
#__PACKAGE__->meta->make_immutable;

1;
