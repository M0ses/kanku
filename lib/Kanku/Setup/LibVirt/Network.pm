package Kanku::Setup::LibVirt::Network;

use Moose;
use Kanku::YAML;
use Path::Tiny;
use Net::IP;
use POSIX 'setsid';
use IPC::Run qw/run/;
use Carp qw/confess/;
use Kanku::LibVirt::HostList;
use Kanku::Util::IPTables;

with 'Kanku::Roles::Logger';


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

has iptables_autostart_json => (
  is      => 'rw',
  isa     => 'Str',
  default => '/var/lib/kanku/iptables_autostart.json',
);

sub dnsmasq_cfg_file {
  my ($self, $name) = @_;
  confess("No name given") unless $name;
  return path("/var/lib/libvirt/dnsmasq/$name.conf");
}

sub dnsmasq_pid_file {
  my ($self, $name) = @_;
  confess("No name given") unless $name;
  return path("/run/libvirt/network/$name.pid");
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
  my ($self)  = @_;
  my $logger  = $self->logger;
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

    $logger->info("Creating bridge $br");
    system('ovs-vsctl', '--may-exist', 'add-br', $br);
    system('ovs-vsctl', 'set', 'bridge', $br, 'stp_enable=true');

    my $port_counter = 0;
    for my $remote ( @{$lvhl->get_remote_ips} ) {
      $logger->info("Setting up connection for $remote");

      my $port = "$vlan-$port_counter";
      $logger->info("Adding port $port on bridge $br");

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
    $logger->debug("Configuring interface with command '@cmd'");
    system(@cmd);

    # Set interface mode to up
    @cmd = ("ip", "link", "set",$br, "up");
    $logger->debug("Configuring interface with command '@cmd'");
    system(@cmd);

    # Set MTU for bridge interface
    @cmd=(qw/ip link set mtu/, $mtu, $br);
    $logger->debug("Configuring interface with command '@cmd'");
    system(@cmd);
  }
}

sub bridge_down {
  my ($self)  = @_;
  my $logger  = $self->logger;
  my $bridges = $self->bridges;
  $logger->debug("Stopping bridges of network '".$self->name."'");
  for my $ncfg (@$bridges)  {
    my $br   = $ncfg->{bridge};

    $logger->info("Deleting bridge $br");

    system('ovs-vsctl','del-br',$br);

    $logger->error("Deleting bridge $br failed") if $?;
  }
  return;
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
  my ($self)  = @_;
  my $logger  = $self->logger;
  my $bridges = $self->bridges;
  my $name    = $self->name;

  for my $net_cfg (@$bridges) {
    next if (! $net_cfg->{start_dhcp} );

    $ENV{VIR_BRIDGE_NAME} = $net_cfg->{bridge};

    defined (my $kid = fork) or die "Cannot fork: $!\n";
    if ($kid) {
      # Parent runs this block
      $logger->debug("Setting iptables commands");
      my @comment = ('-m','comment','--comment',"Kanku:net:$name");
      system("iptables","-I","INPUT","1","-p","tcp","-i",$net_cfg->{bridge},"--dport","67","-j","ACCEPT",@comment);
      system("iptables","-I","INPUT","1","-p","udp","-i",$net_cfg->{bridge},"--dport","67","-j","ACCEPT",@comment);
      system("iptables","-I","INPUT","1","-p","tcp","-i",$net_cfg->{bridge},"--dport","53","-j","ACCEPT",@comment);
      system("iptables","-I","INPUT","1","-p","udp","-i",$net_cfg->{bridge},"--dport","53","-j","ACCEPT",@comment);
      system("iptables","-I","OUTPUT","1","-p","udp","-o",$net_cfg->{bridge},"--dport","68","-j","ACCEPT",@comment);
    } else {
      # Child runs this block
      setsid or die "Can't start a new session: $!";
      my $conf = $self->dnsmasq_cfg_file($name);
      my $dhcp_script;
      for my $f ('/usr/libexec/libvirt_leaseshelper', '/usr/lib64/libvirt/libvirt_leaseshelper') {
        if (-x $f ) {
          $dhcp_script = $f;
          last;
        }
      }
      confess("Could not find dhcp-script") unless $dhcp_script;

      my @cmd = ('/usr/sbin/dnsmasq',
	         "--conf-file=$conf",
		 "--leasefile-ro",
		 "--dhcp-script=$dhcp_script");
      $logger->debug("@cmd");
      system(@cmd);
      exit 0;
    }
  }
}

sub configure_iptables {
  my ($self)       = @_;
  my $logger       = $self->logger;
  my $net_cfg      = $self->net_cfg;
  my $bridges      = $self->bridges;
  my $name         = $self->name;
  my $ipt          = Kanku::Util::IPTables->new;
  my $chain        = $self->iptables_chain;

  my $forward;

  for my $ncfg (@$bridges) {
    $logger->debug("Starting configuration of iptables");

    next if (! $ncfg->{is_gateway} );

    if ( ! $ncfg->{network} ) {
      $logger->error("No netmask configured");
      next;
    }

    my $ip = new Net::IP ($ncfg->{network});
    if ( ! $ip ) {
      $logger->debug("Bad network configuration");
      next;
    }
    $forward++;

    my $prefix = $ip->prefix;

    $logger->debug("prefix: $prefix");

    my @comment = ('-m','comment','--comment',"Kanku:net:$name");
    my $rules = [
      ["-I","FORWARD","2","-i",$ncfg->{bridge},"-j","REJECT","--reject-with","icmp-port-unreachable",@comment],
      ["-I","FORWARD","2","-o",$ncfg->{bridge},"-j","REJECT","--reject-with","icmp-port-unreachable",@comment],
      ["-I","FORWARD","2","-i",$ncfg->{bridge},"-o","$ncfg->{bridge}","-j","ACCEPT",@comment],
      ["-I","FORWARD","2","-s",$prefix,"-i",$ncfg->{bridge},"-j","ACCEPT",@comment],
      ["-I","FORWARD","2","-d",$prefix,"-o",$ncfg->{bridge},"-m","conntrack","--ctstate","RELATED,ESTABLISHED","-j","ACCEPT",@comment],
      ["-t","nat","-I","POSTROUTING","-s",$prefix,"!","-d",$prefix,"-j","MASQUERADE",@comment],
      ["-t","nat","-I","POSTROUTING","-s",$prefix,"!","-d",$prefix,"-p","udp","-j","MASQUERADE","--to-ports","1024-65535",@comment],
      ["-t","nat","-I","POSTROUTING","-s",$prefix,"!","-d",$prefix,"-p","tcp","-j","MASQUERADE","--to-ports","1024-65535",@comment],
      ["-t","nat","-I","POSTROUTING","-s",$prefix,"-d","255.255.255.255/32","-j","RETURN",@comment],
      ["-t","nat","-I","POSTROUTING","-s",$prefix,"-d","224.0.0.0/24","-j","RETURN",@comment],
    ];

    if (!$ipt->chain_exists('filter', $chain)) {
      unshift @$rules,
        ["-N", $chain],
        ["-I", $chain, "-j", "RETURN", @comment],
        ["-I", "FORWARD", "1", "-j", $chain, @comment];
    }

    if (!$ipt->chain_exists('nat', $chain)) {
      unshift @$rules,
        ['-t', 'nat', '-N', $chain],
        ['-t', 'nat', '-I', $chain, "-j", "RETURN", @comment],
        ["-t", "nat", "-I", "PREROUTING", "1", "-j", $chain, @comment];
    }


    for my $rule (@{$rules}) {
      $logger->debug("Adding rule: iptables @{$rule}");
      my @ipt;
      my @cmd = ("iptables",@{$rule});
      run \@cmd, \$ipt[0],\$ipt[1],\$ipt[2];
      if ( $? ) {
	$logger->error("Failed while executing '@cmd'");
	$logger->error("Error: $ipt[2]");
      }
    }
  }
  `sysctl net.ipv4.ip_forward=1` if $forward;

  my $json_file = $self->iptables_autostart_json;
  if (-f $json_file) {
    $ipt->restore_iptables_autostart($json_file);
    unlink $json_file;
  } else {
    $logger->debug("Could not find $json_file");
  }
  return 0;
}

sub kill_dhcp {
  my ($self) = @_;
  my $logger = $self->logger;

  my $pid_file = $self->dnsmasq_pid_file($self->name);
  return if ( ! -f $pid_file );

  my $pid = $pid_file->slurp;
  $logger->debug("Killing dnsmasq with pid $pid");

  kill 'TERM', $pid;
}

sub cleanup_iptables {
  my ($self)  = @_;
  my $logger  = $self->logger;
  my $bridges = $self->bridges;
  my $name    = $self->name;

  $logger->info("Starting cleanup_iptables for network $name");

  my $ipt = Kanku::Util::IPTables->new;
  my $json_file = $self->iptables_autostart_json;
  $logger->debug("Storing $json_file");
  $ipt->store_iptables_autostart($json_file);

  for my $ncfg (@$bridges) {
    my $ncfg = $self->net_cfg;
    my $rules_to_delete = {
      'filter' => {
	'INPUT'               => [],
	'OUTPUT'              => [],
	'FORWARD'             => [],
	$self->iptables_chain => [],
      },
      'nat' => {
	'PREROUTING'          => [],
	'POSTROUTING'         => [],
	$self->iptables_chain => [],
      }
    };

    for my $table (keys %$rules_to_delete) {
      for my $chain (keys %{$rules_to_delete->{$table}}) {
        if ($ipt->chain_exists($table, $chain)) {
          my @rules = $ipt->_get_rules_from_chain($table, $chain);
	  for my $rule (@rules) {
	    $logger->debug("Cleaning chain $chain in table $table  $rule->{comment}");
            push @{$rules_to_delete->{$table}->{$chain}}, $rule->{line_number} if $rule->{comment} eq "Kanku:net:$name";
	  }
        }
      }
    }

    $logger->info("Cleaning iptables rules");
    for my $table (keys(%{$rules_to_delete})) {
      for my $chain (keys(%{$rules_to_delete->{$table}}) ) {
	# cleanup from the highest number to keep numbers consistent
	$logger->debug("Cleaning chain $chain in table $table");
	for my $number ( reverse @{$rules_to_delete->{$table}->{$chain}} ) {
	  $logger->debug("... deleting from chain $chain rule number $number");
	  # security not relevant here because we have trusted input
	  # from 'iptables -L ...'
	  my @cmd_output = `iptables -t $table -D $chain $number 2>&1`;
	  if ( $? ) {
            $logger->error("An error occured while deleting rule $number from chain $chain : @cmd_output");
	  }
	}
      }
    }
    my $chain = $self->iptables_chain;
    if ($ipt->chain_exists('filter', $chain)) {
      my @f_rules = $ipt->_get_rules_from_chain('filter', $chain);
      if (@f_rules <= 1) {
        $logger->debug("Removing filter/$chain");
	`iptables -F $chain`;
	`iptables -X $chain`;
      }
    }
    if ($ipt->chain_exists('nat', $chain)) {
      my @n_rules = $ipt->_get_rules_from_chain('nat', $chain);
      if (@n_rules <= 1) {
        $logger->debug("Removing nat/$chain");
	`iptables -t nat -F $chain`;
	`iptables -t nat -X $chain`;
      }
    }
  }
}

1;

