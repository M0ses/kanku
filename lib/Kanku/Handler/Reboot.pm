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
package Kanku::Handler::Reboot;

use Moose;
use Kanku::Config;
use Kanku::Util::VM;

sub gui_config {
  [
    {
      param => 'wait_for_console',
      type  => 'checkbox',
      label => 'Wait for console'
    },
  ];
}
sub distributable { 1 }
with 'Kanku::Roles::Handler';

has [qw/
      domain_name
      login_user
      login_pass
      management_interface
/] => (is => 'rw',isa=>'Str');

has [qw/wait_for_network wait_for_console/] => (
  is => 'rw',
  isa=>'Bool',
  lazy=>1,
  default=>1,
);

has [qw/allow_ip_change/] => (is => 'rw', isa=>'Bool', lazy=>1, default=>0);
has [qw/timeout/]         => (is => 'rw', isa=>'Int' , lazy=>1, default=>600);
has [qw/login_timeout/]   => (is => 'rw', isa=>'Int' , lazy=>1, default=>0);

sub prepare {
  my $self = shift;
  my $ctx  = $self->job()->context();

  $self->domain_name($ctx->{domain_name}) if ( ! $self->domain_name && $ctx->{domain_name});
  $self->management_interface($ctx->{management_interface}) if ( ! $self->management_interface && $ctx->{management_interface});
  $self->evaluate_console_credentials;

  return {
    code    => 0,
    message => "Nothing todo"
  };
}

sub execute {
  my ($self) = @_;
  my $ctx    = $self->job()->context();
  my $cfg    = Kanku::Config->instance()->config();

  my $vm = Kanku::Util::VM->new(
      domain_name => $self->domain_name,
      login_user  => $self->login_user,
      login_pass  => $self->login_pass,
      job_id      => $self->job->id,
      log_file    => $ctx->{log_file} || q{},
      log_stdout  => defined ($ctx->{log_stdout}) ? $ctx->{log_stdout} : 1,
      no_wait_for_bootloader => 1
  );

  my $con = $vm->console();
  $con->login();
  $con->cmd_timeout(-1);
  $con->login_timeout($self->login_timeout) if $self->login_timeout;
  $con->cmd("reboot");
  $con->cmd_timeout($self->timeout);
  if ($self->wait_for_console) {
    # Wait for reboot to complete
    $self->logger->debug("Waiting for console for ".$con->cmd_timeout."sec!");
    $con->login();
    $con->logout();
  }

  my $new_ip='';

  if ($self->allow_ip_change) {
    $con->login();
    $ctx->{ipaddress} = $con->get_ipaddress(
      interface => $ctx->{management_interface},
      timeout   => $self->timeout,
    );
    $new_ip = " New IP: $ctx->{ipaddress}";
    $con->logout();
  }

  $self->logger->warn("DEPRECATED: THIS HANDLER MAY BE REMOVED FROM FUTURE VERSIONS\n").
  return {
    code    => 0,
    message =>
      "DEPRECATED: THIS HANDLER MAY BE REMOVED FROM FUTURE VERSIONS\n".
        'Rebooted domain '. $self->domain_name ." successfully. $new_ip",
  };
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Kanku::Handler::Reboot

=head1 SYNOPSIS

DEPRECATED: THIS HANDLER MAY BE REMOVED FROM FUTURE VERSIONS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::Reboot
    options:
      wait_for_console: 1
      wait_for_network: 1
      timeout:          600
      login_timeout:    900
      allow_ip_change:  1
      ....

=head1 DESCRIPTION

This handler reboots the VM and optional waits for network and console.

=head1 OPTIONS


    wait_for_console : wait for console login

    wait_for_network : wait until network is up again

    timeout :          wait only <seconds>

    allow_ip_change:   allow VM to change ip address on reboot

    login_timeout:     console login timeout

=head1 CONTEXT

=head2 getters

 domain_name

=head2 setters

=head1 DEFAULTS

    wait_for_console : 1 (true)

    wait_for_network : 1 (true)

    timeout          : 600 seconds

    allow_ip_change  : 0 (false)

    login_timout     : defaults to Kanku::Util::VM::Console

=cut

