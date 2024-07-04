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
package Kanku::Cli;

use MooseX::App qw(Color BashCompletion);
use Moose::Util::TypeConstraints;

with 'Kanku::Roles::Logger';
with 'Kanku::Cli::Roles::View';

option 'traceback'  => (
  is            => 'rw',
  isa           => 'Bool',
  default       => 0,
  cmd_aliases   => ['t'],
  documentation => 'print stacktrace on die',
);

enum 'LogLevel' => [qw/FATAL ERROR WARN INFO DEBUG TRACE/];
option 'loglevel'  => (
  is            => 'rw',
  isa           => 'Str',
  cmd_aliases   => [qw/ll log_level log-level/],
  documentation => 'set log level',
);

enum 'OutputFormat' => [qw/json dumper yaml none pjson/];
option 'format' => (
  isa           => 'OutputFormat',
  is            => 'rw',
  cmd_aliases   => [qw/of output-format output_format/],
  documentation => 'output format',
  default       => 'dumper'
);

app_exclude 'Kanku::Cli::Roles';

__PACKAGE__->meta->make_immutable();

1;
