#!/usr/bin/env perl

# Copyright (c) 2026 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

use strict;
use warnings;

use Test::More;
use Path::Tiny;
use Kanku::Test::MockLogger;

#
# Minimal mock console object supporting cmd responses and logging
#
{
  package TestConsole;
  use Moose;

  has 'logger' => (
    is      => 'ro',
    default => sub { Kanku::Test::MockLogger->new() },
  );

  has 'last_cmd' => (is => 'rw', isa => 'ArrayRef', default => sub { [] });
  has 'cmd_handler' => (is => 'rw', isa => 'CodeRef');

  sub cmd {
    my ($self, @cmds) = @_;
    $self->last_cmd(\@cmds);
    if ($self->cmd_handler) {
      return $self->cmd_handler->(@cmds);
    }
    return ["mock_output\r\n"];
  }

  sub login  { return 1 }
  sub logout { return 1 }
}

use_ok('Kanku::Util::VM::Network::Role');
use_ok('Kanku::Util::VM::Network::SystemdNetworkd');
use_ok('Kanku::Util::VM::Network::Wicked');
use_ok('Kanku::Util::VM::Network::NetworkManager');
use_ok('Kanku::Util::VM::Network::Ifupdown');
use_ok('Kanku::Util::VM::Network::Sysconfig');
use_ok('Kanku::Util::VM::Network::Generic');
use_ok('Kanku::Util::VM::Network::Factory');

#
# 1. Test Factory Framework Detection
#
subtest 'Factory detection' => sub {
  my $tc = TestConsole->new();

  # Detect systemd-networkd
  $tc->cmd_handler(sub {
    return ["cmd\r\nsystemd-networkd\r\n"];
  });
  is(
    Kanku::Util::VM::Network::Factory->detect($tc),
    'systemd-networkd',
    'detects systemd-networkd'
  );

  # Detect wicked
  $tc->cmd_handler(sub {
    return ["cmd\r\nwicked\r\n"];
  });
  is(
    Kanku::Util::VM::Network::Factory->detect($tc),
    'wicked',
    'detects wicked'
  );

  # Detect NetworkManager
  $tc->cmd_handler(sub {
    return ["cmd\r\nNetworkManager\r\n"];
  });
  is(
    Kanku::Util::VM::Network::Factory->detect($tc),
    'NetworkManager',
    'detects NetworkManager'
  );

  # Detect ifupdown
  $tc->cmd_handler(sub {
    return ["cmd\r\nifupdown\r\n"];
  });
  is(
    Kanku::Util::VM::Network::Factory->detect($tc),
    'ifupdown',
    'detects ifupdown'
  );

  # Detect sysconfig
  $tc->cmd_handler(sub {
    return ["cmd\r\nsysconfig\r\n"];
  });
  is(
    Kanku::Util::VM::Network::Factory->detect($tc),
    'sysconfig',
    'detects sysconfig'
  );

  # Fallback to ip
  $tc->cmd_handler(sub {
    return ["cmd\r\nip\r\n"];
  });
  is(
    Kanku::Util::VM::Network::Factory->detect($tc),
    'ip',
    'falls back to ip'
  );
};

#
# 2. Test Factory Instance Creation
#
subtest 'Factory creation' => sub {
  my $tc = TestConsole->new();

  my $sn = Kanku::Util::VM::Network::Factory->create(
    console   => $tc,
    framework => 'systemd-networkd',
  );
  isa_ok($sn, 'Kanku::Util::VM::Network::SystemdNetworkd');
  is($sn->name, 'systemd-networkd', 'SystemdNetworkd name matches');

  my $wk = Kanku::Util::VM::Network::Factory->create(
    console   => $tc,
    framework => 'wicked',
  );
  isa_ok($wk, 'Kanku::Util::VM::Network::Wicked');
  is($wk->name, 'wicked', 'Wicked name matches');

  my $nm = Kanku::Util::VM::Network::Factory->create(
    console   => $tc,
    framework => 'NetworkManager',
  );
  isa_ok($nm, 'Kanku::Util::VM::Network::NetworkManager');
  is($nm->name, 'NetworkManager', 'NetworkManager name matches');

  my $iu = Kanku::Util::VM::Network::Factory->create(
    console   => $tc,
    framework => 'ifupdown',
  );
  isa_ok($iu, 'Kanku::Util::VM::Network::Ifupdown');
  is($iu->name, 'ifupdown', 'Ifupdown name matches');

  my $sc = Kanku::Util::VM::Network::Factory->create(
    console   => $tc,
    framework => 'sysconfig',
  );
  isa_ok($sc, 'Kanku::Util::VM::Network::Sysconfig');
  is($sc->name, 'sysconfig', 'Sysconfig name matches');

  my $gn = Kanku::Util::VM::Network::Factory->create(
    console   => $tc,
    framework => 'ip',
  );
  isa_ok($gn, 'Kanku::Util::VM::Network::Generic');
  is($gn->name, 'ip', 'Generic name matches');
};

#
# 3. Test SystemdNetworkd operations
#
subtest 'SystemdNetworkd adapter operations' => sub {
  my $tc = TestConsole->new();
  my $adapter = Kanku::Util::VM::Network::SystemdNetworkd->new(console => $tc);
  $adapter->tool(path('/usr/bin/networkctl'));

  # IP extraction
  $tc->cmd_handler(sub {
    return [
      "networkctl status eth0\r\n"
      . "● 2: eth0\r\n"
      . "       Link File: /usr/lib/systemd/network/99-default.link\r\n"
      . "    Network File: /usr/lib/systemd/network/20-wired.network\r\n"
      . "           State: routable (configured)\r\n"
      . "         Address: 192.168.101.42 (DHCP4 via 192.168.101.1)\r\n"
    ];
  });
  is(
    $adapter->get_ipaddress('eth0'),
    '192.168.101.42',
    'extracts IP address from networkctl output'
  );

  # Restart command
  $adapter->restart('eth0');
  is_deeply(
    $tc->last_cmd,
    ['networkctl down eth0;networkctl up eth0'],
    'executes networkctl restart commands'
  );
};

#
# 4. Test Wicked operations
#
subtest 'Wicked adapter operations' => sub {
  my $tc = TestConsole->new();
  my $adapter = Kanku::Util::VM::Network::Wicked->new(console => $tc);
  $adapter->tool(path('/usr/sbin/wicked'));

  # IP extraction
  $tc->cmd_handler(sub {
    return [
      "wicked ifstatus eth0\r\n"
      . "eth0            up\r\n"
      . "      link:     #2, state up\r\n"
      . "      type:     ethernet\r\n"
      . "      addr:     ipv4 192.168.100.77/24 [dhcp]\r\n"
    ];
  });
  is(
    $adapter->get_ipaddress('eth0'),
    '192.168.100.77',
    'extracts IP address from wicked output'
  );

  # Restart command
  $adapter->restart('eth0');
  is_deeply(
    $tc->last_cmd,
    ['ifdown eth0;ifup eth0'],
    'executes wicked restart via ifdown/ifup'
  );
};

#
# 5. Test NetworkManager operations
#
subtest 'NetworkManager adapter operations' => sub {
  my $tc = TestConsole->new();
  my $adapter = Kanku::Util::VM::Network::NetworkManager->new(console => $tc);
  $adapter->tool(path('/usr/bin/nmcli'));

  # IP extraction
  $tc->cmd_handler(sub {
    return [
      "nmcli device show eth0\r\n"
      . "GENERAL.DEVICE:                         eth0\r\n"
      . "GENERAL.TYPE:                           ethernet\r\n"
      . "IP4.ADDRESS[1]:                         192.168.100.88/24\r\n"
      . "IP4.GATEWAY:                            192.168.100.1\r\n"
    ];
  });
  is(
    $adapter->get_ipaddress('eth0'),
    '192.168.100.88',
    'extracts IP address from nmcli output'
  );

  # Restart command
  $adapter->restart('eth0');
  is_deeply(
    $tc->last_cmd,
    ['nmcli device disconnect eth0;nmcli device connect eth0'],
    'executes nmcli disconnect/connect'
  );
};

#
# 6. Test Generic/Ifupdown/Sysconfig IP resolution (generic_get_ipaddress)
#
subtest 'Generic/Ifupdown/Sysconfig adapter operations' => sub {
  my $tc = TestConsole->new();
  my $adapter = Kanku::Util::VM::Network::Generic->new(console => $tc);
  $adapter->tool(path('/usr/bin/ip'));

  # IP extraction via generic ip addr show
  $tc->cmd_handler(sub {
    return [
      "ip addr show eth0\r\n"
      . "2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500\r\n"
      . "    inet 192.168.100.99/24 brd 192.168.100.255 scope global eth0\r\n"
    ];
  });
  is(
    $adapter->get_ipaddress('eth0'),
    '192.168.100.99',
    'extracts IP address via generic iproute2'
  );

  # Restart command
  $adapter->restart('eth0');
  is_deeply(
    $tc->last_cmd,
    ['ip link dev eth0 down;ip link dev eth0 up'],
    'executes ip link dev down/up'
  );

  # Ifupdown restart
  my $ifupdown = Kanku::Util::VM::Network::Ifupdown->new(console => $tc);
  $ifupdown->restart('eth0');
  is_deeply(
    $tc->last_cmd,
    ['ifdown eth0;ifup eth0'],
    'executes ifupdown restart'
  );

  # Sysconfig restart
  my $sysconfig = Kanku::Util::VM::Network::Sysconfig->new(console => $tc);
  $sysconfig->restart('eth0');
  is_deeply(
    $tc->last_cmd,
    ['ifdown eth0;ifup eth0'],
    'executes sysconfig restart'
  );
};

done_testing();
