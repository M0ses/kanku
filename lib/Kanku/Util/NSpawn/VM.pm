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
package Kanku::Util::NSpawn::VM;

use Moose;

use Net::IP;
use Try::Tiny;
use Path::Tiny;
use XML::XPath;

use Net::DBus;

use Expect;
use Template;
use POSIX qw(setsid);
use Carp;

with 'Kanku::Roles::Logger';

use Kanku::Util::NSpawn::Console;

has '_bus' => (
  is      => 'rw',
  isa     => 'Object',
  builder => '_build__bus',
);
sub _build__bus {return Net::DBus->system;}

has 'network_name' => (
  is      => 'rw',
  isa     => 'Str',
  builder => '_build_network_name',
);
sub _build_network_name {return Kanku::Config::Defaults->get('Kanku::Handler::CreateDomain', 'network_name')}

has 'vm_name' => (
  is       => 'rw',
  isa      => 'Str',
  required => 1,
);

has '_unit_name' => (
  is       => 'rw',
  isa      => 'Str',
  builder  => '_build__unit_name',
  lazy     => 1,
);
sub _build__unit_name {
  return 'kanku-nspawn@'.$_[0]->vm_name.'.service'
}

has 'state_change_timeout' => (
  is       => 'rw',
  isa      => 'Int',
  default  => 300,
);

has use_9p => (
  is      => 'rw',
  isa     => 'Bool',
  default => 0,
);

has host_dir_9p => (
  is      => 'rw',
  isa     => 'Str',
  lazy    => 1,
  builder => '_build_host_dir_9p',
);
sub _build_host_dir_9p {
  return Path::Tiny->cwd->stringify
}

has mnt_dir_9p => (
  is      => 'rw',
  isa     => 'Str',
  default => '/tmp/kanku',
);

sub _create_nspawn_config {
  my ($self) = @_;
  my $logger = $self->logger;

  my $machine_name = $self->vm_name;
  my $source = $self->host_dir_9p;
  my $dest   = $self->mnt_dir_9p;

  $logger->warn("use_9p: Shared folders with nspawn containers require running without user namespaces");
  $logger->warn("use_9p: This is a known limitation - see https://github.com/systemd/systemd/issues/36470");

  my $config_dir = Path::Tiny->new("/etc/systemd/nspawn");

  eval {
    $config_dir->mkpath unless -d $config_dir;
  };
  if ($@ || ! -d $config_dir) {
    $logger->warn("Cannot create nspawn config directory: $@");
    return 0;
  }

  my $config_file = $config_dir->child("$machine_name.nspawn");

  my $config = "[Files]\nBind=$source:$dest\n";

  $logger->debug("Creating nspawn config file: $config_file");
  
  eval {
    $config_file->spew($config);
  };
  if ($@) {
    $logger->warn("Cannot write nspawn config file: $@");
    return 0;
  }

  $logger->debug("nspawn config created: $config");

  return 1;
}

sub bind_mount {
  my ($self) = @_;
  my $logger = $self->logger;

  return unless $self->use_9p;

  my $machine_name = $self->vm_name;
  my $source = $self->host_dir_9p;
  my $dest   = $self->mnt_dir_9p;

  $logger->debug("Creating bind mount: $source -> $dest for machine $machine_name");

  my $machine_service = $self->_bus->get_service("org.freedesktop.machine1");
  my $machine_manager = $machine_service->get_object(
    "/org/freedesktop/machine1",
    "org.freedesktop.machine1.Manager"
  );

  eval {
    $machine_manager->BindMountMachine($machine_name, $source, $dest, 0, 1);
  };
  if ($@) {
    my $err = $@;
    $logger->debug("D-Bus bind mount failed (expected with user namespaces): $err");
    $logger->debug("Bind mount will be created via console in PrepareSSH handler instead");
    return 0;
  }

  $logger->debug("Bind mount created successfully");

  return 1;
}

sub bind_mount_via_console {
  my ($self) = @_;
  my $logger = $self->logger;

  return unless $self->use_9p;

  my $machine_name = $self->vm_name;
  my $source = $self->host_dir_9p;
  my $dest   = $self->mnt_dir_9p;

  $logger->warn("bind_mount_via_console: Shared folders not supported with user namespaces");
  $logger->warn("bind_mount_via_console: Container '$machine_name' is running with user namespaces");
  $logger->warn("bind_mount_via_console: To use shared folders, run container without user namespaces");

  return 0;
}

sub create_machine {
  my ($self) = @_;
  my $logger = $self->logger;

  my $bridge_name  = $self->network_name;
  my $machine_name = $self->vm_name;
  my $root_dir     = "/var/lib/machines/$machine_name";

  # 2. Get the systemd Manager object
  my $service = $self->_bus->get_service("org.freedesktop.systemd1");
  my $manager = $service->get_object("/org/freedesktop/systemd1", "org.freedesktop.systemd1.Manager");
  my $unit_name = $self->_unit_name;

  if ($self->use_9p) {
    $self->_create_nspawn_config();
  }

  my $job_path = $manager->StartUnit($unit_name, "replace");

  # 2. Wait for the Job object to disappear (Job completion)
  $logger->info("Waiting for job to complete...");
  while (1) {
    my $jobs = $manager->ListJobs();
    # Check if our job_path is still in the active jobs list
    $logger->debug("Found job_path: $_->[2] ") for @$jobs;
    my $found = grep { $_->[2] eq $job_path } @$jobs;
    last unless $found;
    sleep(1);
  }
  $logger->info("Job completed ... Checking state");
  $self->wait_for_state('active');

  my $machine_service = $self->_bus->get_service("org.freedesktop.machine1");
  my $machine_manager = $machine_service->get_object("/org/freedesktop/machine1", "org.freedesktop.machine1.Manager");
  my $addresses = [];

  my $net_ip  = Kanku::Util->get_ipaddress($bridge_name);
  $logger->debug("Host IP Address: " . ($net_ip->[0] // 'none'));

  my $net_obj = new Net::IP($net_ip->[0]) || die(Net::IP::Error());

  $logger->debug("Host prefixlen: ".$net_obj->prefixlen);

  $logger->info("Container '$machine_name' successfully registered and detached.");
  my $ipaddr = $self->get_ipaddress;
  return {ipaddress => $ipaddr};
}

sub get_ipaddress {
  my ($self) = @_;
  my $logger = $self->logger;
  my $machine_name = $self->vm_name;

  my $machine_service = $self->_bus->get_service("org.freedesktop.machine1");
  my $machine_manager = $machine_service->get_object("/org/freedesktop/machine1", "org.freedesktop.machine1.Manager");

  while (1) {
    my $addresses = $machine_manager->GetMachineAddresses($machine_name);

    if (@{$addresses}) {
      for my $addr (@{$addresses}) {
	if (scalar(@{$addr->[1]}) == 4) {
           $logger->trace("Container address: $addr->[1]->[0]");
           if ($addr->[1]->[0] != 169) {
 	     return join('.', @{$addr->[1]});
	   }
	   sleep 1;
        }
      }
    }
  }
}

sub destroy_machine {
  my ($self) = @_;
  my $logger = $self->logger;

  my $bridge_name  = $self->network_name;
  my $machine_name = $self->vm_name;
  # 2. Get the systemd Manager object
  my $service = $self->_bus->get_service("org.freedesktop.systemd1");
  my $manager = $service->get_object("/org/freedesktop/systemd1", "org.freedesktop.systemd1.Manager");
  my $unit_name = $self->_unit_name;

  # Check systemd service unit and stop if exists
  try {
    my $unit     = $manager->GetUnit($unit_name);
    my $job_path = $manager->StopUnit($unit_name, "replace");

    $logger->info("Waiting for job to complete...");
    while (1) {
      my $jobs = $manager->ListJobs();
      # Check if our job_path is still in the active jobs list
      $logger->debug("Found job_path: $_->[2] ") for @$jobs;
      my $found = grep { $_->[2] eq $job_path } @$jobs;
      last unless $found;
      sleep(1);
    }
    $logger->info("Job completed ... Checking state");
    
    $self->wait_for_state('inactive');
  } catch {
    $logger->warn("Failed to stop service unit $unit_name: $_");
  };

  my $machine_service = $self->_bus->get_service("org.freedesktop.machine1");
  my $machine_manager = $machine_service->get_object("/org/freedesktop/machine1", "org.freedesktop.machine1.Manager");
  $machine_manager->RemoveImage($machine_name);
}

sub wait_for_state {
  my ($self, $state) = @_;
  my $logger = $self->logger;

  $logger->info('Waiting for machine "'.$self->vm_name.'" to change state '.$state);
  my $service = $self->_bus->get_service("org.freedesktop.systemd1");
  my $manager = $service->get_object("/org/freedesktop/systemd1", "org.freedesktop.systemd1.Manager");
  my $unit_obj_path = $manager->GetUnit($self->_unit_name);
  my $unit_props    = $service->get_object($unit_obj_path, "org.freedesktop.DBus.Properties");
  my $active_state;#  = $unit_props->Get("org.freedesktop.systemd1.Unit", "ActiveState");

  my $to = $self->state_change_timeout;

  while (1) {
    $active_state  = $unit_props->Get("org.freedesktop.systemd1.Unit", "ActiveState");
    $logger->debug("Unit is in state '$active_state'.");
    last if ($active_state eq $state);
    $to--;
    confess("Timeout while waiting for state to change to '$state'") if ($to <= 0);
    sleep 1;
  }
 
  return 1;
}

sub get_machine_state {
  my ($self) = @_;
  my $logger = $self->logger;

  my $service = $self->_bus->get_service("org.freedesktop.machine1");
  my $manager = $service->get_object("/org/freedesktop/machine1", "org.freedesktop.machine1.Manager");

  my $machine_name = $self->vm_name;
  my $machine_path;

  try {
    $machine_path = $manager->GetMachine($machine_name);
  } catch {
    croak "Error: Machine '$machine_name' not found. Ensure it is running or registered. $_";
  };

  # 3. Access the machine object
  # Note: We do not strictly need to cast to the Machine interface here
  # because we are calling the Properties interface.
  my $machine_obj = $service->get_object($machine_path);

  # 4. Explicitly cast to the standard Properties interface
  my $props_iface = $machine_obj->as_interface("org.freedesktop.DBus.Properties");

  # 5. Call 'Get' providing the Interface name and Property name
  # Syntax: Get(interface_name, property_name)
  my $state = $props_iface->Get("org.freedesktop.machine1.Machine", "State");

  $logger->debug("Machine state: $state");
 
  return $state;
}

sub cmd {
  my ($self, $cmd) = @_;
  my $logger = $self->logger;

  my $service = $self->_bus->get_service("org.freedesktop.machine1");
  my $manager = $service->get_object("/org/freedesktop/machine1", "org.freedesktop.machine1.Manager");

  my $machine_name = $self->vm_name;
  my $machine_path;

  my ($fd, $pty_path) = $manager->OpenMachineLogin($machine_name);
  
  $logger->debug("PTY: $pty_path");

  # 4. Use the file descriptor in Perl
  open(my $pty_fh, "+<&=", $fd) or die "Could not open FD $fd: $!";

  # Example: Read from the container's login prompt
  while (1) {
    my $line = <$pty_fh>;
    $logger->debug("Container says: $line");
    last if $line =~ /login:/;
  }

  close($pty_fh);
  $logger->debug("Closed login");

  return 1;
}

1;
