package Kanku::REST::Guest;

use Moose;

with 'Kanku::Roles::REST';

use Sys::Virt;
use Try::Tiny;
use Session::Token;

use Kanku::Util::IPTables;
use Kanku::LibVirt::HostList;
use Data::Dumper;

sub list {
  my ($self)   = @_;
  my $result   = {errors=>[]};
  my $guests   = {};
  my $filter_p = (ref $self->params->{filter}) ? $self->params->{filter} : [$self->params->{filter}];
  my $filters  = {};

  foreach my $filter (@$filter_p) {
    if ($filter =~ /^(domain|host|worker|state):(.*)$/) {
      $filters->{$1} = $2;
    } else {
      $filters->{domain} = $filter;
    }
  }

  my $hl = Kanku::LibVirt::HostList->new();
  $hl->calc_remote_urls();

  foreach my $host (@{$hl->cfg || []}) {
    my $vmm;
    try {
      $vmm = Sys::Virt->new(uri => $host->{remote_url});
    } catch {
      my $error = "ERROR while connecting '$host->{hostname}' ";
      $self->log('error', $error . $_->message);
      $self->log('debug', $host);
      push @{$result->{errors}}, $error;
    };
    next if (!$vmm);
    next if ($filters->{host} && $host->{hostname} !~ /^$filters->{host}$/);
    next if ($filters->{worker} && $host->{hostname} !~ /^$filters->{worker}$/);
    my @domains = $vmm->list_all_domains();

    foreach my $dom (@domains) {
	my $dom_name          = $dom->get_name;
        next if ($filters->{domain} && $dom_name !~ /^$filters->{domain}$/);
	my ($state, $reason)  = $dom->get_state();
	next if ($filters->{state} && $state != $filters->{state});
	my $ipt = Kanku::Util::IPTables->new(domain_name => $dom_name);
	my $dom_id = "$dom_name:$host->{hostname}";
        my $fwp = $ipt->get_forwarded_ports_for_domain();
        $self->log('debug', "Domain Information: $dom_name/$host->{hostname}/$dom_id\n".Dumper($fwp));
	$guests->{$dom_id}= {
          host		  => $host->{hostname},
	  domain_name     => $dom_name,
	  state           => $state,
	  forwarded_ports => $fwp,
	  nics            => [],
	};

	if ($state == 1 ) {
	  my @t = $dom->get_interface_addresses(Sys::Virt::Domain::INTERFACE_ADDRESSES_SRC_LEASE);
	  $guests->{$dom_id}->{nics} = \@t ;
	}
    }
  }
  $result->{guest_list} = $guests;
  return $result;
}

__PACKAGE__->meta->make_immutable();

1;
