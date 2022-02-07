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
  @net_cfg = @net_list;
} else {
  for my $net (@net_list) {
    next if ($net->{name} ne $current_network_name);
    push @net_cfg, $net;
  }
}

for my $ncfg (@net_cfg) {
  my $setup = Kanku::Setup::LibVirt::Network->new(net_cfg=>$ncfg,name=>$current_network_name);
  try {
    if ( $action eq 'start' ) {
      $setup->prepare_ovs();
    }

    if ( $action eq 'started' ) {
      $setup->prepare_dns();
      $setup->start_dhcp();
      $setup->configure_iptables();
    }

    if ( $action eq 'stopped' ) {
      $setup->kill_dhcp();
      $setup->cleanup_iptables;
      $setup->bridge_down;
    }
  } catch {
    $logger->error("$0 $current_network_name $action failed:");
    $logger->error($_);
    die "Died because of previous errors - have a look into /var/log/kanku/network-setup.log for detailed information.\n";
  };
}

$logger->info("Current network name ($current_network_name) did not found in our configs");
exit 0;
