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
package Kanku::Util::VM::Network::Role;

use Moose::Role;
use Path::Tiny;
use Data::Dumper;

#
# Methods that must be implemented by each concrete network adapter.
#
requires qw(
  name
  tool_candidates
  restart
);

#
# Reference back to the parent Kanku::Util::VM::Console instance.
# Weakened to prevent circular reference cycles between Console and Adapter.
#
has 'console' => (
  is       => 'ro',
  isa      => 'Object',
  required => 1,
  weak_ref => 1,
);

#
# Resolved binary path (as Path::Tiny) for network operations.
# Lazy built from tool_candidates via console shell command.
#
has 'tool' => (
  is      => 'rw',
  isa     => 'Object',
  lazy    => 1,
  builder => '_build_tool',
);

#
# Probe guest for available binaries in order of candidate preference.
# Uses 'type -P' with candidates space-separated so the first match
# becomes the resolved tool.
#
sub _build_tool {
  my ($self)     = @_;
  my @candidates = $self->tool_candidates;
  my $cand_str   = join(q{ }, @candidates);

  my $out   = $self->cmd("type -P $cand_str||true");
  my @lines = split(/\R/, $out->[0] || q{});
  # Drop echoed command line
  shift @lines;

  my $resolved;
  for my $line (@lines) {
    if ($line =~ /^\s*(\/\S+)/) {
      $resolved = path($1);
      last;
    }
  }

  $resolved ||= path('/bin/ip');
  $self->logger->debug(
    "Resolved network tool for " . $self->name . ": " . $resolved->stringify
  );
  return $resolved;
}

#
# Convenience delegation helpers to console
#
sub cmd {
  my ($self, @args) = @_;
  return $self->console->cmd(@args);
}

sub logger {
  my ($self) = @_;
  return $self->console->logger;
}

#
# Generic IP address resolution using iproute2 'ip addr show <if>'.
# Shared by ifupdown, sysconfig, and generic fallback adapters.
#
sub generic_get_ipaddress {
  my ($self, $interface) = @_;
  my $logger    = $self->logger;
  my $ipaddress;

  my $result = $self->cmd("LANG=C \\ip addr show $interface 2>&1|cat");
  $logger->trace("  -- generic_get_ipaddress output:\n" . Dumper($result));

  for my $line (split(/\R/, $result->[0] || q{})) {
    if ($line =~ /^\s+inet\s+([0-9.]+)\//) {
      $ipaddress = $1;
      last;
    }
  }

  return $ipaddress;
}

#
# Default get_ipaddress falls back to generic iproute2 query.
# Adapters with specialized CLIs (SystemdNetworkd, Wicked, NetworkManager)
# can override this method.
#
sub get_ipaddress {
  my ($self, $interface) = @_;
  return $self->generic_get_ipaddress($interface);
}

1;
