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
package Kanku::Cli::SSH;

use MooseX::App::Command;
extends qw(Kanku::Cli);

# timeout must be defined before consuming role
#
option 'timeout' => (
  isa           => 'Int',
  is            => 'rw',
  documentation => 'Timeout to use for ssh',
  default       => 180,
);
with 'Kanku::Roles::SSH';
with 'Kanku::Cli::Roles::VM';

command_short_description  'open ssh connection to vm';

command_long_description  '
This command opens a ssh connection to a local kanku domain
by calling the `ssh` command.

';

option 'user' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'u',
  documentation => 'Login user to use for ssh',
  builder       => '_build_user',
);

sub _build_user {
  my ($self) = @_;
  return $self->kankufile_config->{ssh_user} || 'kanku';
}

sub _build_domain_name {
  my ($self) = @_;
  return $self->kankufile_config->{domain_name} || q{};
}

option 'port' => (
  isa           => 'Int',
  is            => 'rw',
  cmd_aliases   => [qw/p/],
  documentation => 'TCP port to use for ssh',
  default       => 22,
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
  cmd_aliases   => [qw/A/],
  documentation => 'allow ssh agent forwarding',
);

option 'x11_forward' => (
  isa           => 'Bool',
  is            => 'rw',
  cmd_aliases   => [qw/X/],
  documentation => 'allow X11 forwarding',
);

option 'pseudo_terminal' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => [qw/T pseudo-terminal/],
  documentation => 'force/disable pseudo terminal allocation',
);

has 'template' => (
  is            => 'rw',
  isa           => 'Str',
  default       => 'ssh.tt',
);

with 'Kanku::Cli::Roles::View';

use Kanku::Util::VM;

sub run {
  my ($self) = @_;
  Kanku::Config->initialize(class=>'KankuFile', file=>$self->file);
  my $config = $self->kankufile_config;
  my $logger = $self->logger;
  my $ret    = 0;
  my $vars   = {
    x11_forward   => $self->x11_forward,
    agent_forward => $self->agent_forward,
    execute       => $self->execute,
    user          => $self->user,
    port          => $self->port,
    ip            => $self->ipaddress,
  };

  if ($self->pseudo_terminal) {
    $vars->{term} = q{ -t} if ($self->pseudo_terminal eq 'force');
    $vars->{term} = q{ -T} if ($self->pseudo_terminal eq 'disable');
  }
  if (!$vars->{ip}) {
    my $vm     = Kanku::Util::VM->new(
     domain_name => $self->domain_name || $config->{domain_name},
     management_network  => $config->{management_network} || q{}
    );
    my $state = $vm->state;

    if ( $state eq 'on' && !$self->ipaddress ) {
      $vars->{ip} = $self->ipaddress($config->{ipaddress} || $vm->get_ipaddress);
    } elsif ($state eq 'off') {
      $logger->warn('VM is off - use \'kanku startvm\' to start VM and try again');
      $ret = 1;
    } else {
      $logger->fatal('No VM found or VM in state \'unknown\'');
      $ret = 2;
    }
  }

  if(!$ret) {
    my $cmd = $self->render_template($vars);
    $logger->debug("Calling ssh client with username `$vars->{user}` to `$vars->{ip}`");
    $logger->debug("\$sshcmd = >>>$cmd<<<");
    system($cmd);
    if ($?) {
      $logger->error("Failed to execute `$cmd`. RC=$?");
      $ret = $? >> 8;
    }
  }
  return $ret;
}

__PACKAGE__->meta->make_immutable;

1;
