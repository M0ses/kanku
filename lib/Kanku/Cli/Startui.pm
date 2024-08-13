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
package Kanku::Cli::Startui;

use MooseX::App::Command;
extends qw(Kanku::Cli);

command_short_description  'start an simple webserver to access web ui under http://localhost:5000';

command_long_description   '
This command starts an simple webserver to access web ui.
Use the URL http://localhost:5000

';

use Carp;
use File::Slurp;
use File::HomeDir;

sub run {
  my ($self)    = @_;
  my $logger    = $self->logger;
  my $hd        = File::HomeDir->my_home;
  my $pid_file  = "$hd/.kanku/ui.pid";

  if ( -f $pid_file ) {
    $logger->warn('WebUI already running!');
    $logger->info('*** Please run stopui before or connect to http://localhost:5000 ***');
    return 1;
  }

  my $pid = fork;

  if ( $pid == 0 ) {
    # autoflush
    local $| = 1;

    # remove pid_file if child die`s
    $SIG{__DIE__} = sub { unlink $pid_file };

    my $log_file = "$hd/.kanku/ui.log";

    local *STDOUT; ## no critic (Variables::RequireInitializationForLocalVars)
    local *STDERR; ## no critic (Variables::RequireInitializationForLocalVars)

    require Plack::Runner;

    open(STDOUT, '>>', $log_file) || croak("Could not open $log_file: $!");
    open(STDERR, '>>', $log_file) || croak("Could not open $log_file: $!");

    require Kanku;
    my $runner = Plack::Runner->new;
    $runner->run(Kanku->to_app);

    close STDOUT || croak("Could not close STDOUT: $!");
    close STDERR || croak("Could not close STDERR: $!");

    return 0;
  }

  write_file($pid_file, $pid);
  $logger->info("Started webserver with pid: $pid");
  $logger->info('Please connect to http://localhost:5000');

  return 0;
}

__PACKAGE__->meta->make_immutable;

1;
