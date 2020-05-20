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
package Kanku::Util::IPTables;

use Moose;
use Data::Dumper;
use File::Which;
use Kanku::Config;

with 'Kanku::Roles::Logger';

# For future use: we could also get the ip from the serial login
# but therefore we need the domain_name
has [qw/domain_name/] => (is=>'rw',isa=>'Str');
has [qw/guest_ipaddress forward_port_list iptables_chain/] => (is=>'rw',isa=>'Str');
has forward_ports => (is=>'rw',isa=>'ArrayRef',default=>sub { [] });
has '+iptables_chain' => (lazy=>1, default => 'KANKU_HOSTS');

has 'host_interface' => (
  is      => 'rw',
  isa     => 'Str',
);

has host_ipaddress => (
  is      =>'rw',
  isa     =>'Str',
  lazy    => 1,
  default =>sub {
    my $host_interface = $_[0]->host_interface;
    if (! $host_interface ) {
      my $cfg  = Kanku::Config->instance()->config();
      $host_interface = $cfg->{'Kanku::Util::IPTables'}->{host_interface};
    }

    die "No host_interface given. Can not determine host_ipaddress" if (! $host_interface );

    $_[0]->logger->debug("Using host_interface: $host_interface");
    my $cmd = "LANG=C ip --color=never addr show " . $host_interface;
    $_[0]->logger->debug("Executing command: '$cmd'");
    my @out = `$cmd`;

    $_[0]->logger->trace(Dumper(\@out));

    for my $line (@out) {
      if ( $line =~ /^\s*inet\s+([0-9\.]*)(\/\d+)?\s.*/ ) {
        return $1
      }
    }
    return '';
  }
);

sub get_forwarded_ports_for_domain {
  my $self        = shift;
  my $domain_name = shift || $self->domain_name;
  my $result      = { };
  my $sudo        = $self->sudo();
  my $cmd         = "";

  die "No domain_name given. Cannot procceed\n" if (! $domain_name);

  my $re = '^DNAT.*\/\*\s*Kanku:host:'.$domain_name.'(:\w*)?\s*\*\/';

  # prepare command to read PREROUTING chain
  $cmd = $sudo . "LANG=C iptables -t nat -L PREROUTING -n";

  # read PREROUTING rules
  my @prerouting_rules = `$cmd`;

  # check each PREROUTING rule if comment matches "/* Kanku:host:<domain_name>:<application_protocol> */"
  # and push line number to rules ARRAY
  my %port2app = (
    22  => 'ssh',
    80  => 'http',
    443 => 'https',
  );
  for my $line (@prerouting_rules) {
      if ( $line =~ $re ) {
        chomp $line;
        # DNAT       tcp  --  0.0.0.0/0            10.160.67.4          tcp dpt:49002 /* Kanku:host:obs-server:<application_protocol> */ to:192.168.100.148:443
        my($target,$prot,$opt,$source,$destination,@opts) = split(/\s+/,$line);
        my ($host_port,$guest_port,$app);
        for my $f (@opts) {
          if ($f =~ /^Kanku:host:[^\s:]+:(\w+)$/ ) { $app = $1 }
          if ($f =~ /^dpt:(\d+)$/ ) { $host_port = $1 }
          if ($f =~ /^to:[\d\.]+:(\d+)$/ ) { $guest_port = $1 }
        }
        $app = $port2app{$guest_port} if (!$app && $port2app{$guest_port});
        $result->{$destination}->{$host_port} = [$guest_port, $app];
      }
  }

  return $result;
}

sub get_active_rules_for_domain {
  my $self        = shift;
  my $domain_name = shift || $self->domain_name;
  my $result      = { filter => { $self->iptables_chain => [] }, nat => { PREROUTING => [] }  };
  my $sudo        = $self->sudo();
  my $cmd         = "";

  die "No domain_name given. Cannot procceed\n" if (! $domain_name);

  my $re = '^(\d+).*\/\*\s*Kanku:host:'.$domain_name.':\w* \s*\*\/';

  # prepare command to read PREROUTING chain
  $cmd = $sudo . "LANG=C iptables -t nat -v -L PREROUTING -n --line-numbers";

  # read PREROUTING rules
  my @prerouting_rules = `$cmd`;

  # check each PREROUTING rule if comment matches "/* Kanku:host:<domain_name> */"
  # and push line number to rules ARRAY
  for my $line (@prerouting_rules) {
    push(@{$result->{nat}->{PREROUTING}},$1) if ( $line =~ $re );
  }

  # prepare command to read FORWARD chain
  $cmd = $sudo . "LANG=C iptables -v -L ".$self->iptables_chain." -n --line-numbers";

  # read FORWARD rules
  my @forward_rules = `$cmd`;

  # check each FORWARD rule if comment matches "/* Kanku:host:<domain_name> */"
  # and push line number to rules ARRAY
  for my $line (@forward_rules) {
    push (@{$result->{filter}->{$self->iptables_chain}},$1) if ( $line =~ $re);
  }

  return $result;
}

sub cleanup_rules_for_domain {
  my $self        = shift;
  my $domain_name = shift || $self->domain_name;
  my $rules       = $self->get_active_rules_for_domain($domain_name);
  my $sudo        = $self->sudo();

  foreach my $table (keys(%{$rules})) {
    foreach my $chain (keys(%{$rules->{$table}})) {
      foreach my $line_number (reverse(@{$rules->{$table}->{$chain}})) {
        my $cmd = $sudo."iptables -t $table -D $chain $line_number";
        my @out = `$cmd 2>&1`;
        if ($?) {
          die "Error while deleting rules by executing command: $?\n\t$cmd\n\n@out"
        }
      }
    }
  }
};

sub add_forward_rules_for_domain {
  my $self          = shift;
  my %opts          = @_;
  my $start_port    = $opts{start_port};
  my $forward_rules = $opts{forward_rules};
  my $sudo          = $self->sudo();
  my $logger        = $self->logger;

  my $portlist      = { tcp =>[],udp=>[] };
  my $host_ip       = $self->host_ipaddress;

  if (! $host_ip ) {
      $self->logger->warn("No ipaddress found for host_interface '".$self->host_interface."'");
      return undef
  }

  my $guest_ip      = $self->guest_ipaddress;
  if (! $guest_ip ) {
      $self->logger->warn("No ipaddress found for guest domain '".$self->domain_name."'");
      return undef
  }

  $logger->debug("Using ip's(host_ip/guest_ip): ($host_ip/$guest_ip)");

  foreach my $rule (@$forward_rules) {
    if ($rule =~ /^(tcp|udp):(\d+)(:(\w+))?$/i ) {
      # ignore case for protocol TCP = tcp
      my $trans = lc($1);
      my $port  = $2;
      my $app   = lc($4);
      push(@{$portlist->{$trans}}, [$port, $app]);
    } else {
      die "Malicious rule detected '$rule'\n";
    }
  }
  # TODO: implement for udp also
  my $proto         = 'tcp';
  my @fw_ports = $self->_find_free_ports(
    $start_port,
    scalar(@{$portlist->{$proto}}),
    $proto
  );
  $self->_check_chain;
  foreach my $port ( @{$portlist->{$proto}} ) {
    my $host_port = shift(@fw_ports);

    my $comment = " -m comment --comment 'Kanku:host:".$self->domain_name.":$port->[1]'";

    my @cmds = (
      "iptables -t nat -I PREROUTING 1 -d $host_ip -p $proto --dport $host_port -j DNAT --to $guest_ip:$port->[0] $comment",
      "iptables -I ".$self->iptables_chain." 1 -d $guest_ip/32 -p $proto -m state --state NEW -m tcp --dport $port->[0] -j ACCEPT $comment"
    );

    for my $cmd (@cmds) {
      $self->logger->debug("Executing command '$cmd'");
      my @out = `$sudo$cmd 2>&1`;
      if ($?) {
        die "Error while adding rule by executing command: $?\n\t$cmd\n\n@out\n";
      }
    }
  }

};

sub _check_chain {
  my ($self) = @_;

  my $sudo = $self->sudo();
  my $cmd  = "LANG=C iptables -L ".$self->iptables_chain." -n";
  my $out  = `$sudo$cmd 2>&1`;
  if ($out =~ /iptables: No chain\/target\/match by that name./ ) {
    $cmd = "LANG=C iptables -N ".$self->iptables_chain;
    $out  = `$sudo$cmd 2>&1`;
    if ($?) {
      die "Error while creating iptables chain($?):\n\t$cmd\n\n$out\n";
    }
  }
}
sub _find_free_ports {
  my $self        = shift;
  my $start_port  = shift;
  my $count       = shift;
  my $proto       = shift;
  # TODO: make usable for tcp and udp
  my $port2check  = $start_port || 49000;
  my @result      = ();
  my $used_ports  = $self->_used_ports;

  while ( $count && $port2check <= 65535 ) {
    if ( ! $used_ports->{$port2check} ) {
      push(@result,$port2check);
      $count--;
    }
    $port2check++;
  }

  return @result;
};

has _used_ports => (
  is      => 'rw',
  isa     => 'HashRef',
  lazy    => 1,
  default => sub {
    my $self    = shift;
    my $hostip  = $self->host_ipaddress;
    my $result  = {};
    my $cmd     = "";
    # TODO: make usable for tcp and udp

    # prepare command to read PREROUTING chain
    my $bin = which 'ss';
    $bin = which 'netstat' unless $bin;
    if ($bin) {
      $cmd = $self->sudo . "LANG=C $bin -ltn";

      # read PREROUTING rules
      foreach my $line (`$cmd`) {
	chomp $line;
	my @fields = split(/\s+/,$line);
	if ( $fields[3] =~ /(.*):(\d+)$/ ) {
	  if (
		$1 eq '0.0.0.0' or
		$1 eq $hostip
		# or $1 eq '::' use only ipv4 for now
	  ) {
	    $result->{$2} = 1;
	  }
	}
      }
    }

    # prepare command to read PREROUTING chain
    $cmd = $self->sudo . "LANG=C iptables -t nat -L PREROUTING -n";

    # read PREROUTING rules
    for my $line ( `$cmd` ) {
      chomp $line;
      my($target,$prot,$opt,$source,$destination,@opts) = split(/\s+/,$line);
      next if ($target ne 'DNAT');
      if (
          $destination eq '0.0.0.0' or
          $destination eq $hostip
      ){
        map { if ( $_ =~ /^dpt:(\d+)/ ) { $result->{$1} = 1 } } @opts;
      }
    }
    return $result;
  }
);

sub sudo {

  my $sudo      = "";

  # if EUID not root
  if ( $> != 0 ) {
    $sudo = "sudo -n ";
  }

  return $sudo;
}

__PACKAGE__->meta->make_immutable;

1;
