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
package Kanku::Handler::ExecuteCommandViaSSH;

use Moose;
use Carp;

sub gui_config {[
    {
      param => 'disabled',
      type  => 'checkbox',
      label => 'Disabled',
    },
]}

sub distributable { 1 }
with 'Kanku::Roles::Handler';

has timeout => (
  is      => 'rw',
  isa     => 'Int',
  lazy    => 1,
  default => 60*60*4
);

with 'Kanku::Roles::SSH';

has commands => (
  is      => 'rw',
  isa     => 'ArrayRef',
  default => sub {[]},
);

has environment => (
  is      => 'rw',
  isa     => 'HashRef',
  default => sub {{}},
);

has context2env => (
  is      => 'rw',
  isa     => 'HashRef',
  default => sub {{}},
);

has disabled => (
  is      => 'rw',
  isa     => 'Bool',
  default => 0,
);


sub execute {
  my $self    = shift;
  my $results = [];

  $self->connect();

  my $ip      = $self->ipaddress;
  my $ssh     = $self->ssh;
  my $ctx     = $self->job->context;

  for my $env_var (keys(%{$self->context2env})) {
    # upper case environment variables are more shell
    # style
    my $n_env_var = uc($env_var);
    $self->ENV->{$n_env_var} = $ctx->{$env_var};
  }

  for my $env_var (keys(%{$self->environment})) {
    # upper case environment variables are more shell
    # style
    my $n_env_var = uc($env_var);
    $self->ENV->{$n_env_var} = $ctx->{$env_var};
  }

  foreach my $cmd ( @{$self->commands} ) {
      my $ret = $self->exec_command($cmd);

      if ($ret->{exit_code}) {
        $ssh->disconnect();
        croak("Error while executing command via ssh '$cmd': $ret->{stderr}\nSTDOUT: $ret->{stdout}\n");
      }

      push @$results, {
        command     => $cmd,
        exit_status => 0,
        message     => $ret->{stdout},
      };
  }

  return {
    code        => 0,
    message     => "All commands on $ip executed successfully",
    subresults  => $results
  };
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Kanku::Handler::ExecuteCommandViaSSH

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::ExecuteCommandViaSSH
    options:
      context2env:
        ipaddress:
      environment:
        test: value
      publickey_path: /home/m0ses/.ssh/id_rsa.pub
      privatekey_path: /home/m0ses/.ssh/id_rsa
      passphrase: MySecret1234
      username: kanku
      ipaddress: 192.168.199.17
      commands:
        - rm /etc/shadow

=head1 DESCRIPTION

This handler will connect to the ipaddress stored in job context and excute the configured commands


=head1 OPTIONS

      commands          : array of commands to execute


SEE ALSO L<Kanku::Roles::SSH>


=head1 CONTEXT

=head2 getters

SEE ALSO L<Kanku::Roles::SSH>

=head2 setters

NONE

=head1 DEFAULTS

SEE ALSO L<Kanku::Roles::SSH>

=cut
