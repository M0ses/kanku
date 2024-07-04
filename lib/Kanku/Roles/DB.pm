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
package Kanku::Roles::DB;

use Moose::Role;

use Kanku::YAML;
use Kanku::Schema;

has schema => (
  is      => 'rw',
  isa     => 'Object',
  lazy    => 1,
  builder => '_build_schema',
);
sub _build_schema {
  my ($self) = @_;
  my $file   = '/etc/kanku/dancer/config.yml';
  my $cfg_yaml = Kanku::YAML::LoadFile($file);
  return
    Kanku::Schema->connect(
      $cfg_yaml->{plugins}->{DBIC}->{default}->{dsn}
    )
  ;
}

1;
