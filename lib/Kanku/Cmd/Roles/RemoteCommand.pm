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
package Kanku::Cmd::Roles::RemoteCommand;

use Moose::Role;

has list => (
  traits        => [qw(Getopt)],
  isa           => 'Bool',
  is            => 'rw',
  cmd_aliases    => 'l',
  documentation => '(*) list <history|job|guest> overview',
);

has details => (
  traits        => [qw(Getopt)],
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'd',
  documentation => '(*) show details <job_id|job_name|guest_name>',
);

sub description_footer {
 "
All options marked with an asterisk (*) are subcommands.
";   
}

1;
