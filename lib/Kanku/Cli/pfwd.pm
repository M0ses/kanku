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
package Kanku::Cli::pfwd;

use MooseX::App::Command;
extends qw(Kanku::Cli);

with 'Kanku::Cli::Roles::VM';

option 'ports' => (
    isa           => 'Str',
    is            => 'rw',
    cmd_aliases   => 'p',
    documentation => 'comma separated list of ports to forward (e.g. tcp:22,tcp:443)',
    required      => 1
);

option 'interface' => (
    isa           => 'Str',
    is            => 'rw',
    cmd_aliases   => 'i',
    documentation => 'host interface to use for port forwarding',
    required      => 1
);

command_short_description  "Create port forwards for VM";

command_long_description "
This command can be used to create the portforwarding for an already existing VM
";

sub run {
  my ($self)  = @_;
  my $logger  = $self->logger;
  my $vm      = Kanku::Util::VM->new(domain_name=>$self->domain_name);

  $logger->debug("Searching for domain: ".$self->domain_name);

  my $ip    = $vm->get_ipaddress();
  my $ipt = Kanku::Util::IPTables->new(
    domain_name     => $self->domain_name,
    host_interface  => $self->interface,
    guest_ipaddress => $ip
  );

  $ipt->add_forward_rules_for_domain(
    start_port => $self->cfg->{'Kanku::Util::IPTables'}->{start_port},
    forward_rules => [split(/,/,$self->ports)]
  );
}

__PACKAGE__->meta->make_immutable;

1;
