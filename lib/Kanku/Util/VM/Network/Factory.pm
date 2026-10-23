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
#
# You should have received a copy of the GNU General Public License
# along with this program (see the file COPYING); if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#
package Kanku::Util::VM::Network::Factory;

use strict;
use warnings;
use Carp;

#
# Map supported framework identifiers to their adapter classes.
#
my %FRAMEWORK_MAP = (
  'systemd-networkd' => 'Kanku::Util::VM::Network::SystemdNetworkd',
  'wicked'           => 'Kanku::Util::VM::Network::Wicked',
  'NetworkManager'   => 'Kanku::Util::VM::Network::NetworkManager',
  'ifupdown'         => 'Kanku::Util::VM::Network::Ifupdown',
  'sysconfig'        => 'Kanku::Util::VM::Network::Sysconfig',
  'ip'               => 'Kanku::Util::VM::Network::Generic',
);

#
# Probe the guest VM via console to identify active network manager.
# Probes active systemd units first, then enabled units, runtime paths,
# configuration files, and finally binary availability.
#
sub detect {
  my ($class, $console) = @_;
  my $logger = $console->logger;

  my $probe_cmd = join(
    '; ',
    'if systemctl is-active --quiet systemd-networkd 2>/dev/null',
    'then echo systemd-networkd',
    'elif systemctl is-active --quiet wicked 2>/dev/null',
    'then echo wicked',
    'elif systemctl is-active --quiet NetworkManager 2>/dev/null',
    'then echo NetworkManager',
    'elif systemctl is-active --quiet networking 2>/dev/null',
    'then echo ifupdown',
    'elif systemctl is-active --quiet network 2>/dev/null',
    'then echo sysconfig',
    'elif systemctl is-enabled --quiet systemd-networkd 2>/dev/null',
    'then echo systemd-networkd',
    'elif systemctl is-enabled --quiet wicked 2>/dev/null',
    'then echo wicked',
    'elif systemctl is-enabled --quiet NetworkManager 2>/dev/null',
    'then echo NetworkManager',
    'elif [ -d /run/systemd/netif ]',
    'then echo systemd-networkd',
    'elif [ -d /run/wicked ] || [ -d /var/run/wicked ]',
    'then echo wicked',
    'elif [ -d /run/NetworkManager ] || [ -d /var/run/NetworkManager ]',
    'then echo NetworkManager',
    'elif [ -f /etc/network/interfaces ]',
    'then echo ifupdown',
    'elif [ -d /etc/sysconfig/network ]',
    'then echo sysconfig',
    'elif type -P wicked >/dev/null 2>&1',
    'then echo wicked',
    'elif type -P nmcli >/dev/null 2>&1',
    'then echo NetworkManager',
    'elif type -P networkctl >/dev/null 2>&1',
    'then echo systemd-networkd',
    'elif type -P ifdown >/dev/null 2>&1',
    'then echo ifupdown',
    'else echo ip',
    'fi',
  );

  my $out   = $console->cmd($probe_cmd);
  my @lines = split(/\R/, $out->[0] || q{});
  # Drop echoed command line
  shift @lines;

  my $framework = 'ip';
  for my $line (@lines) {
    if ($line =~ /^\s*(
      systemd-networkd|wicked|NetworkManager|ifupdown|sysconfig|ip
    )\s*$/x) {
      $framework = $1;
      last;
    }
  }

  $logger->debug("Detected network framework: $framework");
  return $framework;
}

#
# Instantiate appropriate network adapter instance for given console.
# If framework is not specified, auto-detection is performed.
#
sub create {
  my ($class, %opts) = @_;
  my $console   = $opts{console} || croak "console parameter is required";
  my $framework = $opts{framework} || $class->detect($console);

  my $adapter_pkg = $FRAMEWORK_MAP{$framework}
    || $FRAMEWORK_MAP{ip};

  # Dynamically load the selected adapter module
  (my $file = $adapter_pkg . '.pm') =~ s{::}{/}g;
  require $file;

  return $adapter_pkg->new(console => $console);
}

1;
