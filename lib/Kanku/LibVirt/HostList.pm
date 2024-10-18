package Kanku::LibVirt::HostList;

use Moose;
use Kanku::YAML;
use URI::Escape;
use Try::Tiny;

has cfg_file => (
  is      => 'rw',
  isa     => 'Str',
  lazy    => 1,
  default => '/etc/kanku/kanku-config.yml'
);

has cfg => (
  is      => 'rw',
  isa     => 'ArrayRef',
  lazy    => 1,
  default => sub {
    my $pkg = __PACKAGE__;
    Kanku::YAML::LoadFile($_[0]->cfg_file)->{$pkg};
  }
);

sub get_remote_ips {
  my $self       = shift;
  my $cfg        = $self->cfg;
  my @remote_ips = ();
  for my $host (@{$cfg || []}) {
    push(@remote_ips, $host->{remote_ip}) if ($host->{remote_ip});
  }

  return \@remote_ips;
}

sub calc_remote_urls {
  my $self        = shift;
  my $cfg        = $self->cfg;
  my @remote_urls = ();

  for my $tmp (@{$cfg || []}) {
    my ($user, $host, $port, $extraparameters);

    my (@eparam);

    my $driver = $tmp->{driver} || 'qemu';

    my $transport = ($tmp->{transport}) ? "+$tmp->{transport}" : '';

    my $path = $tmp->{remote_path} || 'system';

    if ($tmp->{remote_ip}) {
      $host = $tmp->{remote_ip};
      # Only set user and port if we got remote_ip
      $user = ($tmp->{remote_user}) ? "$tmp->{remote_user}\@" : '';
      $port = ($tmp->{remote_port}) ? ":$tmp->{remote_port}" : '';
    } else {
      $host = $user = $port = '';
    }

    # sorting for reliable testing
    for my $epa (sort(keys(%{$tmp->{extraparameters} || {}}))) {
      push(@eparam,"$epa=".uri_escape($tmp->{extraparameters}->{$epa}));
    }

    if (@eparam) {
      $extraparameters = '?'.join('&',@eparam);
    } else {
      $extraparameters = '';
    }

    $tmp->{remote_url} = "$driver$transport://$user$host$port/$path$extraparameters";
  }
}

sub get_remote_urls {
  my $self        = shift;
  my $cfg        = $self->cfg;
  my @remote_urls = ();

  $self->calc_remote_urls;

  for my $tmp (@{$cfg || []}) {
    push(@remote_urls, $tmp->{remote_url});
  }
  return \@remote_urls
}

__PACKAGE__->meta->make_immutable;
1;

__END__
Kanku::LibVirt::HostList:
  -
    hostname: localhost
  -
    hostname: kanku-worker1
    remote_ip: 10.0.0.1
    driver: qemu
    transport: ssh
    remote_user: root
    # remote_port: 22
    # remote_path: system
    # The following options are documented in
    # https://libvirt.org/remote.html#Remote_URI_parameters
    extraparameters
      keyfile: /opt/kanku/etc/ssh/id_dsa
      no_verify: 1
      # no_tty: 1
      known_hosts: /opt/kanku/etc/ssh/known_hosts
      sshauth: privkey

Kanku::LibVirt::Network::OpenVSwitch:
  name:                kanku-ovs
  bridge:              kanku-br0
  vlan:                kanku-vlan1
  host_ip:             192.168.199.1
  network:             192.168.199.0/24
  dhcp_range:          192.168.199.66,192.168.199.254
  start_dhcp:          1
  is_gateway:          1

