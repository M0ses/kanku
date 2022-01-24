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

sub run {
  my ($self) = @_;
  my $cfg    = $self->cfg;
  my $vm     = Kanku::Util::VM->new(
                domain_name => $self->domain_name,
                management_network  => $cfg->config->{management_network} || q{}
              );
  my $state = $vm->state;

  if ( $state eq 'on' ) {
    my $ip    = $self->ipaddress || $cfg->config->{ipaddress} || $vm->get_ipaddress;
    my $user  = $self->user;
    my $cmd   = $self->execute || q{};

    $self->ipaddress($ip);
    $self->username($user);
    $self->job(Kanku::Job->new());
    $self->connect();

    system "ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -l $user $ip $cmd";
    exit 0;
  } elsif ($state eq 'off') {
    $self->logger->warn('VM is off - use \'kanku startvm\' to start VM and try again');
    exit 1;
  } else {
    $self->logger->fatal('No VM found or VM in state \'unknown\'');
    exit 2;
  }

}

__PACKAGE__->meta->make_immutable;

1;
