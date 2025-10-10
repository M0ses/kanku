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
package Kanku::Handler::CreateDomain;

use Moose;

use Carp;
use Try::Tiny;
use Path::Tiny;
use Data::Dumper;
use Session::Token;

use Kanku::Config;
use Kanku::Config::Defaults;
use Kanku::Util::VM;
use Kanku::Util::VM::Image;
use Kanku::Util::IPTables;
use Kanku::TypeConstraints;
use Kanku::Helpers;

sub gui_config {
  [
    {
      param => 'forward_port_list',
      type  => 'text',
      label => 'List of Forwarded Ports'
    },
    {
      param => 'network_name',
      type  => 'text',
      label => 'Name of libvirt network'
    },
    {
      param => 'network_bridge',
      type  => 'text',
      label => 'Name of network bridge'
    },
    {
      param => 'domain_autostart',
      type  => 'checkbox',
      label => 'Set autostart for domain on host startup',
    },
    {
      param => 'vcpu',
      type  => 'text',
      label => 'Number of CPUs for new domain',
    },
    {
      param => 'memory',
      type  => 'text',
      label => 'Memory size for new domain',
    },
    {
      param => 'template',
      type  => 'text',
      label => 'Template for domain xml',
    },
  ];
}
sub distributable { 1 }
with 'Kanku::Roles::Handler';

has [qw/
      domain_name           vm_image_file
      login_user            login_pass
      forward_port_list     ipaddress
      management_interface  management_network
      short_hostname	    memory
      template
/] => (is => 'rw',isa=>'Str');

has 'network_name' => (
  is      => 'rw',
  isa     =>'Str',
  lazy    => 1,
  builder => '_build_network_name',
);
sub _build_network_name {
  return
    $_[0]->job->context->{network_name}
    || Kanku::Config::Defaults->get(__PACKAGE__,'network_name');
}

has 'network_bridge' => (
  is      => 'rw',
  isa     =>'Str',
  lazy    => 1,
  builder => '_build_network_bridge',
);
sub _build_network_bridge {
  return
    $_[0]->job->context->{network_bridge}
    || Kanku::Config::Defaults->get(__PACKAGE__,'network_bridge');
}

has 'template' => (
  is      => 'rw',
  isa     =>'Str',
  lazy    => 1,
  builder => '_build_template',
);
sub _build_template {
  return
    $_[0]->job->context->{vm_template_file}
    || Kanku::Config::Defaults->get(__PACKAGE__,'template');
}

has 'pool_name' => (
  is      => 'rw',
  isa     =>'Str',
  lazy    => 1,
  builder => '_build_pool_name',
);
sub _build_pool_name {
  return Kanku::Config::Defaults->get(__PACKAGE__, 'pool_name');
}

has '+memory'         => ( builder => '_build_memory' );
sub _build_memory {
  return Kanku::Config::Defaults->get(__PACKAGE__, 'memory');
}

has 'vcpu' => (
  is      => 'rw',
  isa     =>'Int',
  builder => '_build_vcpu',
);
sub _build_vcpu {
  return Kanku::Config::Defaults->get(__PACKAGE__, 'vcpu');
}

has '+management_interface' => ( default => q{});
has '+management_network'   => ( default => q{});

has [qw/
        skip_network
        skip_login
        skip_memory_checks
	domain_autostart
	no_wait_for_bootloader
/]      => (is => 'rw',isa=>'Bool',default => 0);

has use_9p => (
  is      => 'rw',
  isa     => 'Bool',
  builder => '_build_use_9p',
);
sub _build_use_9p {
  return Kanku::Config::Defaults->get(__PACKAGE__, 'use_9p');
}

has "images_dir"     => (
  is      => 'rw',
  isa     => 'Str',
  builder => '_build_images_dir',
);
sub _build_images_dir {
  return Kanku::Config::Defaults->get('Kanku::Config::GlobalVars', 'images_dir');
}

has 'cache_dir'     => (
  is      => 'rw',
  isa     => 'Str',
  builder => '_build_cache_dir',
);
sub _build_cache_dir {
  return Kanku::Config::Defaults->get('Kanku::Config::GlobalVars', 'cache_dir');
}

has 'mnt_dir_9p' => (
  is => 'rw',
  isa => 'Str',
  builder => '_build_mnt_dir_9p',
);
sub _build_mnt_dir_9p {
  return Kanku::Config::Defaults->get(__PACKAGE__, 'mnt_dir_9p');
}

has ['host_dir_9p']    => (is => 'rw', isa => 'Str');

has ['accessmode_9p']  => (is => 'rw', isa => 'Str');

has [qw/
  noauto_9p
  wait_for_systemd
/]                    => (is => 'rw', isa => 'Bool');

has ['_root_disk']    => (is => 'rw', isa => 'Object');

has 'root_disk_size'  => (is => 'rw', isa => 'Str');

has 'root_disk_bus'  => (
  is => 'rw',
  isa => 'Str',
  builder => '_build_root_disk_bus',
);
sub _build_root_disk_bus {
  return Kanku::Config::Defaults->get(__PACKAGE__, 'root_disk_bus');
}

has empty_disks => (
  is => 'rw',
  isa => 'ArrayRef',
  lazy => 1,
  default => sub {[]}
);

has additional_disks => (
  is => 'rw',
  isa => 'ArrayRef',
  lazy => 1,
  default => sub {[]}
);

has installation => (
  is      => 'rw',
  isa     => 'ArrayRef',
  lazy    => 1,
  default => sub { [] }
);

has pwrand => (
  is      => 'rw',
  isa     => 'HashRef',
  lazy    => 1,
  default => sub { {} }
);

has default_console_timeout => (
  is      => 'rw',
  isa     => 'Int',
  lazy    => 1,
  default => 600,
);

has login_timeout => (
  is      => 'rw',
  isa     => 'Int',
);

has image_type => (
  is      => 'rw',
  isa     => 'ImageType',
  lazy    => 1,
  builder => '_build_image_type',
);

sub _build_image_type {
  my ($self) = @_;
  my $ctx  = $self->job()->context();
  my $d    = Kanku::Config::Defaults->get(__PACKAGE__, 'image_type');
  return $ctx->{image_type} || $d;
}

sub prepare {
  my ($self) = @_;
  my $ctx  = $self->job()->context();

  $self->domain_name($ctx->{domain_name})       if ( ! $self->domain_name && $ctx->{domain_name});
  $self->login_user($ctx->{login_user})         if ( ! $self->login_user  && $ctx->{login_user});
  $self->login_pass($ctx->{login_pass})         if ( ! $self->login_pass  && $ctx->{login_pass});
  $self->vm_image_file($ctx->{vm_image_file})   if ( ! $self->vm_image_file  && $ctx->{vm_image_file});
  $self->host_dir_9p($ctx->{host_dir_9p})       if ( ! $self->host_dir_9p  && $ctx->{host_dir_9p});
  $self->accessmode_9p($ctx->{accessmode_9p})   if ( ! $self->accessmode_9p  && $ctx->{accessmode_9p});
  $self->cache_dir($ctx->{cache_dir})           if ($ctx->{cache_dir});
  $self->domain_autostart(1)                    if ($ctx->{domain_autostart});
  $self->no_wait_for_bootloader(1)              if $self->image_type eq 'vagrant';

  $ctx->{management_interface} = $self->management_interface
    if $self->management_interface;

  if (!$self->vm_image_file) {
    croak(
      'No vm_image_file defined. Either you specify it manually for local '.
      'files or you need to run e.g. Kanku::Handler::ImageDownload before '.
      'running '.__PACKAGE__.'!'
    );
  }
  $self->logger->debug("*** vm_image_file: ".$self->vm_image_file);
  $self->logger->debug("*** tmp_image_file: ".$ctx->{tmp_image_file}) if $ctx->{tmp_image_file};
  $self->logger->debug("*** image_type: ".$self->image_type);

  return {
    code    => 0,
    message => "Nothing todo"
  };
}

sub execute {
  my ($self) = @_;
  my $ctx    = $self->job()->context();
  my $logger = $self->logger;

  my $cfg  = Kanku::Config->instance()->config();

  my $mem;

  if ( $self->memory =~ /^\d+$/ ) {
    $mem = $self->memory;
  } elsif ( $self->memory =~ /^(\d+)([kKmMgG])[bB]?$/ ) {
    my $factor = lc($2);
    my $ft = {k => 1, m => 1024, g => 1024*1024};
    $mem = $1 * $ft->{$factor};
  } else {
    die "Option memory has wrong format! Allowed formats: INT[kKmMgG].\n";
  }

  $self->logger->debug("Using memory: '$mem'");

  $logger->debug("Using default network_bridge : '".$self->network_bridge."'");

  $logger->debug("additional_disks:".Kanku::Helpers->dump_it($self->additional_disks));


  my $final_file = ($ctx->{tmp_image_file} ) ? path($ctx->{tmp_image_file})->basename : $self->vm_image_file;

  if ($self->root_disk_size) {
    croak("Using Kanku::Handler::ResizeImage AND root_disk_size is not supported") if $ctx->{tmp_image_file};
    my $img_obj = Kanku::Util::VM::Image->new();
    $logger->debug("CreateDomain: resizing to ". $self->root_disk_size);
    $ctx->{tmp_image_file} = $img_obj->resize_image($final_file, $self->root_disk_size);
    $final_file = $ctx->{tmp_image_file}->stringify;
  }

  my ($vol, $image) = $self->_create_image_file_from_cache({file=>$final_file}, 0, $self->domain_name);

  $final_file = $vol->get_path();
  for my $file(@{$self->additional_disks}) {
      my ($avol,$aimage) = $self->_create_image_file_from_cache($file);
      $logger->debug("additional_disk: - before: $file->{file}");
      $file->{file} = $avol->get_path();
      $logger->debug("additional_disk: - after: $file->{file}");
  }

  my $pkg = __PACKAGE__;
  my $network_name = $self->network_name
    || $ctx->{network_name}
    || Kanku::Config::Defaults->get(__PACKAGE__, 'network_name');

  my $vm = Kanku::Util::VM->new(
      vcpu                  => $self->vcpu,
      memory                => $mem,
      domain_name           => $self->domain_name,
      images_dir            => $self->images_dir,
      login_user            => $self->login_user,
      login_pass            => $self->login_pass,
      use_9p                => $self->use_9p,
      management_interface  => $self->management_interface,
      management_network    => $self->management_network,
      empty_disks           => $self->empty_disks,
      additional_disks      => $self->additional_disks,
      job_id                => $self->job->id,
      network_name          => $network_name,
      network_bridge        => $self->network_bridge,
      running_remotely      => $self->running_remotely,
      image_file            => $final_file,
      root_disk             => $image,
      root_disk_bus         => $self->root_disk_bus,
      skip_memory_checks    => $self->skip_memory_checks,
      pool_name             => $self->pool_name,
      log_file              => $ctx->{log_file} || q{},
      log_stdout            => defined ($ctx->{log_stdout}) ? $ctx->{log_stdout} : 1,
      no_wait_for_bootloader => $self->no_wait_for_bootloader,
      template_file         => $self->template,
  );

  $vm->host_dir_9p($self->host_dir_9p) if ($self->host_dir_9p);
  $vm->accessmode_9p($self->accessmode_9p) if ($self->accessmode_9p);

  $logger->info("Creating domain ".$self->domain_name);
  $vm->create_domain();

  if ($self->domain_autostart) {
    $vm->dom->set_autostart(1);
    $ctx->{domain_autostart} = 1;
  }

  $ctx->{tmp_image_file} = undef if exists $ctx->{tmp_image_file};
  if ($self->image_type ne 'vagrant') {
    my $con = $vm->console();

    $con->cmd_timeout($self->default_console_timeout);
    $con->login_timeout($self->login_timeout) if $self->login_timeout;

    if (@{$self->installation}) {
      $self->_handle_installation($con);
    }

    if ($self->skip_login) {
      $con->wait_for_login_prompt;
    } else {
      $self->_prepare_vm_via_console($con, $vm);
    }
  } else {
    $logger->info('Image Type "'.$self->image_type.'". Skipping VM preparation via console');
    $ctx->{ipaddress} = $vm->get_ipaddress();
  }

  return {
    code    => 0,
    message => "Create domain " . $self->domain_name ." (".( $ctx->{ipaddress} || 'no ip found' ).") successfully"
  };
}

sub _handle_installation {
  my ($self, $con) = @_;
  my $exp          = $con->_expect_object();
  my $logger       = $self->logger;

  $logger->debug("Handling installation");

  my $cursor = {
    up    => "\e[A",
    down  => "\e[B",
    right => "\e[C",
    left  => "\e[D",
  };

  for my $step (@{$self->installation}) {
    my ($expect,$send) = ($step->{expect}, $step->{send});
    my $timeout = $step->{timeout} || 300;
    $logger->debug("Waiting for '$expect' on console (timeout: $timeout)");
    $exp->expect(
      $timeout,
      [ $expect =>
        sub {
          my $exp = shift;
          $logger->debug("SEEN '$expect' on console");
          if ($step->{send_ctrl_c}) {
            $logger->debug("Sending <CTRL>+C");
            $exp->send("\cC");
          }
          if ($send) {
            $logger->debug("Sending '$send'");
            $exp->send($send);
          }
          if ($step->{send_cursor}) {
            foreach my $cur (split /\s+/, $step->{send_cursor}) {
               my $n2c = $cursor->{$cur};
               if ($n2c) {
                 $logger->debug("Sending '$n2c'");
                 $exp->send($n2c);
               } else {
                 croak("Cannot lookup cursor direction '$cur'\n");
               }
            }
          }
          if ($step->{send_enter}) {
            $logger->debug("Sending <enter>");
            $exp->send("\r");
          }
          if ($step->{send_esc}) {
            $logger->debug("Sending <ESC>");
            $exp->send("\x1B");
          }
        }
      ],
    );
    $exp->clear_accum();
  }
}


sub _prepare_vm_via_console {
  my ($self, $con, $vm) = @_;

  my $ctx    = $self->job()->context();
  my $logger = $self->logger;
  my $cfg    = Kanku::Config->instance()->config();

  $con->login();

  if ($self->use_9p) {
    my $output = $con->cmd('grep --color=never "^CONFIG_NET_9P=m" /boot/config-$(uname -r)|| zgrep --color=never "^CONFIG_NET_9P=m" /proc/config.gz ||true');
    my @out = split /\n/, $output->[0];
    my @supports_9p = grep { /^CONFIG_NET_9P=m/ } @out;
    $logger->debug("supports 9p: @supports_9p");
    if (!$supports_9p[0]) {
      croak(
        "\n".
        "Kanku::Handler::CreateDomain: ".
        "You have enabled 'use_9p' but the guest kernel doesn't support.\n".
        "Please disable 'use_9p' in your kanku config!\n"
      );
    }
  }

  $self->_randomize_passwords($con) if keys %{$self->pwrand};

  my $ip;
  my %opts = ();

  $self->_setup_9p($con);

  $self->_setup_hostname($con);

  # make sure that dhcp server gets updated
  $con->network_restart;

  if ( ! $self->skip_network ) {
    %opts = (mode => 'console') if $self->management_interface or $self->running_remotely;

    $ip = $vm->get_ipaddress(%opts);
    die "Could not get ipaddress from VM" unless $ip;
    $ctx->{ipaddress} = $ip;

    if ( $self->forward_port_list ) {
	my $ipt = Kanku::Util::IPTables->new(
	  domain_name      => $self->domain_name,
	  host_interface   => $ctx->{host_interface}
	                      || Kanku::Config::Defaults->get('Kanku::Util::IPTables',
			                                      'host_interface')
			      || q{},
	  guest_ipaddress  => $ip,
	  iptables_chain   => Kanku::Config::Defaults->get('Kanku::Util::IPTables',
	                                                   'iptables_chain'),
	  domain_autostart => $self->domain_autostart,
	);

	$ipt->add_forward_rules_for_domain(
	  start_port => Kanku::Config::Defaults->get('Kanku::Util::IPTables',
	                                             'start_port'),
	  forward_rules => [ split(/,/,$self->forward_port_list) ]
	);
    }

  }

  if ( $self->wait_for_systemd ) {
    $logger->info("Waiting for system to come up!");
    $con->cmd(
      'while [ "$s" != "No jobs running." ];do s=`systemctl list-jobs`;logger "systemctl list-jobs: $s";sleep 1;done'
    );
  }

  $con->logout();
}

sub _randomize_passwords {
  my ($self, $con) = @_;
  my $ctx  = $self->job()->context();
  $ctx->{pwrand} = {};

  $ctx->{encrypt_pwrand} = $self->pwrand->{recipients} if $self->pwrand->{recipients};

  for my $user (@{$self->pwrand->{users} || []}) {
    my $pw_length = $self->pwrand->{pw_length} || 16;
    $self->logger->info("Setting randomized password for user: $user, lenght: $pw_length");
    my $pw = Session::Token->new(length => $pw_length)->get;
    $self->logger->trace("  -- New password for user $user: '$pw'");
    # keep first character blank to hide from history
    $con->cmd(" echo -en \"$pw\\n$pw\\n\"|passwd $user");
    $ctx->{pwrand}->{$user} = $pw;
  }
}

sub _setup_9p {
  my ($self,$con) = @_;

  return if (! $self->use_9p);

  my $mp     = $self->mnt_dir_9p;

  if ($mp) {
    my $noauto = ($self->noauto_9p) ? ',noauto' : '';
    $con->cmd(
      "mkdir -p $mp",
      "echo \"kankushare $mp 9p trans=virtio,version=9p2000.L$noauto 1 0\" >> /etc/fstab",
      "mount -a",
      "echo 'force_drivers+=\" 9p 9pnet 9pnet_virtio \"' >> /etc/dracut.conf.d/98-kanku.conf",
      "dracut --force",
      # Be aware of the two spaces after delimiter
      'if [ -f /boot/grub2/device.map ] ;then grub2-install `cut -f2 -d\  /boot/grub2/device.map |head`;else /bin/true;fi',
      'id kanku || { useradd -m -s /bin/bash kanku && { echo kanku:kankusho | chpasswd ; } ; echo "Added user"; }'
    );
  }
}

sub _setup_hostname {
  my ($self,$con) = @_;
  my $hostname;

  if ($self->short_hostname) {
    $hostname = $self->short_hostname;
  } else {
    $hostname = $self->domain_name;
    $hostname =~ s/\./-DOT-/g;
  }
  try {
    $con->cmd("hostnamectl set-hostname \"$hostname\"");
  }
  catch {
    $self->logger->warn("Setting hostname with hostnamectl failed: '$_'");
    $self->logger->warn("Trying legacy method to set hostname");

    # set hostname unique to avoid problems with duplicate in dhcp
    $con->cmd(
      "echo \"$hostname\" > /etc/hostname",
      "hostname \"$hostname\"",
    );
  };

}

sub _create_image_file_from_cache {
  my $self       = shift;
  my $file_data  = shift;
  my $file       = $file_data->{file};
  my $size       = shift || 0;
  my $vol_prefix = shift;
  my $ctx  = $self->job()->context();
  my $image;
  my $vol;

  # 0 means that format is the same as suffix
  my %suffix2format = (
     qcow2    => 0,
     raw      => 0,
     vmdk     => 0,
     vdi      => 0,
     iso      => 0,
     img      => 'raw',
     vhdfixed => 'raw',
  );
  my $supported_formats = join('|', keys %suffix2format);
  $self->logger->debug("file: --- $file");
  my @parts = ($file =~ m#/#) ? ($file) : ($self->cache_dir, $file);
  my $in = path(@parts);

  $self->logger->debug("Using file ".$in->stringify);
  if ( $file =~ /\.($supported_formats)(\.(gz|bz2|xz))?$/ ) {
    my $fmt      = $1;
    my $vol_name = $file;
    $vol_name = $self->domain_name .".$fmt" if ($vol_prefix);

    $image =
      Kanku::Util::VM::Image->new(
	format		=> ($suffix2format{$fmt} || $fmt),
	vol_name 	=> $vol_name,
	source_file 	=> $in->stringify,
        final_size      => $size,
        pool_name       => $self->pool_name,
      );

    if ($file_data->{reuse}) {
      $self->logger->info("Uploading '$vol_name' skipped because of reuse flag");
      my $vm = Kanku::Util::VM->new();
      $vol = $vm->search_volume(name=>$vol_name);
      die "No volume with name '$vol_name' found" if ! $vol;
    } else {
      $self->logger->info("Uploading $in via libvirt to pool ".$self->pool_name." as $vol_name");
      try {
        $vol = $image->create_volume();
      } catch {
        my $e = $_;
        $self->logger->error("Error while uploading $in to $vol_name");
        if (ref($e)) {
          die $e->stringify;
        } else {
          die $e;
        }
      };
    }
  } else {
    die "Unknown extension for disk file $file\n";
  }

  return ($vol, $image);
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Kanku::Handler::CreateDomain

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::CreateDomain
    options:
      domain_name: kanku-vm-1
      ....
      installation:
        -
          expect: Install
          send: yes
          send_enter: 1
        -
          expect: Next Step
          send_ctrl_c: 1
        -
          expect: Step 3
          send_esc: 1
      pwrand:                   # create randomized password
        length: 16              # password length (default: 16 characters)
        user: 			# list of users to
          - root
          - kanku
        recipients:
          - fschreiner@suse.de  # list of recipients to encrypt for
                                # if not specified, clear text password will
                                # be stored

      additional_disks:		# list of additional disk images to use in VM
        -
          file: storage.qcow2   # filename for disk image
	  format: raw		# can be one of the following list
                                # qcow2, raw, vmdk, vdi, iso, img, vhdfixed
          reuse: 1		# do not overwrite existing image in libvirt,
                                # but reuse it in new VM

=head1 DESCRIPTION

This handler creates a new VM from the given template file and a image file.

It will login into the VM and try to find out the ipaddress of the interface connected to the default route.

If configured a port_forward_list, it tries to find the next free port and configure a port forwarding with iptables.


=head1 OPTIONS


    domain_name           : name of domain to create

    vm_image_file         : image file to be used for domain creation

    login_user            : user to be used to login via console

    login_pass            : password to be used to login via console

    images_dir            : directory where the images can be found

    management_interface  : Primary network interface on guest.
                            Used to get guest ip address via console.

    management_network    : Name of virtual network on host.
                            Used to get guest ip address from DHCP server.

    network_name          : Name of virtual network on host (default: default)
                            Used as domain.network_name in guests xml template

    network_bridge        : Name of bridge interface on host (default: br0)
                            Used as domain.network_bridge in guests xml template

    forward_port_list     : list of ports to forward from host_interface`s IP to VM
                            DONT USE IN DISTRIBUTED ENV - SEE Kanku::Handler::PortForward

    memory                : memory in KB to be used by VM

    vcpu                  : number of cpus for VM

    use_9p                : create a share folder between host and guest using 9p

    cache_dir		  : set directory for caching images

    mnt_dir_9p		  : set diretory to mount current working directory in vm. Only used if use_9p is set to true. (default: '/tmp/kanku')

    noauto_9p		  : set noauto option for 9p directory in fstab.

    root_disk_size        : define size of root disk (WARNING: only availible with raw images)

    additional_disks      : Array of additional disk images to use in VM

                            * file   - filename for disk image

			    * format - qcow2, raw, vmdk, vdi, iso, img, vhdfixed

                            * reuse  - do not overwrite existing image in libvirt pool

    empty_disks           : Array of empty disks to be created

                            * name   - name of disk (required)

                            * size   - size of disk (required)

                            * pool   - name of pool (default: 'default')

                            * format - format of new disk (default: 'qcow2')

    installation          : array of expect commands for installation process

    pool_name             : name of disk pool

    root_disk_bus         : disk bus system for root device. Default: virtio

                            Can be virtio, ide, sata or scsi.

    template              : template xml to define VM (has precedence over job context)

    default_console_timeout : default timeout for console commands (default: 600 sec)

    login_timeout         : timeout to wait from bootloader to login prompt (boot time) (default: 300 sec)

    no_wait_for_bootloader : don't wait for bootloader messages (default: 0)


=head1 CONTEXT

=head2 getters

 domain_name

 login_user

 login_pass

 vm_template_file

 vm_image_file

 host_interface

 cache_dir

 domain_autostart

 network_name

 image_type

=head2 setters

 vm_image_file

 ipaddress

 domain_autostart

=head1 DEFAULTS

 images_dir     /var/lib/libvirt/images

 vcpu           1

 memory         1024 MB

 use_9p         0

 mnt_dir_9p	/tmp/kanku

=cut

