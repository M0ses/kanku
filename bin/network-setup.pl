#!/usr/bin/env perl

use strict;
use warnings;
use Log::Log4perl;
use Try::Tiny;

BEGIN {
  unshift @::INC, ($ENV{KANKU_LIB_DIR} || '/usr/lib/kanku/lib');
}

use Kanku::Setup::LibVirt::Network;

my $conf_dir = $::ENV{KANKU_ETC_DIR} || '/etc/kanku';

Log::Log4perl->init("$conf_dir/logging/network-setup.conf");

my $logger = Log::Log4perl->get_logger();

my $current_network_name = $ARGV[0];
my $action               = $ARGV[1];
my $cfg                  = Kanku::YAML::LoadFile("/etc/kanku/kanku-config.yml");
my @net_list;
my @net_cfg;

$logger->info("$0 started with network '$current_network_name' -> '$action'");

if (ref($cfg->{'Kanku::LibVirt::Network::OpenVSwitch'}) eq 'ARRAY') {
  @net_list = @{$cfg->{'Kanku::LibVirt::Network::OpenVSwitch'}}
} elsif (ref($cfg->{'Kanku::LibVirt::Network::OpenVSwitch'}) eq 'HASH') {
  push @net_list, $cfg->{'Kanku::LibVirt::Network::OpenVSwitch'};
} else {
   $logger->warn("No valid config found for Kanku::LibVirt::Network::OpenVSwitch");
   exit 0;
}

if ($current_network_name eq '-') {
  $logger->info("Adding all networks");
  @net_cfg = @net_list;
} else {
  for my $net (@net_list) {
    next if ($net->{name} ne $current_network_name);
    $logger->info("Adding network: $net->{name}");
    push @net_cfg, $net;
  }
}

for my $ncfg (@net_cfg) {
  my $setup = Kanku::Setup::LibVirt::Network->new(net_cfg=>$ncfg,name=>$ncfg->{name});
  try {
    if ( $action eq 'start' ) {
      $setup->prepare_ovs();
    }

    if ( $action eq 'started' ) {
      $setup->prepare_dns();
      $setup->start_dhcp();
    }

    if ( $action eq 'stopped' ) {
      $setup->kill_dhcp();
      $setup->bridge_down;
    }

    if ( $action eq 'cleanup_iptables' ) {
      $setup->cleanup_iptables;
    }

    if ( $action eq 'configure_iptables' ) {
      $setup->configure_iptables;
    }
  } catch {
    $logger->error("$0 $current_network_name $action failed:");
    $logger->error($_);
    die "Died because of previous errors - have a look into /var/log/kanku/network-setup.log for detailed information.\n";
  };
}

exit 0;
