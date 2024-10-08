# Copyright (c) 2015 SUSE LLC
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
package Kanku::Roles::Daemon;

use Moose::Role;

use Carp;
use Try::Tiny;
use Path::Tiny;
use Getopt::Long;
use POSIX ':sys_wait_h';
use Data::Dumper;
use JSON::XS;
use Sys::Hostname;
use Net::Domain qw/hostfqdn/;

use Kanku::Config;
use Kanku::Airbrake;
use Kanku::NotifyQueue;

with 'Kanku::Roles::Logger';

requires 'run';

has daemon_options => (
  is      => 'rw',
  isa     => 'HashRef',
  lazy    => 1,
  builder => '_build_daemon_options',
);
sub _build_daemon_options {
  my ($self) = @_;
  my $opts = {};
  GetOptions(
    $opts,
    'stop',
    'foreground|f',
   ) || croak($self->print_usage());
   return $opts;
}

has daemon_basename => (
  is      => 'rw',
  isa     => 'Str',
  builder => '_build_daemon_basename',
);
sub _build_daemon_basename {
  return path($0)->basename;
}

has run_dir => (
  is => 'rw',
  isa => 'Object',
  builder => '_build_run_dir',
);
sub _build_run_dir {
    return path('/run/kanku');
}

has pid_file => (
  is      => 'rw',
  isa     => 'Object',
  lazy    => 1,
  builder => '_build_pid_file',
);
sub _build_pid_file {
  my ($self) = @_;
  path($self->run_dir,$self->daemon_basename.'.pid');
}

has shutdown_file => (
  is      => 'rw',
  isa     => 'Object',
  lazy    => 1,
  builder => '_build_shutdown_file',
);
sub _build_shutdown_file {
  my ($self) = @_;
  path($self->run_dir,$self->daemon_basename.'.shutdown');
}

has airbrake => (
  is      => 'rw',
  isa     => 'Object',
  lazy    => 1,
  builder => '_build_airbrake',
);
sub _build_airbrake { return Kanku::Airbrake->instance(); }

has notify_queue => (
  is      => 'rw',
  isa     => 'Object',
  lazy    => 1,
  builder => '_build_notify_queue',
);
sub _build_notify_queue {
  my ($self) = @_;
  $self->logger->debug("self->shutdown_file: ".$self->shutdown_file);
  my $q      = Kanku::NotifyQueue->new(
    shutdown_file => $self->shutdown_file,
    logger        => $self->logger
  );
  $self->logger->debug("q->shutdown_file: ".$self->shutdown_file);
  $q->prepare;
  return $q;
}

sub print_usage {
  my ($self) = @_;
  my $basename = $self->daemon_basename;

  return "\nUsage: $basename [--stop]\n";
}

sub prepare_and_run {
  my ($self) = @_;
  Kanku::Config->initialize();
  my $logger = $self->logger;

  if ($self->daemon_options->{stop}) {
    return $self->initialize_shutdown;
  }

  $self->check_pid if $self->pid_file->exists;

  $self->logger->info("Starting service " . ref $self);

  my $hn  = hostfqdn() || hostname();
  my $ref = ref $self;
  my $notification = {
    type    => 'daemon_change',
    event   => 'start',
    daemon  => $ref,
    pid     => $$,
    message => "$ref starting (pid $$) on $hn",
  };
  $self->notify_queue->send($notification);

  $SIG{'INT'} = $SIG{'TERM'} = sub {
    $self->logger->info('Initializing shutdown');
    $self->initialize_shutdown;
  };

  # daemonize
  if (! $self->daemon_options->{foreground}) {
    return 0 if fork;
  }

  $self->logger->info(sprintf("Writing to pid file '%s' : %d", $self->pid_file, $$));

  path($self->pid_file)->spew("$$");

  Kanku::Airbrake->initialize();

  $self->run;

  $self->finalize_shutdown();

  return 0;
}

sub initialize_shutdown {
  my ($self) = @_;
  my $logger = $self->logger;

  # nothing should be running if no pid_file exists
  if (!$self->pid_file->exists) {
    $logger->info('No pidfile found, exiting');
    return 0;
  }

  my $pid = $self->pid_file->slurp;

  if (kill(0,$pid)) {
    $self->shutdown_file->touch();
  } else {
    $logger->warn("Process $pid seems to be died unexpectedly");
    try {
      $self->pid_file->remove();
    }
    catch {
      $logger->error($_);
    };
  }

  return 0;
}

sub finalize_shutdown {
  my ($self) = @_;
  my $logger = $self->logger;
  my $pkg    = __PACKAGE__;
  $logger->debug('Removing shutdown file: '. $self->shutdown_file->stringify);
  try {
    $self->shutdown_file->remove;
  }
  catch {
    $logger->error($_);
  }

  $logger->debug('Removing PID file: '. $self->pid_file->stringify);
  try {
    $self->pid_file->remove;
  }
  catch {
    $logger->error($_);
  }

  $logger->info("Shutting down service $pkg");

  my $hn  = hostfqdn() || 'localhost';
  my $ref = ref($self);
  my $notification = {
    type    => 'daemon_change',
    event   => 'stop',
    daemon  => $ref,
    pid     => $$,
    message => "$ref stopping (pid $$) on $hn",
  };

  $self->notify_queue->send($notification);

  return;
}

sub check_pid {
  my ($self)   = @_;
  my $pid      = $self->pid_file->slurp ;

  if ($pid == $$) {;
    $self->logger->info("Pid matches my own pid $$");
    return
  }

  if (kill(0, $pid)) {
    die "Another instance already running with pid $pid\n";
  }

  $self->logger->warn("Process $pid seems to be died unexpectedly");
  $self->pid_file->remove;

  return;
}

sub detect_shutdown {
  my ($self) = @_;
  return 1 if $self->shutdown_file->is_file;
  return 0;
}

1;
