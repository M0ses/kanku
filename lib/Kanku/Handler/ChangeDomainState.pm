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
package Kanku::Handler::ChangeDomainState;

use Moose;

use Kanku::Config;
use Kanku::Util::VM;
use Kanku::TypeConstraints;

sub gui_config {
  [
    {
      param => 'wait_for_console',
      type  => 'checkbox',
      label => 'Wait for console'
    },
    {
      param => 'wait_for_network',
      type  => 'checkbox',
      label => 'Wait for network'
    },
    {
      param => 'allow_ip_change',
      type  => 'checkbox',
      label => 'Allow ip to change (e.g. at reboot)'
    },
    {
      param => 'management_interface',
      type  => 'text',
      label => 'Allow ip to change (e.g. at reboot)'
    },
  ];

}

sub distributable { 1 }

with 'Kanku::Roles::Handler';

has [qw/domain_name login_user login_pass/] => (
  is => 'rw',
  isa=>'Str'
);

has 'management_interface' => (
  'is'      => 'rw',
  'isa'     => 'Str',
  'builder' => '_build_management_interface',
);
sub _build_management_interface {
  my ($self) = @_;
  my $ctx    = $self->job()->context();
  return ($ctx->{management_interface} || q{eth0});
}

has 'action' => (
  is => 'ro',
  isa => 'DomainAction',
);

has [qw/wait_for_network wait_for_console/] => (
  is      => 'rw',
  isa     => 'Bool',
  lazy    => 1,
  default => 1,
);

has [qw/allow_ip_change/] => (
  is      => 'rw',
  isa     => 'Bool',
  lazy    => 1,
  default => 0,
);

has 'timeout' => (
  is      => 'rw',
  isa     => 'Int',
  lazy    => 1,
  default => 600,
);

sub prepare {
  my $self = shift;
  my $ctx  = $self->job()->context();
  my $msg  = "Nothing to do!";

  if ( ! $self->domain_name && $ctx->{domain_name}) {
    $self->domain_name($ctx->{domain_name});
    $msg = "Set domain_name from context to '".$self->domain_name."'";
  }

  $self->evaluate_console_credentials;

  return {
    code    => 0,
    message => $msg
  };
}

sub execute {
  my ($self) = @_;
  my $ctx    = $self->job()->context();
  my $action = $self->action;
  my $cfg    = Kanku::Config->instance()->config();

  my $final_state = {
    reboot   => 1,
    create   => 1,
    shutdown => 5,
    destroy  => 5,
    undefine => 0
  };

  my $cb = {
    reboot => sub {
      my ($vm) = @_;
      my $con   = $vm->console;
      $con->login();
      if ($self->allow_ip_change) {
        $ctx->{ipaddress} = $con->get_ipaddress(
         interface => $self->management_interface,
         timeout   => $self->timeout,
       );
     }
     $con->logout();
   },
   create => sub {
     my ($vm) = @_;
     my $con   = $vm->console;
     $con->login();
     $con->logout();
    },
  };

  my $vm = Kanku::Util::VM->new(
      domain_name => $self->domain_name,
      login_user  => $self->login_user,
      login_pass  => $self->login_pass,
      job_id      => $self->job->id,
  );

  my $dom = $vm->dom;
  $dom->$action();

  if ($action ne 'undefine') {
    my $to = $self->timeout;
    my ($state, $reason) = $dom->get_state;
    $self->logger->debug("initial state: $state / reason: $reason");
    while ($state != $final_state->{$action}) {
      $to--;
      if( $to <= 0) {
        die "Action '$action' on ". $self->domain_name ." failed with timeout";
      }
      ($state, $reason) = $dom->get_state;
      $self->logger->debug("current state: $state / reason: $reason");
      sleep 1;
    }
  }
  $cb->{$action}->($vm) if ($cb->{$action});

  return {
    code    => 0,
    message => "Action '$action' on ". $self->domain_name ." finished successfully"
  };
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Kanku::Handler::ChangeDomainState

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::ChangeDomainState
    options:
      action: shutdown
      timeout:          600

=head1 DESCRIPTION

This handler triggers an action on a VM and waits for the final state.

=head1 OPTIONS

    action  :             <create|reboot|shutdown|destroy|undefine>

    timeout :             wait only <seconds>

    wait_for_console:     wait for console (e.g. after reboot) [DEFAULT: true]

    wait_for_network:     wait for network (e.g. after reboot) [DEFAULT: true]

    allow_ip_change:      wait for console and store new ip in job context [DEFAULT: false]

    management_interface: interface to read new ip from (required by allow_ip_change)

=head1 CONTEXT

=head2 getters

 domain_name

=head2 setters

 ipaddress      (in case of allow_ip_change enabled)

=head1 DEFAULTS

    timeout : 600 seconds

=cut

