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
package Kanku::Cli::ssh; ## no critic (NamingConventions::Capitalization)

use strict;
use warnings;

use MooseX::App::Command;
extends qw(Kanku::Cli);

use Kanku::Util::VM;
use Net::IP;

use Kanku::Job;
use Kanku::Config;

with 'Kanku::Roles::SSH';
with 'Kanku::Cli::Roles::VM';

command_short_description  'open ssh connection to vm';

command_long_description  'open ssh connection to vm';

option 'user' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'u',
  documentation => 'Login user to use for ssh',
  default       => sub {
    return $_[0]->cfg->config->{ssh_user} || 'kanku';
  },
);

option 'ipaddress' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'i',
  documentation => 'IP address to connect to',
);

option 'execute' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'e',
  documentation => 'command to execute via ssh',
);

option 'agent_forward' => (
  isa           => 'Bool',
  is            => 'rw',
  cmd_aliases   => 'A',
  documentation => 'allow ssh agent forwarding',
);

option 'x11_forward' => (
  isa           => 'Bool',
  is            => 'rw',
  cmd_aliases   => 'X',
  documentation => 'allow X11 forwarding',
);

option 'pseudo_terminal' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'T',
  documentation => 'force/disable pseudo terminal allocation',
);

# Must be sub because role requires
sub timeout { 180 }

sub run {
  my ($self) = @_;
  my $cfg    = $self->cfg;
  my $user   = $self->user;
  my $ip     = $self->ipaddress;
  my $A      = ($self->agent_forward) ? q{ -A} : q{};
  my $X      = ($self->x11_forward)   ? q{ -X} : q{};
  my $cmd    = ($self->execute)       ? " '".$self->execute."'" : q{};
  my $term   = q{};

  if ($self->pseudo_terminal) {
    $term = q{ -t} if ($self->pseudo_terminal eq 'force');
    $term = q{ -T} if ($self->pseudo_terminal eq 'disable');
  }

  if (!$ip) {
    my $vm     = Kanku::Util::VM->new(
		  domain_name => $self->domain_name,
		  management_network  => $cfg->config->{management_network} || q{}
		);
    my $state = $vm->state;
    if ( $state eq 'on' ) {
      $ip    = $cfg->config->{ipaddress} || $vm->get_ipaddress;
    } elsif ($state eq 'off') {
      $self->logger->warn('VM is off - use \'kanku startvm\' to start VM and try again');
      exit 1;
    } else {
      $self->logger->fatal('No VM found or VM in state \'unknown\'');
      exit 2;
    }
  }
  $self->logger->info("Executing ssh client as user '$user' to '$ip'");
  my $sshcmd = 'ssh'.$A.$X.$term." -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l $user $ip".$cmd;
  $self->logger->debug("\$sshcmd=>$sshcmd<");
  system $sshcmd;
  exit 0;
}

__PACKAGE__->meta->make_immutable;

1;
