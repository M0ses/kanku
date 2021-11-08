package Kanku::Setup::LibVirt::Network;

use Moose;
use Kanku::YAML;
use Path::Class qw/file/;
use Net::IP;
use POSIX 'setsid';
use IPC::Run qw/run/;
use Carp qw/confess/;
use Kanku::LibVirt::HostList;


has cfg_file => (
  is      => 'rw',
  isa     => 'Str',
  lazy    => 1,
  default => "/etc/kanku/kanku-config.yml"
);

has cfg => (
	is => 'rw',
	isa => 'HashRef',
	lazy => 1,
	default => sub { Kanku::YAML::LoadFile($_[0]->cfg_file) }
);

has logger => (
	is => 'rw',
	isa => 'Object',
	lazy => 1,
	default => sub { Log::Log4perl->get_logger() }
);

has iptables_chain => (
	is => 'rw',
	isa => 'Str',
	lazy => 1,
	default => sub { $_[0]->net_cfg->{iptables_chain} || 'KANKU_HOSTS' }

);

has net_cfg => (
  is => 'rw',
  isa => 'HashRef',
  lazy => 1,
  default => sub { {} },
);

has name => (
  is => 'rw',
  isa => 'Str',
  required => 1,
);

sub dnsmasq_cfg_file {
  my ($self, $name) = @_;
  confess("No name given") unless $name;
  return file("/var/lib/libvirt/dnsmasq/$name.conf");
}

sub dnsmasq_pid_file {
  my ($self, $name) = @_;
  confess("No name given") unless $name;
  return file("/run/libvirt/network/$name.pid");
}

sub bridges {
  my ($self) = @_;
  my $ncfg   = $self->net_cfg;
  return $ncfg->{bridges} || [
    {
      bridge  => $ncfg->{bridge},
      vlan    => $ncfg->{vlan},
      mtu     => $ncfg->{mtu} || '1450',
      network => $ncfg->{network},
      host_ip => $ncfg->{host_ip},
      start_dhcp => $ncfg->{start_dhcp},
      name       => $ncfg->{name},
      dhcp_range => $ncfg->{dhcp_range},
    }
  ];
}

sub prepare_ovs {
  my ($self) = @_;
  my $bridges = $self->bridges;

  for my $ncfg (@$bridges) {
    my $br   = $ncfg->{bridge};
    my $vlan = $ncfg->{vlan};

    die "missing vlan for bridge $ncfg->{bridge} in your kanku-config.yml for network ".$self->name unless $vlan;

    # Standard mtu size is 1500 bytes
    # VXLAN header is 50 bytes
    # 1500 - 50 = 1450
    my $mtu  = $ncfg->{mtu} || '1450';
    my $lvhl = Kanku::LibVirt::HostList->new();
    my $out;
    my $fh;


    $self->logger->info("Creating bridge $br");
    system('ovs-vsctl', '--may-exist', 'add-br', $br);
    system('ovs-vsctl', 'set', 'bridge', $br, 'stp_enable=true');

    my $port_counter = 0;
    for my $remote ( @{$lvhl->get_remote_ips} ) {
      $self->logger->info("Setting up connection for $remote");
      my $port = "$vlan-$port_counter";
      $self->logger->info("Adding port $port on bridge $br");
      system('ovs-vsctl', '--may-exist', 'add-port', $br, $port);
      my @cmd = ('ovs-vsctl','set','Interface',$port,'type=vxlan',"options:remote_ip=$remote");
      push @cmd, "options:dst_port=$ncfg->{dst_port}" if $ncfg->{dst_port};
      system(@cmd);
      $port_counter++;
    }

    # Set ip address for bridge interface
    my @cmd;
    my $ip = new Net::IP ($ncfg->{network});
    @cmd = ("ip", "addr", "add", "$ncfg->{host_ip}/".$ip->mask, 'dev', $br);
    $self->logger->debug("Configuring interface with command '@cmd'");
    system(@cmd);

    # Set interface mode to up
    @cmd = ("ip", "link", "set",$br, "up");
    $self->logger->debug("Configuring interface with command '@cmd'");
    system(@cmd);

    # Set MTU for bridge interface
    @cmd=(qw/ip link set mtu/, $mtu, $br);
    $self->logger->debug("Configuring interface with command '@cmd'");
    system(@cmd);
  }
}

sub bridge_down {
  my $self = shift;
  my $bridges = $self->bridges;
  $self->logger->debug("Stopping bridges of network '".$self->name."'");
  for my $ncfg (@$bridges)  {
    my $br   = $ncfg->{bridge};

    $self->logger->info("Deleting bridge $br");

    system('ovs-vsctl','del-br',$br);

    if ( $? > 0 ) {
      $self->logger->error("Deleting bridge $br failed");
    }
  }
}

sub prepare_dns {
  my ($self)  = @_;
  my $bridges = $self->bridges;
  my $name = $self->name;

  for my $net_cfg (@$bridges) {
    next if (! $net_cfg->{start_dhcp} );

    my $pid_file  = $self->dnsmasq_pid_file($name)->stringify ;
    my $addnfile  = "/var/lib/libvirt/dnsmasq/$name.addnhosts";
    my $addn      = (-f $addnfile) ? "addn-hosts=$addnfile" : q{};
    my $hostsfile = "/var/lib/libvirt/dnsmasq/$name.hostsfile";
    my $host      = (-f $hostsfile) ? "dhcp-hostsfile=$hostsfile" : q{} ;

    my $dns_config = <<EOF
##WARNING:  THIS IS AN AUTO-GENERATED FILE. CHANGES TO IT ARE LIKELY TO BE
##OVERWRITTEN AND LOST.  Changes to this configuration should be made using:
##    virsh net-edit default
## or other application using the libvirt API.
##
## dnsmasq conf file created by kanku
strict-order
pid-file=$pid_file
except-interface=lo
bind-dynamic
interface=$net_cfg->{bridge}
dhcp-range=$net_cfg->{dhcp_range}
dhcp-no-override
dhcp-lease-max=253
$host
$addn
EOF
;
    $self->dnsmasq_cfg_file($name)->spew($dns_config);
  }
}

sub start_dhcp {
  my ($self) = @_;
  my $bridges = $self->bridges;
  my $name    = $self->name;

  for my $net_cfg (@$bridges) {
    next if (! $net_cfg->{start_dhcp} );

    $ENV{VIR_BRIDGE_NAME} = $net_cfg->{bridge};

    defined (my $kid = fork) or die "Cannot fork: $!\n";
    if ($kid) {
      # Parent runs this block
      $self->logger->debug("Setting iptables commands");
      system("iptables","-I","INPUT","1","-p","tcp","-i",$net_cfg->{bridge},"--dport","67","-j","ACCEPT");
      system("iptables","-I","INPUT","1","-p","udp","-i",$net_cfg->{bridge},"--dport","67","-j","ACCEPT");
      system("iptables","-I","INPUT","1","-p","tcp","-i",$net_cfg->{bridge},"--dport","53","-j","ACCEPT");
      system("iptables","-I","INPUT","1","-p","udp","-i",$net_cfg->{bridge},"--dport","53","-j","ACCEPT");
      system("iptables","-I","OUTPUT","1","-p","udp","-o",$net_cfg->{bridge},"--dport","68","-j","ACCEPT");
    } else {
      # Child runs this block
      setsid or die "Can't start a new session: $!";
      my $conf = $self->dnsmasq_cfg_file($name);
      my @cmd = ('/usr/sbin/dnsmasq',
	         "--conf-file=$conf",
		 "--leasefile-ro",
		 "--dhcp-script=/usr/lib64/libvirt/libvirt_leaseshelper");
      $self->logger->debug("@cmd");
      system(@cmd);
      exit 0;
    }
  }
}

sub configure_iptables {
  my $self	= shift;
  my $net_cfg	= $self->net_cfg;
  my $bridges = $self->bridges;
  my $forward;
  for my $ncfg (@$bridges) {
    $self->logger->debug("Starting configuration of iptables");

    next if (! $ncfg->{is_gateway} );

    if ( ! $ncfg->{network} ) {
      $self->logger->error("No netmask configured");
      next;
    }

    my $ip = new Net::IP ($ncfg->{network});
    if ( ! $ip ) {
      $self->logger->debug("Bad network configuration");
      next;
    }
    $forward++;

    my $prefix = $ip->prefix;

    $self->logger->debug("prefix: $prefix");

    my $rules = [
      ["-X",$self->iptables_chain],
      ["-N",$self->iptables_chain],
      ["-I",$self->iptables_chain, "-j","RETURN"],
      ["-I","FORWARD","1","-i",$ncfg->{bridge},"-j","REJECT","--reject-with","icmp-port-unreachable"],
      ["-I","FORWARD","1","-o",$ncfg->{bridge},"-j","REJECT","--reject-with","icmp-port-unreachable"],
      ["-I","FORWARD","1","-i",$ncfg->{bridge},"-o","$ncfg->{bridge}","-j","ACCEPT"],
      ["-I","FORWARD","1","-s",$prefix,"-i",$ncfg->{bridge},"-j","ACCEPT"],
      ["-I","FORWARD","1","-j",$self->iptables_chain],
      ["-I","FORWARD","1","-d",$prefix,"-o",$ncfg->{bridge},"-m","conntrack","--ctstate","RELATED,ESTABLISHED","-j","ACCEPT"],
      ["-t","nat","-I","POSTROUTING","-s",$prefix,"!","-d",$prefix,"-j","MASQUERADE"],
      ["-t","nat","-I","POSTROUTING","-s",$prefix,"!","-d",$prefix,"-p","udp","-j","MASQUERADE","--to-ports","1024-65535"],
      ["-t","nat","-I","POSTROUTING","-s",$prefix,"!","-d",$prefix,"-p","tcp","-j","MASQUERADE","--to-ports","1024-65535"],
      ["-t","nat","-I","POSTROUTING","-s",$prefix,"-d","255.255.255.255/32","-j","RETURN"],
      ["-t","nat","-I","POSTROUTING","-s",$prefix,"-d","224.0.0.0/24","-j","RETURN"],
    ];

    for my $rule (@{$rules}) {
      $self->logger->debug("Adding rule: iptables @{$rule}");
      my @ipt;
      my @cmd = ("iptables",@{$rule});
      run \@cmd, \$ipt[0],\$ipt[1],\$ipt[2];
      if ( $? ) {
	$self->logger->error("Failed while executing '@cmd'");
	$self->logger->error("Error: $ipt[2]");
      }
    }
  }
  system('sysctl net.ipv4.ip_forward=1') if $forward;

  return 0;
}

sub kill_dhcp {
  my ($self) = @_;

  my $pid_file = $self->dnsmasq_pid_file($self->name);
  return if ( ! -f $pid_file );

  my $pid = $pid_file->slurp;
  $self->logger->debug("Killing dnsmasq with pid $pid");

  kill 'TERM', $pid;
}

sub cleanup_iptables {
  my ($self)  = @_;
  my $bridges = $self->bridges;
  for my $ncfg (@$bridges) {
    my $ncfg = $self->net_cfg;
    my $rules_to_delete = {
      'filter' => {
	'INPUT' 	=> [],
	'OUTPUT'	=> [],
	'FORWARD'	=> [],
      },
      'nat' => {
	'POSTROUTING'	=> [],
      }
    };

    $self->logger->info("Cleaning iptables rules");
    my @cmdout;
    @cmdout = `iptables -L OUTPUT -n -v --line-numbers`;

    for my $line (@cmdout ) {
	    my @args = split(/\s+/,$line,10);
	    # check if outgoing interface matches
	    $self->logger->debug("Values: $args[7] eq $ncfg->{bridge}");
	    if ( $args[7] eq $ncfg->{bridge} ) {
		    # remember line numbers
		    push(@{$rules_to_delete->{filter}->{OUTPUT}},$args[0]);
	    }
    }

    @cmdout = `iptables -L INPUT -n -v --line-numbers`;

    for my $line (@cmdout ) {
	    my @args = split(/\s+/,$line,10);
	    # check if incomming interface matches
	    $self->logger->debug("Values: $args[6] eq $ncfg->{bridge}");
	    if ( $args[6] eq $ncfg->{bridge} ) {
		    # remember line numbers
		    push(@{$rules_to_delete->{filter}->{INPUT}},$args[0]);
	    }
    }


    my $ip = new Net::IP ($ncfg->{network});
    if ( ! $ip ) {
	    $self->logger->debug("Bad network configuration");
	    next;
    }

    my $prefix = $ip->prefix;
    my $netreg = qr/!?\Q$prefix\E/;
    my $brreg  = $ncfg->{bridge};

    @cmdout = `iptables -L FORWARD -n -v --line-numbers`;

    for my $line (@cmdout ) {
	    my @args = split(/\s+/,$line,11);
	    # check if incomming interface matches
	    $self->logger->debug("Values: $netreg -> $args[8] / $args[9]");
	    if (
		    $args[8] =~ $netreg
		    || $args[9] =~ $netreg
		    || $args[7] =~ /$brreg/
		    || $args[6] =~ /$brreg/
		    || $args[3] eq $self->iptables_chain
	    ) {
		    # remember line numbers
		    push(@{$rules_to_delete->{filter}->{FORWARD}},$args[0]);
	    }
    }

    @cmdout = `iptables -t nat -L POSTROUTING -n -v --line-numbers`;

    for my $line (@cmdout ) {
	    my @args = split(/\s+/,$line,11);
	    # check if incomming interface matches
	    $self->logger->debug("Values: $netreg -> $args[8] / $args[9]");
	    if (
		    $args[8] =~ $netreg
		    || $args[9] =~ $netreg
		    || $args[7] =~ /$brreg/
		    || $args[6] =~ /$brreg/
	    ) {
		    # remember line numbers
		    $self->logger->debug("Adding line $args[0]");
		    push(@{$rules_to_delete->{nat}->{POSTROUTING}},$args[0]);
	    }
    }

    for my $table (keys(%{$rules_to_delete})) {
	    for my $chain (keys(%{$rules_to_delete->{$table}}) ) {
		    # cleanup from the highest number to keep numbers consistent
		    $self->logger->debug("Cleaning chain $chain in table $table");
		    for my $number ( reverse @{$rules_to_delete->{$table}->{$chain}} ) {
			    $self->logger->debug("... deleting from chain $chain rule number $number");
			    # security not relevant here because we have trusted input
			    # from 'iptables -L ...'
			    my @cmd_output = `iptables -t $table -D $chain $number 2>&1`;
			    if ( $? ) {
				    $self->logger->error("An error occured while deleting rule $number from chain $chain : @cmd_output");
			    }
		    }

	    }
    }
    my $chain = $self->iptables_chain;
    `iptables -F $chain`;
    `iptables -X $chain`;
  }
}
1;

