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
package Kanku::Handler::SetupNetwork;

use Moose;
use Data::Dumper;
use JSON::XS;
use Kanku::Util::VM;
use Kanku::Util::VM::Console;
use Kanku::Config;
use Try::Tiny;

sub gui_config {[]}
sub distributable { 1 }
with 'Kanku::Roles::Handler';

has [qw/domain_name login_user login_pass/] => (
  is      => 'rw',
  isa     => 'Str',
  lazy    => 1,
  default => q{},
);

has 'interfaces' => (
  is      => 'rw',
  isa     => 'ArrayRef',
  builder => '_build_interfaces',
);
sub _build_interfaces {[]}

has 'resolv' => (
  is  => 'rw',
  isa => 'HashRef|Undef'
);

has 'routes' => (
  is      =>'rw',
  isa     =>'HashRef',
  lazy    => 1,
  builder => '_build_routes',
);
sub _build_routes {{}}

has '_mac_table' => (
  is      => 'rw',
  isa     => 'HashRef',
  lazy    => 1,
  builder => '_build__mac_table',
);
sub _build__mac_table {{}}

has '_con' => (
  is      => 'rw',
  isa     => 'Object',
  lazy    => 1,
  builder => '_build__con',
);
sub _build__con {
  my ($self) = @_;
  my $ctx    = $self->job()->context();
  return Kanku::Util::VM::Console->new(
    domain_name => $self->domain_name,
    login_user  => $self->login_user(),
    login_pass  => $self->login_pass(),
    job_id      => $self->job->id,
    log_file    => $ctx->{log_file} || q{},
    log_stdout  => defined ($ctx->{log_stdout}) ? $ctx->{log_stdout} : 1,
    no_wait_for_bootloader => 1,
  );
}

has '_requires_restart'       => (is=>'rw', isa=>'Bool', default=>0);
has '_get_ipaddress_required' => (is=>'rw', isa=>'Bool', default=>1);
has '_management_interface'   => (is=>'rw', isa=>'Str' , default=>q{});

sub prepare {
  my $self = shift;
  my $ctx  = $self->job()->context();

  $self->domain_name($ctx->{domain_name}) if ( ! $self->domain_name && $ctx->{domain_name});
  $self->evaluate_console_credentials;

  return {
    code    => 0,
    message => "Nothing todo"
  };
}

sub execute {
  my ($self) = @_;
  my $cfg    = Kanku::Config->instance()->config();
  my $ctx    = $self->job()->context();
  my $logger = $self->logger;
  my $con    = $self->_con;

  $con->init();
  $con->login();

  my $iinfo = $self->_get_interface_info();

  $self->prepare__mac_table($cfg, $iinfo);

  $self->_configure_interfaces;

  $self->_configure_resolver;

  $self->_configure_routes;

  if ($self->_get_ipaddress_required) {
    $ctx->{ipaddress} = $con->get_ipaddress(interface=>$self->_management_interface,timeout=>60);
  }

  $con->logout();

  return {
    code    => 0,
    message => "Successfully setup network for domain " . $self->domain_name
  }
}

sub prepare__mac_table {
  my ($self, $cfg, $iinfo) = @_;
  for my $cfg (@{$self->interfaces}) {
    for my $i (@$iinfo) {
      if ($i->{ifname} eq $cfg->{if_name}) {
	$self->_mac_table->{$i->{ifname}}  = $i->{address};
	$self->_mac_table->{$i->{address}} = $i->{ifname};
      }
    }
  }
}

sub _configure_resolver {
  my ($self) = @_;
  my $con    = $self->_con;

  return undef if (ref($self->resolv) ne 'HASH');

  my $config_str  = "";
  my @nameserver;
  my @searchlist;
  my $config_file = "/etc/resolv.conf";

  for my $key ( keys(%{$self->resolv}) ) {
    if ($key eq 'nameserver') {
      for my $dns ( @{$self->resolv()->{$key}} ) {
        $config_str .= "nameserver $dns\\n";
        push @nameserver, $dns;
      }
    } else {
      my $val = $self->resolv()->{$key};
      $self->logger->debug("_configure_resolver $key - $val");
      $config_str .= "$key $val\\n";
      push @searchlist, $val if $key eq "search";
    }
  }

  my $resolv_conf = 'echo -en "'.$config_str.'" >'.$config_file;
  $con->cmd($resolv_conf);
  my $nw_cfg = "/etc/sysconfig/network/config";
  $con->cmd("perl -p -i -e 's/.*NETCONFIG_DNS_STATIC_SEARCHLIST=.*/NETCONFIG_DNS_STATIC_SEARCHLIST=\"@searchlist\"/' $nw_cfg ||/bin/true");
  $con->cmd("perl -p -i -e 's/.*NETCONFIG_DNS_STATIC_SERVERS=.*/NETCONFIG_DNS_STATIC_SERVERS=\"@nameserver\"/' $nw_cfg ||/bin/true");
  $con->cmd("netconfig update -f || /bin/true");

  return 1;
}

sub _configure_routes {
  my ($self)   = @_;
  my $logger   = $self->logger;
  my $con      = $self->_con;
  my $cfg_file = '/etc/sysconfig/network/routes';
  my $routes   = $self->routes;
  my $string   = '';
  for my $key (keys %$routes) {
    my $r    = $routes->{$key};
    my $nm   = $r->{netmask} || '-';
    my $dev  = $r->{device}  || '-';
    $string .= $key.' '.$r->{gw}.' '.$nm.' '.$dev.'\n';
    $con->cmd("ip route del $key || /bin/true");
    $con->cmd("ip route add $key via $r->{gw}");
  }
  $con->cmd("echo -en \"$string\" > $cfg_file");
}

sub _configure_interfaces {
  my ($self) = @_;
  my $con    = $self->_con;
  my $logger = $self->logger;

  $logger->debug("Starting _configure_interfaces");
  for my $cfg (@{$self->interfaces}) {
    my $interface    = $cfg->{if_name};
    my $final_ifname = $cfg->{rename} || $interface;
    $logger->debug("Configuring interface $interface (final_ifname: $final_ifname)");
    if ($cfg->{rename}) {
      $con->cmd("ifdown $interface");
      $self->_configure_persistent_udev_rules($interface, $cfg);
    }
    my $config_str  = "";
    my $config_file = "/etc/sysconfig/network/ifcfg-$final_ifname";
    my $acfg = {STARTMODE=>'auto', BOOTPROTO=>"dhcp", %{$cfg}};
    $logger->debug("Dump \$cfg\n".Dumper($cfg));
    for my $key (keys %{$acfg}) {
      next if ($key =~ /^[a-z]/);
      my $val = $acfg->{$key};
      $config_str .= "$key=\"$val\"\\n";
    }

    if ($acfg->{is_mgmt_if}) {
      $self->_management_interface($final_ifname);
      if ($acfg->{IPADDR}) {
        my @ip = split('/', $acfg->{IPADDR},2);
        my $ctx  = $self->job()->context();
        $ctx->{ipaddress} = $ip[0];
        $self->_get_ipaddress_required(0);
      }
    }

    my $create_config = 'echo -en "'.$config_str.'" > '.$config_file;
    $logger->debug("Create config command:\n$create_config");
    $con->cmd($create_config);

    my $if_command    = "ifup $final_ifname";
    $logger->debug("ifup command:\n$if_command");
    $con->cmd($if_command);
  }

  $con->cmd("systemctl enable --now wickedd");
}

sub _configure_persistent_udev_rules {
  my ($self, $interface, $cfg) = @_;
  my $con                      = $self->_con;
  my $rename                   = $cfg->{rename};

  return unless ($rename);

  # SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="52:54:00:33:79:73", ATTR{type}=="1", KERNEL=="eth*", NAME="pbu"
  # /etc/udev/rules.d/70-persistent-net.rules
  my $mac = $self->_mac_table->{$interface} || $self->_mac_table->{$rename};
  if (!$mac) {
    $self->logger->debug("No mac found for $interface/$rename");
    return;
  }
  $con->cmd("rm -f /etc/sysconfig/network/ifcfg-$interface");
  # Remove persistent rules to avoid confusion with our rules
  $con->cmd("rm -f /etc/udev/rules.d/70-persistent-net.rules");

  # The NAME attribute needs the colon to prevent later rules
  # from overwriting the given values
  my $string='SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="'.$mac.'", ATTR{type}=="1", KERNEL=="eth*", NAME:="'.$rename.'"';

  # Place our persistent net rules before 70-persistent-net.rules
  # (using 00-persistent-net-$rename.rules) to make sure that these
  # rules are executed first
  # The "NAME:=" attribute from $string will prevent overwriting our names
  #
  my $fn = "/etc/udev/rules.d/00-persistent-net-$rename.rules";
  $con->cmd("echo '$string' > $fn");
  $con->cmd("ip link set $interface name $rename");
}

sub _get_interface_info {
  my ($self, $interface) = @_;
  my $con = $self->_con;

  my $network_info = $con->cmd('LANG=C ip -j address show '.($interface||q{}))->[0];
  my @json_string = split(/\n/,$network_info);
  my $iinfo = decode_json($json_string[1]);
  return $iinfo->[0] if $interface;
  die "Something unexpected happend - first interface is expected to be lo\n$json_string[1]\n" unless ($iinfo->[0]->{ifname} eq 'lo');
  # remove loopback interface from list of interfaces
  shift @$iinfo;
  return $iinfo;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Kanku::Handler::SetupNetwork

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::SetupNetwork
    options:
      interfaces:
        -
          if_name: eth0
          BOOTPROTO: dhcp
        -
          if_name: eth1
	  rename: newdev
          BOOTPROTO: static
          IPADDR: 192.168.122.22/24
      resolv:
        nameserver:
          - 192.168.122.1
        search: opensuse.org local.site
        domain: local.site
      routes:
        10.1.1.0:
	  gw: 192.168.122.1
          netmask: 255.255.255.0
	  device: eth1


=head1 DESCRIPTION

This handler set`s up your Network configuration

=head1 OPTIONS

  interfaces - An array of strings which include your public ssh key

=head1 CONTEXT

=head1 DEFAULTS

=cut
