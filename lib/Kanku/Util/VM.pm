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
package Kanku::Util::VM;

use Moose;

use Sys::Virt;
use Sys::Virt::Stream;
use Expect;
use Template;
use Cwd;
use Net::IP;
use Sys::Virt::StorageVol;
use XML::XPath;
use Try::Tiny;
use File::Path qw/make_path/;

use Kanku::Util::VM::Console;
use Kanku::Util::VM::Image;

has [qw/
      image_file    domain_name   vcpu        memory
      images_dir    login_user    login_pass  template_file
      ipaddress     uri           disks_xml
      management_interface        management_network
      network_name  network_bridge
      keep_volumes  pool_name     snapshot_name
    / ]  => ( is=>'rw', isa => 'Str');

has job_id           => ( is => 'rw', isa => 'Int' );
has root_disk        => ( is => 'rw', isa => 'Object' );
has use_9p           => ( is => 'rw', isa => 'Bool' );
has no_wait_for_bootloader => ( is => 'rw', isa => 'Bool' );
has running_remotely => ( is => 'rw', isa => 'Bool', default => 0 );
has empty_disks      => ( is => 'rw', isa => 'ArrayRef', default => sub {[]});
has additional_disks => ( is => 'rw', isa => 'ArrayRef', default => sub {[]});
has keep_volumes     => ( is => 'rw', isa => 'ArrayRef', default => sub {[]});
has '+uri'           => ( default => 'qemu:///system');
has '+template_file' => ( default => q{});
has '+snapshot_name' => ( default => 'current');
#has "+ipaddress"  => ( lazy => 1, default => sub { $self->get_ipaddress } );

has vmm => (
  is => 'rw',
  isa => 'Object|Undef',
  lazy => 1,
  default => sub {
    my $self = shift;
    try {
      return Sys::Virt->new(uri => $self->uri);
    }
    catch {
      my ($e) = @_;
      if ( ref($e) eq 'Sys::Virt::Error' ){
        die $e->stringify();
      } else {
        die $e
      }
    };
  }
);

has dom => (
  is => 'rw',
  isa => 'Object|Undef',
  lazy => 1,
  default => sub {
    my $self = shift;
    die "Could not find domain_name\n" if ! $self->domain_name;
    my $dom_o = undef;
    try {
      my $vmm = $self->vmm();
      for my $dom ( $vmm->list_all_domains() ) {
        if ( $self->domain_name eq $dom->get_name ) {
          $self->logger->debug("Found domain with name ".$self->domain_name);
          $dom_o = $dom;
          return $dom;
        }
      }
    }
    catch {
      my ($e) = @_;
      if ( ref($e) eq 'Sys::Virt::Error' ){
        die $e->stringify();
      } else {
        die $e
      }
    };
    return $dom_o;
  }
);

has console => (
  is => 'rw',
  isa => 'Object',
  lazy => 1,
  default => sub {
      my $self = shift;

      my $con = Kanku::Util::VM::Console->new(
        domain_name => $self->domain_name,
        login_user  => $self->login_user,
        login_pass  => $self->login_pass,
        job_id      => $self->job_id,
	log_file    => $self->log_file,
	log_stdout  => $self->log_stdout,
	no_wait_for_bootloader => $self->no_wait_for_bootloader,
      );

      $con->init();

      return $con
  }
);

has logger => (
  is => 'rw',
  isa => 'Object',
  lazy => 1,
  default => sub { Log::Log4perl->get_logger(); }
);

has wait_for_network => (
  is => 'rw',
  isa => 'Int',
  lazy => 1,
  default => 180
);

has network_name => (
  is      => 'rw',
  isa     => 'Str',
  lazy    => 1,
  default => 'default'
);

has host_dir_9p => (
  is      => 'rw',
  isa     => 'Str',
  lazy    => 1,
  default => sub { getcwd() }
);

has accessmode_9p => (
  is      => 'rw',
  isa     => 'Str',
  lazy    => 1,
  default => 'squash',
);

has '_unit' => (
  is 	=> 'rw',
  isa 	=> 'HashRef',
  default => sub {
    {
      vd => 0,
      sd => 0,
      hd => 0,
    }
  },
);

has '_controllers' => (
  is 	=> 'rw',
  isa 	=> 'HashRef',
  default => sub { {} },
);

has skip_memory_checks => ( is => 'rw', isa => 'Bool' );

has 'root_disk_bus'  => (is => 'rw', isa => 'Str');

has 'log_file'       => (is => 'rw', isa => 'Str',  default => q{});
has 'log_stdout'     => (is => 'rw', isa => 'Bool', default => 1);


sub process_template {
  my ($self,$disk_xml) = @_;
  my $logger = $self->logger;

  # some useful options (see below for full list)
  my $template_path = '/etc/kanku/templates';
  my $config = {
    INCLUDE_PATH => $template_path,
    INTERPOLATE  => 1,               # expand "$var" in plain text
    POST_CHOMP   => 1,               # cleanup whitespace
    #PRE_PROCESS  => 'header',        # prefix each template
    #EVAL_PERL    => 1,               # evaluate Perl code blocks
    #RELATIVE     => 1
  };

  my $host_feature = $self->_get_hw_virtualization;
  die "Hardware doesn't support kvm" if ! $host_feature;
  $logger->debug("Found hardware virtualization: '$host_feature'");
  # create Template object
  my $template  = Template->new($config);


  if (!$self->skip_memory_checks) {
    my $default_msg =  "You configured less than %dM memory. %s"
                      ." You can overwrite this with the 'skip_memory_checks'"
                      ." option in Kanku::Handler::CreateDomain.\n";
    my $mem;
    my $msg;
    $mem = 3;
    $msg = "You may not see any output on the console with our default images!";
    die(sprintf($default_msg, $mem, $msg)) if ($self->memory < $mem*1024);
    $mem = 64;
    $msg = "You may not see the kernel booting with our default images!";
    die(sprintf($default_msg, $mem, $msg)) if ($self->memory < $mem*1024);
    $mem = 256;
    $msg = "You may see a kernel panic with our default images!";
    die(sprintf($default_msg, $mem, $msg)) if ($self->memory < $mem*1024);
  }

  my $qemu_kvm;
  if (-e  '/usr/bin/qemu-kvm') {
     $qemu_kvm = '/usr/bin/qemu-kvm';
  } elsif (-e  '/usr/bin/kvm') {
     $qemu_kvm = '/usr/bin/kvm';
  } elsif ( $host_feature eq 'aarch64' && -e '/usr/bin/qemu-system-aarch64') {
     $qemu_kvm = '/usr/bin/qemu-system-aarch64';
  } else {
     die "Could not find qemu-kvm binary!\n";
  }

  $logger->debug("Using qemu-kvm binary: $qemu_kvm");

  # define template variables for replacement
  my $vars = {
    domain => {
      vcpu            => $self->vcpu        ,
      memory          => $self->memory      ,
      domain_name     => $self->domain_name ,
      images_dir      => $self->images_dir  ,
      image_file      => $self->image_file  ,
      network_name    => $self->network_name  ,
      network_bridge  => $self->network_bridge  ,
      hostshare       => "",
      disk_xml        => $disk_xml,
      disk_controllers_xml  => join('', keys %{$self->_controllers}),
    },
    host_feature      => $host_feature,
    qemu_kvm          => $qemu_kvm,
  };

  $logger->debug(" --- use_9p:".$self->use_9p);
  if ( $self->use_9p ) {
    $logger->debug(" --- host_dir_9p:".$self->host_dir_9p);
    if (! -d $self->host_dir_9p) {
      $logger->debug(" --- host_dir_9p does not exists. Trying to create");
      make_path($self->host_dir_9p) || die "Could not create host_dir_9p '".$self->host_dir_9p."': $!";
    }

    $logger->debug(" --- accesmode_9p: ".$self->accessmode_9p);

    $vars->{domain}->{hostshare} = "
    <filesystem type='mount' accessmode='".$self->accessmode_9p."'>
      <source dir='".$self->host_dir_9p."'/>
      <target dir='kankushare'/>
      <alias name='fs0'/>
    </filesystem>
";

  }

  # specify input filename, or file handle, text reference, etc.
  my $input;
  my @df=($self->template_file, $self->domain_name, 'default-vm');
  # cleanup .tt2 if template_file ends with .tt2
  $df[0] =~s/\.tt2$//;
  my ($f, undef) = grep { -f "$template_path/$_.tt2" } @df;

  if ($f) {
    $input = "$f.tt2";
    $logger->info("Using template file '$template_path/$input'");
  } else {
    $logger->warn("No template file found!");
    $logger->warn("Using internal template!");
    my $template;
    my $start = tell DATA;
    while ( <DATA> ) { $template .= $_ };
    seek DATA, $start,0;
    $input = \$template;
    $logger->trace("template:\n${$input}");
  }
  my $output = '';
  # process input template, substituting variables
  $template->process($input, $vars, \$output)
    || die $template->error()->as_string();
  $logger->debug("######### XML: ########\n$output\n");
  return $output;
}

sub _generate_disk_xml {
    my ($self,$file,$format, $boot) = @_;
    $self->logger->debug("generate_disk_xml: $file, $format");

    # ASCII 97 = a + 0
    my $disk_list   = {
      virtio => ['vd', 'disk', '<controller type="virtio-serial" index="0"/>' ],
      ide    => ['hd', 'disk', '<controller type="ide" index="0"/>'           ],
      sata   => ['sd', 'disk', '<controller type="sata" index="0"/>'          ],
      scsi   => ['sd', 'disk', '<controller type="scsi" index="0"/>'          ],
    };
    my $bus         = $self->root_disk_bus;
    die "Unknown bus type: '$bus'\n" unless $disk_list->{$bus};
    my $disk_prefix = $disk_list->{$bus}->[0];
    my $device      = $disk_list->{$bus}->[1];
    my $readonly    = '';

    if ($format eq 'iso') {
       $format      = 'raw';
       $disk_prefix = 'hd';
       $device      = 'cdrom';
       $bus         = 'ide';
       $readonly    = '<readonly/>';
    }

    $self->_controllers->{$disk_list->{$bus}->[2]} = 1;
    my $drive = $disk_prefix . chr(97+$self->_unit()->{$disk_prefix});
    $self->_unit()->{$disk_prefix}++;
    my $tboot = ($boot) ? "<boot order='1'/>" : '';
    my $cache = ($format eq 'vmdk') ? q{cache='unsafe'} : q{};

    return "
    <disk type='file' device='$device'>
      <driver name='qemu' type='$format' $cache/>
      <source file='$file'/>
      <target dev='$drive' bus='$bus'/>
      $readonly
      $tboot
    </disk>
";

}

sub _get_hw_virtualization {
  my $proc = open(my $fh,"<","/proc/cpuinfo") || die "Cannot open /proc/cpuinfo: $!";
  while (<$fh>) { return $1 if /(vmx|svm)/ }
  open(my $uname, "uname -p|");
  my $arch = <$uname>;
  close($uname);
  chomp $arch;
  return $arch if ($arch eq "aarch64");
  return;
}


sub create_empty_disks  {
  my ($self) = @_;
  my $xml    = "";

  for my $disk (@{$self->empty_disks}) {
    my $fmt    = $disk->{format} || 'qcow2';
    my $img = Kanku::Util::VM::Image->new(
                vol_name  => $self->domain_name ."-".$disk->{name}.".$fmt",
                size      => $disk->{size},
                vmm       => $self->vmm,
                pool_name => $disk->{pool} || $self->pool_name,
                format    => $fmt,
              );
    my $vol = $img->create_volume();

    $xml .= $self->_generate_disk_xml($vol->get_path,$img->format);
  }

  return $xml;
}

sub create_additional_disks {
  my ($self) = @_;
  my $xml    = "";

  for my $disk (@{$self->additional_disks}) {
    $xml .= $self->_generate_disk_xml($disk->{file}, $disk->{format});
  }

  return $xml;
}

sub create_domain {
  my $self  = shift;

  my $disk_xml;

  if ($self->root_disk->format eq 'iso') {
    $disk_xml .= $self->create_additional_disks();
    $disk_xml .= $self->create_empty_disks();
    $disk_xml .= $self->_generate_disk_xml($self->image_file,$self->root_disk->format, 1);
  } else {
    $disk_xml .= $self->_generate_disk_xml($self->image_file,$self->root_disk->format, 1);
    $disk_xml .= $self->create_additional_disks();
    $disk_xml .= $self->create_empty_disks();
  }

  my $xml   = $self->process_template($disk_xml);
  my $vmm;
  my $dom;
  $self->logger->trace("disk_xml:\n$disk_xml");
  $self->logger->trace("domain_xml:\n$xml");

  # connect to libvirtd
  try {
    $vmm = Sys::Virt->new(uri => 'qemu:///system');
  }
  catch {
    my ($e) = @_;
    if ( ref($e) eq 'Sys::Virt::Error' ){
      die $e->stringify();
    } else {
      die $e
    }
  };

  die $@->message . "\n" if ($@);

  # create domain
  try {
    $dom = $vmm->define_domain($xml);
    $dom->create;
  }
  catch {
    my ($e) = @_;
    if ( ref($e) eq 'Sys::Virt::Error' ){
      die $e->stringify();
    } else {
      die $e
    }
  };

  # return domain
  return $dom
}

sub get_ipaddress {
  my $self        = shift;
  my %opts        = @_;

  if ( $opts{management_network} ) {
    $self->management_network($opts{management_network});
  }

  if ( $opts{management_interface} ) {
    $self->management_interface($opts{management_interface})
  }

  $self->logger->debug("Running remotely: '".$self->running_remotely."'");

  if ((($opts{mode} || '' ) eq 'console') or $self->running_remotely) {
    return $self->_get_ip_from_console();
  } else {
    try {
      return $self->_get_ip_from_dhcp();
    } catch {
      return $self->_get_ip_from_console();
    }
  }
}

sub remove_domain {
  my $self    = shift;
  my $dom     = $self->dom;

  $self->logger->debug("Trying to remove domain '".$self->domain_name."'");

  if ( ! $dom ) {
    $self->logger->info("Domain with name '".$self->domain_name."' not found");
    return 0;
  }


  try {
    # Shutdown domain immediately (poweroff)
    my ($dom_state, $reason) = $dom->get_state;
    if ($dom_state == Sys::Virt::Domain::STATE_RUNNING ) {
      $self->logger->debug("Trying to destroy domain '".$dom->get_name."'");
      $dom->destroy();
    }

    $self->logger->debug("Checking for snapshots of domain '".$dom->get_name."'");
    my @snapshots = $dom->list_all_snapshots();
    $self->logger->debug("List of snapshots: (@snapshots)");
    for my $snap (@snapshots) {
      $snap->delete;
    }

    $self->logger->debug("Undefine domain '".$dom->get_name."'");
    $self->_manual_delete_volumes;
    $dom->undefine(Sys::Virt::Domain::UNDEFINE_NVRAM);
    $self->logger->debug("Successfully undefined domain '".$dom->get_name."'");
  } catch {
    die $_->message ."\n";
  };

  return 0;
}

sub _manual_delete_volumes {
  my ($self) = @_;

  my $vols = $self->list_volumes;

  for my $vol (@$vols) {
    my @res = grep { $vol->get_path =~ /\/$_$/ } @{$self->keep_volumes};
    if (! @res) {
      $self->logger->debug("Deleting volume ".$vol->get_path);
      $vol->delete;
    } else {
      $self->logger->debug("Keeping volume ".$vol->get_path);
    }
  }
}

sub list_volumes {
  my ($self) = @_;

  my $dom = $self->dom;

  my $xml = $dom->get_xml_description;

  my $xxp = XML::XPath->new(xml=>$xml);

  my @nodes = $xxp->findnodes('/domain/devices/disk');
  my @files;
  my @volumes;

  for my $node (@nodes) {
     if (ref($node) eq 'XML::XPath::Node::Element') {
       for my $c_node (@{$node->getChildNodes}) {
         if ( ($c_node->getName || '') eq 'source') {
           push @files, $c_node->getAttribute('file');
         }
       }
     }
  }

  for my $vol (@{$self->list_all_volumes}) {
    my $path = $vol->get_path;
    my @res = grep { $_ eq $path } @files;
    push @volumes, $vol if (@res);
  }

  return \@volumes;
}

sub list_all_volumes {
  my ($self) = @_;
  my @volumes;
  my @pools = $self->vmm->list_storage_pools();

  for my $pool (@pools) {
    my @vols = $pool->list_volumes();
    push @volumes, @vols;
  }

  return \@volumes;
}

sub search_volume {
  my ($self, %opts) = @_;
  my $vols;

  if ($self->domain_name) {
    $vols = $self->list_volumes;
  } else {
    $vols = $self->list_all_volumes;
  }

  for my $vol (@{$vols}) {
    return $vol if ($opts{name} && $opts{name} eq $vol->get_name);
    return $vol if ($opts{path} && $opts{path} eq $vol->get_path);
  }
  return;
}

sub create_snapshot {
  my ($self)  = @_;
  my $logger  = $self->logger;
  my $dom     = $self->dom;

  my $xml = '<domainsnapshot><name>'.$self->snapshot_name.'</name></domainsnapshot>';
  my $flags;

  try {
    $dom->create_snapshot($xml, $flags);
  } catch {
    if ($_->message =~ /Error: Migration is disabled when VirtFS export path '.*' is mounted in the guest using mount_tag '(.*)'/) {
      my $share = $1;
      my $con = Kanku::Util::VM::Console->new(
	domain_name => $self->domain_name,
	login_user  => $self->login_user,
	login_pass  => $self->login_pass,
	job_id      => $self->job_id,
	log_file    => $self->log_file,
	log_stdout  => $self->log_stdout,
	no_wait_for_bootloader => 1,
      );

      $con->init();
      $con->login;
      $logger->info("Umount $share");
      $con->cmd("umount $share");
      $logger->info("Retrying to create snapshot");
      $dom->create_snapshot($xml, $flags);
      $logger->info("Mount $share");
      $con->cmd("mount $share");
    } else {
      die $_;
    }

  };
  return;
}

sub remove_snapshot {
  my $self    = shift;
  my $dom     = $self->dom;
  my $snap    = $dom->get_snapshot_by_name($self->snapshot_name);
  $snap->delete();
}

sub revert_snapshot {
  my $self    = shift;
  my $dom     = $self->dom;
  my $snap    = $dom->get_snapshot_by_name($self->snapshot_name);
  $snap->revert_to();
}

sub list_snapshots {
  my $self    = shift;
  return ($self->dom->list_all_snapshots);
}

sub get_disk_list {
  my $self    	= shift;
  my %opts    	= @_;
  my $result    = [];
  my $dom     	= $self->dom;
  my $xml     	= $opts{xml} || $dom->get_xml_description;

  my $xp        = XML::XPath->new( xml => $xml );
  my $xp_result = $xp->find("//domain/devices/disk");

  foreach my $node ($xp_result->get_nodelist) {
	my $disk = {};
	my $sources = $xp->find('./source',$node);
	foreach my $source ( $sources->get_nodelist ) {
	  $disk->{source_file} = $source->getAttribute("file");
	}
	my $targets = $xp->find('./target',$node);
	foreach my $target ( $targets->get_nodelist ) {
	  $disk->{target_device} = $target->getAttribute("dev");
	}
	push(@{$result},$disk);
  }

  return $result;
}

sub state {
  my $self    	= shift;
  my %opts    	= @_;
  my $dom       = $self->dom;

  if ($dom) {
    my $info = $dom->get_info();
    $self->logger->debug("State: $info->{state}");
    if ( $info->{state} == 5 ) {
      return "off";
    } elsif ( $info->{state} == 1 ) {
      return "on";
    } else {
      return "unkown";
    }
  } else {
    die "Domain ".$self->domain_name." does not exists";
  }
}

sub _get_ip_from_console {
  my $self        = shift;
  my $interface   = $self->management_interface() || 'eth0';
  my $con         = $self->console;
  my $need_logout = 0;

  if (!$con->user_is_logged_in) {
    $con->login;
    $need_logout = 1;
  }

  $self->ipaddress(
    $con->get_ipaddress(
      interface => $interface,
      timeout => $self->wait_for_network
    )
  );

  $con->logout if $need_logout;

  return $self->ipaddress();
}

sub _get_ip_from_dhcp {
  my $self          = shift;
  my $domain_name   = $self->domain_name;
  my $dom           = $self->dom;
  my $ipaddress;


  my $wait = $self->wait_for_network;

  while ( $wait > 0) {
      my @nics = $dom->get_interface_addresses(
                   Sys::Virt::Domain::INTERFACE_ADDRESSES_SRC_LEASE
      );

      if (! $self->management_network() ) {
        $ipaddress = $nics[0]->{addrs}->[0]->{addr};
      } else {
          my $mgmt_range    = Net::IP->new($self->management_network());

          for my $nic (@nics) {
            for my $addr (@{$nic->{addrs}}) {
              my $ip = Net::IP->new($addr->{addr});
              if ( $ip->overlaps($mgmt_range) == $IP_A_IN_B_OVERLAP ) {
                $ipaddress = $ip->ip;
              }
            }
          }
      }
      last if $ipaddress;

      $wait--;

      sleep 1;

      $self->logger->debug("Could not get ip address from interface using net-dhcp-leases.");
      $self->logger->debug("Waiting another $wait seconds for network to come up");

  }

  if (! $ipaddress) {
    die "Could not get ip address for interface within "
      . $self->wait_for_network." seconds.";
  }

  return $self->ipaddress($ipaddress);

}

__PACKAGE__->meta->make_immutable;

1;

__DATA__
<domain type='kvm'>
  <name>[% domain.domain_name %]</name>
  <memory unit='KiB'>[% domain.memory %]</memory>
  <currentMemory unit='KiB'>[% domain.memory %]</currentMemory>
  <vcpu placement='static'>[% domain.vcpu %]</vcpu>
  <cpu mode='host-passthrough' check='none'>
    <cache mode='passthrough'/>
    <feature policy='require' name='[% host_feature %]'/>
  </cpu>
  <os>
    <type arch='x86_64' machine='pc'>hvm</type>
  </os>
  <features>
    <acpi/>
    <apic/>
    <pae/>
  </features>
  <clock offset='utc'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>[% qemu_kvm %]</emulator>
    [% domain.disk_xml %]
    <controller type='pci' index='0' model='pci-root'/>
    [% domain.disk_controllers_xml %]
    <interface type='network'>
      <source network='[% domain.network_name %]' bridge='[% domain.network_bridge %]'/>
      <model type='virtio'/>
      <alias name='net0'/>
    </interface>
    <serial type='pty'>
      <target port='0'/>
    </serial>
    <console type='pty'>
      <target type='serial' port='0'/>
    </console>
[% domain.hostshare %]
  </devices>
</domain>
