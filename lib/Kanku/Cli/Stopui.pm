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
package Kanku::Cli::Stopui;

use strict;
use warnings;

use MooseX::App::Command;
extends qw(Kanku::Cli);

use Try::Tiny;
use File::Slurp;
use File::HomeDir;

command_short_description  'stop local webserver';

command_long_description  '
This command stops the local webserver, providing the ui

';

sub run {
  my ($self)    = @_;
  my $logger    = $self->logger;
  my $hd        = File::HomeDir->my_home;
  my $pid_file  = "$hd/.kanku/ui.pid";
  my $ret       = 0;

  try {
    if (my $pid = read_file($pid_file)) {
      kill(9, $pid) || $logger->error("Error while killing $pid: $!");
      unlink($pid_file) || $logger->error("Error while deleting $pid_file: $!");
      $logger->info("Stopped webserver with pid: $pid");
    } else {
      $logger->warn('No pid file found.');
      $ret = 1;
    }
  }
  catch {
    $logger->error($_);
    $ret = 1;
  };
  return $ret;
}

1;
