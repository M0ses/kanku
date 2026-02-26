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
package Kanku::Util::NSpawn::Console;

use Moose;
use Carp;
use IO::Pty;
use Fcntl;
use POSIX qw(:termios_h :unistd_h);
use Time::HiRes qw/usleep/;

use Net::DBus;

use Kanku::Config::Defaults;

with 'Kanku::Roles::Logger';

has ['domain_name', 'login_user', 'login_pass', 'log_file'] => (is => 'rw', isa => 'Str');
has 'prompt' => (is => 'rw', isa => 'Str', default => 'Kanku-prompt: ');
has 'prompt_regex' => (is => 'rw', isa => 'Object', default => sub { qr/\RKanku-prompt:\s+/smx });
has 'user_is_logged_in' => (is => 'rw', isa => 'Bool', default => 0);
has 'console_connected' => (is => 'rw', isa => 'Bool', default => 0);

has ['cmd_timeout'] => (is => 'rw', isa => 'Int', default => 600);
has ['login_timeout'] => (is => 'rw', isa => 'Int', default => 300);
has 'job_id' => (is => 'rw', isa => 'Int|Undef');

has 'context2env' => (
  is      => 'rw',
  isa     => 'HashRef',
  lazy    => 1,
  default => sub { {} },
);

has '_pty_master' => (is => 'rw', isa => 'IO::Pty');
has '_bus' => (is => 'rw', isa => 'Object');

sub init {
  my ($self) = @_;
  my $logger = $self->logger;

  $self->_bus(Net::DBus->system);

  my $machine_name = $self->domain_name;
  my $machine_service = $self->_bus->get_service("org.freedesktop.machine1");
  my $machine_manager = $machine_service->get_object(
    "/org/freedesktop/machine1",
    "org.freedesktop.machine1.Manager"
  );

  my ($fd, $pty_path) = $machine_manager->OpenMachineShell($machine_name, undef, '/bin/sh', [], []);
  $logger->debug("Opened shell session for machine '$machine_name', PTY: $pty_path");

  my $pty_master = IO::Pty->new;
  $pty_master->fdopen($fd, 'r+');

  $self->_pty_master($pty_master);

  $self->console_connected(1);

  return 0;
}

sub _read_until {
  my ($self, $timeout, $regex) = @_;
  my $logger = $self->logger;
  my $pty = $self->_pty_master;

  my $buffer = '';
  my $matched = 0;
  my $start_time = time;

  my $flags = fcntl($pty, F_GETFL, 0);
  fcntl($pty, F_SETFL, $flags | O_NONBLOCK);

  while (time - $start_time < $timeout) {
    my $ready;
    vec($ready, fileno($pty), 1) = 1;
    my $n = select($ready, undef, undef, 0.5);

    if ($n > 0) {
      my $data;
      my $bytes = sysread($pty, $data, 1024);
      if ($bytes > 0) {
        $buffer .= $data;
        $logger->trace("Read buffer: '$buffer'");
        if ($buffer =~ /$regex/) {
          $matched = 1;
          last;
        }
      }
    }

    last if ($matched);
  }

  fcntl($pty, F_SETFL, $flags);

  return ($buffer, $matched);
}

sub _send {
  my ($self, $data) = @_;
  my $pty = $self->_pty_master;
  my $bytes = syswrite($pty, $data);
  die "syswrite failed: $!" unless defined($bytes);
  $self->logger->trace("Sent: '$data' (bytes: $bytes)");
  return $bytes;
}

sub login {
  my ($self) = @_;
  my $logger = $self->logger;
  my $timeout = $self->login_timeout;

#  my $user = $self->login_user;
#  my $password = $self->login_pass;
#
#  die "No login_user found in config" if !$user;
#  die "No login_pass found in config" if !$password;
#
#  $logger->debug("Waiting for login prompt or shell (timeout: $timeout)");
#  my ($buffer, $matched) = $self->_read_until($timeout, qr/(login:|\$ |# )/);
#  $logger->debug("buffer:\n$buffer\n$matched\n");
#
#  if ($buffer =~ /login:/) {
#    $logger->debug("Found login prompt, sending username: '$user'");
#    $self->_send("$user\n");
#
#    ($buffer, $matched) = $self->_read_until(10, qr/Password:/);
#    die "No password prompt seen" unless $matched;
#
#    $logger->debug("Found password prompt, sending password");
#    $self->_send("$password\n");
#
#    ($buffer, $matched) = $self->_read_until(10, qr/(Login incorrect|Permission denied)/);
#    if ($buffer =~ /Login incorrect|Permission denied/) {
#      die "Login failed: Invalid credentials";
#    }
#
#    ($buffer, $matched) = $self->_read_until(10, qr/(#|\$)\s*$/);
#  } elsif ($buffer =~ /(\$ |# )/) {
#    $logger->debug("Already at shell prompt, using existing session");
#  }
#
#  die "No shell prompt seen after login" unless $matched;
#
#  $logger->debug("Logged in successfully");

  $self->_send("export TERM=dumb\n");
  usleep(100000);

  while (my ($env, $val) = each %{$self->context2env}) {
    $val =~ s/'/\\'/g;
    $self->_send("export $env='$val'\n");
    usleep(50000);
  }

  $self->_send("export PS1=\"" . $self->prompt . "\"\n");

  my ($buffer, $matched) = $self->_read_until($timeout, $self->prompt_regex);

  $self->user_is_logged_in(1);

  return 0;
}

sub logout {
  my ($self) = @_;
  my $logger = $self->logger;

  $logger->debug("Logging out");
  $self->_send("exit\n");
  usleep(500000);

  $self->user_is_logged_in(0);

  if ($self->_pty_master) {
    close($self->_pty_master);
  }

  return 0;
}

sub cmd {
  my $self    = shift;
  my @cmds    = @_;
  my $results = [];
  my $logger  = $self->logger;

  my $timeout = $self->cmd_timeout;

  foreach my $cmd (@cmds) {
    $logger->debug("Executing command: '$cmd' (timeout: $timeout)");

    $self->_send("export TERM=dumb\n");
    $self->_send("export LANG=C\n");
    $self->_send("$cmd\n");
    usleep(100000);

    my ($buffer, $matched) = $self->_read_until($timeout, $self->prompt_regex);

    if (!$matched) {
      die "Timeout while waiting for prompt after command '$cmd'";
    }

    my @lines = split(/\r?\n/, $buffer);
    pop @lines while @lines && $lines[-1] =~ /^\s*$/;
    pop @lines if @lines && $lines[-1] eq $self->prompt;

    my $output = join("\n", @lines);
    $logger->trace("Command output: '$output'");

    $self->_send("echo \$?\n");
    usleep(100000);

    my ($rc_buffer, $rc_matched) = $self->_read_until($timeout, $self->prompt_regex);
    my @rc_lines = split(/\r?\n/, $rc_buffer);
    my $rc = 0;
    for my $line (@rc_lines) {
      if ($line =~ /^\s*(\d+)\s*$/) {
        $rc = $1;
        last;
      }
    }

    if ($rc) {
      $logger->warn("Command '$cmd' failed with return code '$rc'");
    } else {
      $logger->debug("Command '$cmd' succeeded");
    }

    push @$results, $output;
  }

  return $results;
}

sub get_ipaddress {
  my ($self, %opts) = @_;
  my $logger = $self->logger;

  croak 'Please specify an interface!' unless $opts{interface};
  croak 'Please specify a timeout!' unless $opts{timeout};

  if (!$self->user_is_logged_in) {
    $logger->debug("User not logged in. Trying to login");
    $self->login;
  }

  my $wait = $opts{timeout};
  my $ipaddress;

  while ($wait > 0) {
    my $result = $self->cmd("ip addr show $opts{interface} 2>/dev/null | grep 'inet ' | awk '{print \$2}' | cut -d/ -f1");
    my $output = $result->[0] // '';
    $logger->trace("ip addr output: '$output'");

    if ($output =~ /(\d+\.\d+\.\d+\.\d+)/) {
      $ipaddress = $1;
      last;
    }

    $logger->debug("Could not get IP address, waiting another $wait seconds");
    $wait--;
    sleep 1;
  }

  if (!$ipaddress) {
    croak "Could not get IP address for interface $opts{interface} within $opts{timeout} seconds";
  }

  return $ipaddress;
}

__PACKAGE__->meta->make_immutable;

1;
