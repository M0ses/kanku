# Copyright (c) 2017 SUSE LLC
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
package Kanku::Handler::PortForward;

use Moose;
use Kanku::Config::Defaults;
use Kanku::Util::IPTables;

sub gui_config {
  [
    {
      param => 'forward_port_list',
      type  => 'text',
      label => 'List of Forwarded Ports'
    },
  ];
}
sub distributable { 0 }
with 'Kanku::Roles::Handler';

has [qw/ipaddress domain_name forward_port_list host_interface/] => (is => 'rw',isa=>'Str');

has '+domain_name' => (
  lazy => 1,
  default => sub { $_[0]->job()->context()->{domain_name} || '' }
);

has '+host_interface' => (
  lazy => 1,
  builder => '_build_host_interface',
);
sub _build_host_interface {
  my ($self) = @_;
  return
    $self->job()->context()->{host_interface}
    || Kanku::Config::Defaults->get('Kanku::Config::GlobalVars', 'host_interface');
}

has '+ipaddress' => (
  lazy => 1,
  default => sub { $_[0]->job()->context()->{ipaddress} || '' }
);

sub execute {
  my ($self) = @_;
  my $ctx    = $self->job()->context();

  if ( $self->forward_port_list ) {
    my $ipt = Kanku::Util::IPTables->new(
      domain_name      => $self->domain_name,
      host_interface   => $self->host_interface || '',
      guest_ipaddress  => $self->ipaddress,
      domain_autostart => $ctx->{domain_autostart},
    );

    $ipt->add_forward_rules_for_domain(
      start_port => $self->cfg->{'Kanku::Util::IPTables'}->{start_port},
      forward_rules => [ split(/,/,$self->forward_port_list) ]
    );

    return {
      code    => 0,
      message => "Created port forwarding for " . $self->domain_name .
		  " (".$self->ipaddress.") port list: (". $self->forward_port_list.")"
    };

  } else {
    return {
      code    => 0,
      message => "No forward_port_list configured. Nothing to do."
    };
  }
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

Kanku::Handler::PortForward

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::PortForward
    options:
      host_interface: br0
      forward_port_list: tcp:22,tcp:80,tcp:443,udp:53

=head1 DESCRIPTION

Enable port forwarding for configured a port_forward_list.
It tries to find the next free port and configure a port forwarding with iptables.

=head1 OPTIONS

    domain_name           : name of domain to create

    forward_port_list     : list of ports to forward from host_interface`s IP to VM

=head1 CONTEXT

=head2 getters

 domain_name

 ipaddress

=head2 setters


=head1 DEFAULTS


=cut
