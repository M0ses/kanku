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
package Kanku::Cli::Verify;

use MooseX::App::Command;
extends qw(Kanku::Cli);

use Template;
use Carp;
use Try::Tiny;
use Kanku::Config;
use Kanku::Config::Defaults;
use Kanku::Util::VM::Image;

command_short_description  'verify gpg signature of KankuFile in your current working directory';

command_long_description '
This command verifies the gpg signature of the KankuFile in your current
working directory.
';

option 'kankufile' => (
  isa           => 'Str',
  is            => 'rw',
  documentation => 'Name of output file',
  cmd_aliases   => [qw/o F output/],
  lazy          => 1,
  default       => 'KankuFile',
);

sub run {
  my ($self)  = @_;
  Kanku::Config->initialize();
  my $ret     = 0;
  my $logger  = $self->logger;
  my $kf      = $self->kankufile;

  if ( -f $kf && -f "$kf.asc" ) {
    system(qw/gpg --verify/, "$kf.asc", $kf);
    $ret = $? >> 8;
  } else {
    $logger->error("Could not find $kf or $kf.asc");
    $ret = 99;
  }

  return $ret;
}

__PACKAGE__->meta->make_immutable;

1;
