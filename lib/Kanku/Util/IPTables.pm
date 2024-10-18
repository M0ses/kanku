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
use JSON::MaybeXS;
use Carp;

use Kanku::Config::Defaults;

with 'Kanku::Roles::Logger';

# For future use: we could also get the ip from the serial login
# but therefore we need the domain_name
has [qw/domain_name/] => (is=>'rw',isa=>'Str');
has [qw/guest_ipaddress forward_port_list iptables_chain iptables_wrapper/] => (is=>'rw',isa=>'Str');
has forward_ports => (is=>'rw',isa=>'ArrayRef',default=>sub { [] });
has '+iptables_chain' => (lazy=>1, default => 'KANKU_HOSTS');
has '+iptables_wrapper' => (lazy=>1, default => '/usr/lib/kanku/iptables_wrapper');

has 'host_interface' => (
  is      => 'rw',
  isa     => 'Str',
);

has host_ipaddress => (
  is      =>'rw',
  isa     =>'Str',
  lazy    => 1,
  builder => '_build_host_interface',
);
sub _build_host_interface {
  my ($self) = @_;
  my $host_interface = $self->host_interface
    || Kanku::Config::Defaults->get(
	 'Kanku::Config::GlobalVars',
	 'host_interface'
       );

  die "No host_interface given. Can not determine host_ipaddress" if (! $host_interface );

  $self->logger->debug("Using host_interface: $host_interface");

  # use cat for disable colors
  my $cmd = "LANG=C ip addr show " . $host_interface . "|cat";
  $self->logger->debug("Executing command: '$cmd'");
  my @out = `$cmd`;

  for my $line (@out) {
    if ( $line =~ /^\s*inet\s+([0-9\.]*)(\/\d+)?\s.*/ ) {
      return $1
    }
  }
  return '';
}

has 'domain_autostart' => (
  is      => 'rw',
  isa     => 'Bool',
  default => 0,
);

sub get_forwarded_ports_for_domain {
  my ($self, $domain_name) = @_;
  my $result               = { };
  $domain_name           ||= $self->domain_name;

  die "No domain_name given. Cannot procceed\n" if (! $domain_name);

  my @prerouting_rules = $self->_get_rules_from_chain('nat');

  my %port2app = (
    22  => 'ssh',
    80  => 'http',
    443 => 'https',
  );
  for my $rule (@prerouting_rules) {
    next if ($rule->{target} ne 'DNAT');
    next if ($rule->{domain_name} ne $domain_name);
    my $guest_port  = $rule->{to_port};
    my $app         = $result->{application_protocol};
    $app            = $port2app{$guest_port} if (!$app && $port2app{$guest_port});
    my $host_port   = $rule->{dpt};
    my $destination = $rule->{dest};
    $result->{$destination}->{$host_port} = [$guest_port, $app];
  }

  return $result;
}

sub get_active_rules_for_domain {
  my ($self, $domain_name) = @_;
  $domain_name           ||= $self->domain_name;
  my $chain                = $self->iptables_chain;
  my $result               = {filter =>{$chain=>[]}, nat=>{$chain=>[]}};

  die "No domain_name given. Cannot procceed\n" if (! $domain_name);

  for my $table ('nat', 'filter') {
    if ($self->chain_exists($table)) {
      for my $rule ($self->_get_rules_from_chain($table)) {
        push(@{$result->{$table}->{$chain}},$rule->{line_number}) if (($rule->{domain_name}||q{}) eq $domain_name);
      }
    }
  }

  return $result;
}

sub cleanup_rules_for_domain {
  my ($self, $domain_name) = @_;
  $domain_name           ||= $self->domain_name;
  my $rules                = $self->get_active_rules_for_domain($domain_name);
  my $sudo                 = $self->sudo();
  my $wrapper              = $self->iptables_wrapper;
  my $logger               = $self->logger;

  foreach my $table (keys(%{$rules})) {
    foreach my $chain (keys(%{$rules->{$table}})) {
      foreach my $line_number (reverse(@{$rules->{$table}->{$chain}})) {
        my $cmd = $sudo."$wrapper D:$table:$chain:$line_number 2>&1";
        $logger->debug("executing `$cmd`");
        my @out = `$cmd`;
        if ($?) {
          die "Error while deleting rules by executing command: $?\n\t$cmd\n\n@out"
        }
      }
    }
  }
}

sub add_forward_rules_for_domain {
  my ($self, %opts) = @_;
  my $start_port    = $opts{start_port};
  my $forward_rules = $opts{forward_rules};
  my $sudo          = $self->sudo();
  my $logger        = $self->logger;

  my $portlist      = { tcp =>[],udp=>[] };
  my $host_ip       = $self->host_ipaddress;
  my $wrapper       = $self->iptables_wrapper;
  my $chain         = $self->iptables_chain;

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
      my $app   = lc($4||q{});
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

    my $comment = "Kanku:host:".$self->domain_name.":".($port->[1]||q{}).":".($self->domain_autostart||0);

    my @cmds = (
      "$wrapper I:nat:$chain:$host_ip:$proto:$host_port:$guest_ip:$port->[0]:$comment",
      "$wrapper I:filter:$chain:$guest_ip/32:$proto:$port->[0]:$comment"
    );

    for my $cmd (@cmds) {
      $self->logger->debug("Executing command '$cmd'");
      my @out = `$sudo$cmd 2>&1`;
      if ($?) {
        die "Error while adding rule by executing command: $?\n\t$cmd\n\n@out\n";
      }
    }
  }

}

sub store_iptables_autostart {
  my ($self, $file) = @_;
  my $rules2store = {nat=>[],filter=>[]};

  for my $table (keys %$rules2store) {
    if ($self->chain_exists($table)) {
      my @rules =  $self->_get_rules_from_chain($table);
      for my $rule (@rules) {
	push @{$rules2store->{$table}}, $rule if $rule->{domain_autostart};
      }
    }
  }
  $self->logger->debug("Writing rules2store to $file");
  open(my $fh, '>', $file) || die "Could not open $file: $!\n";
  print $fh encode_json($rules2store);
  close $fh;
}

sub restore_iptables_autostart {
  my ($self, $file) = @_;
  my $sudo          = $self->sudo || q{};
  my $wrapper       = $self->iptables_wrapper;
  my $chain         = $self->iptables_chain;
  my $lines;
  if(-f $file) {
    open(my $fh, '<', $file) || die "Could not open $file: $!\n";
    $lines = <$fh>;
    close $fh;
  } else {
    $self->logger->debug("$file not found");
  }

  my $restore = decode_json($lines);

  for my $table (keys %{$restore}) {
    for my $rule (@{$restore->{$table}}) {
      my $cmd;
      if ($rule->{target} eq 'DNAT') {
	$cmd = "$wrapper I:$table:$chain:$rule->{dest}/32:$rule->{proto}:$rule->{dpt}:$rule->{to_host}:$rule->{to_port}:$rule->{comment}";
      } elsif ($rule->{target} eq 'ACCEPT'){
	$cmd = "$wrapper I:$table:$chain:$rule->{dest}/32:$rule->{proto}:$rule->{dpt}:$rule->{comment}";
      }

      $self->logger->debug("Executing command '$cmd'");
      my @out = `$sudo$cmd 2>&1`;
      if ($?) {
	die "Error while adding rule by executing command: $?\n\t$cmd\n\n@out\n";
      }
    }
  }
}

sub chain_exists {
  my ($self, $table, $chain) = @_;
  my $sudo    = $self->sudo();
  my $wrapper = $self->iptables_wrapper;
  my @rules;
  $table  ||= 'filter';
  $chain  ||= $self->iptables_chain;
  my $cmd  = "$sudo $wrapper L:$table:$chain 2>&1";
  my @lines = `$cmd`;

  return 1 unless $?;

  return 0;
}


sub _get_rules_from_chain {
  my ($self, $table, $chain) = @_;
  my $sudo                   = $self->sudo();
  my $logger                 = $self->logger;
  $table                   ||= 'filter';
  $chain                   ||= $self->iptables_chain;
  my $wrapper                = $self->iptables_wrapper;
  my $cmd                    = "$sudo $wrapper L:$table:$chain 2>&1";
  my @rules;
  $logger->debug("Executing `$cmd`");
  my @lines = `$cmd`;

  confess "Error while creating iptables chain($?):\n\t$cmd\n\n@lines\n" if $?;

  # 1        0     0 ACCEPT     tcp  --  *      *       0.0.0.0/0            192.168.199.84       state NEW tcp dpt:443 /* Kanku:host:obs-server::1 */
  my $re = qr/^
    (\d+)\s+       # line-number
    (\d+[KMG]?)\s+ # packets
    (\d+[KMG]?)\s+ # bytes
    ([^\s]+)\s+    # target
    ([^\s]+)\s+    # proto
    ([^\s]+)\s+    # opts
    ([^\s]+)\s+    # in
    ([^\s]+)\s+    # out
    ([^\s]+)\s+    # source
    ([^\s]+)\s*    # dest
    (.*)           # info
  $/x;

  for my $l (splice @lines,2) {
    chomp($l);
    if ($l =~ $re) {
      my $result = {
        line_number => $1,
	packets     => $2,
	bytes       => $3,
	target      => $4,
	proto       => $5,
	opts        => $6,
	in          => $7,
	out         => $8,
	source      => $9,
	dest        => $10,
	_info       => $11,
      };
      $result->{state} = $1 if($result->{_info} =~ /state ([^\s]+)/);
      $result->{dpt} = $1 if($result->{_info} =~ /(?:udp|tcp) dpt:(\d+)/);
      if($result->{_info} =~ m#/\*\s+(Kanku:host:(.*):(.*):(.*))\s+\*/#) {
        $result->{comment}              = $1;
        $result->{domain_name}          = $2;
        $result->{application_protocol} = $3;
        $result->{domain_autostart}     = $4;
      }
      if($result->{_info} =~ m#\s+to:([0-9\.]+):(\d+)#) {
        $result->{to_host} = $1;
        $result->{to_port} = $2;
      }
      if($result->{_info} =~ m#/\*\s+(Kanku:net:(.*))\s+\*/#) {
        $result->{comment}              = $1;
        $result->{network_name}          = $2;
      }
      push @rules, $result;
    } else {
       $self->logger->warn("Could not parse line: '$l'")
    }
  }
  return @rules;
}

sub _check_chain {
  my ($self)  = @_;
  my $logger  = $self->logger;
  my $wrapper = $self->iptables_wrapper;
  my $sudo    = $self->sudo();
  my $chain   = $self->iptables_chain;

  my $cmd     = "$sudo$wrapper L:filter:$chain 2>&1";
  $logger->debug("Executing `$cmd`");
  my $out     = `$cmd`;

  if ($out =~ /iptables: No chain\/target\/match by that name./ ) {
    $cmd = "$wrapper N:filter:$chain";
    $out  = `$sudo$cmd 2>&1`;
    if ($?) {
      die "Error while creating iptables chain($?):\n\t$cmd\n\n$out\n";
    }
  }
}

sub _find_free_ports {
  my ($self, $start_port, $count, $proto) = @_;
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
}

has _used_ports => (
  is      => 'rw',
  isa     => 'HashRef',
  lazy    => 1,

  builder => '_build__used_ports',
);

sub _build__used_ports {
    # TODO: make usable for tcp and udp
    my ($self)  = @_;
    my $hostip  = $self->host_ipaddress;
    my $result  = {};
    my $sudo    = $self->sudo;
    my $lib_p   = '/usr/lib/kanku';
    my $bin     = "$lib_p/ss_netstat_wrapper";
    die "$bin not found" unless -f $bin;

    if ($bin) {
      my $cmd = $sudo.$bin;

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

    # read nat rules
    for my $rule ( $self->_get_rules_from_chain('nat')) {
      next if ($rule->{target} ne 'DNAT');
      my $destination = $rule->{dest};
      if (
          $destination eq '0.0.0.0' or
          $destination eq $hostip
      ){
        $result->{$rule->{dpt}} = 1 if $rule->{dpt};
      }
    }
    return $result;
  }
sub sudo {
  return ($> != 0) ? "sudo -n " : q{};
}

__PACKAGE__->meta->make_immutable;

1;
