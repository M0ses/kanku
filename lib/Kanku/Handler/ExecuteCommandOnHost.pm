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
package Kanku::Handler::ExecuteCommandOnHost;

use Moose;

sub _build_gui_config {[]}
has 'distributable' => (is=>'ro', isa=>'Int', default => 1);
with 'Kanku::Roles::Handler';

has commands => (is=>'rw', isa=>'ArrayRef', default => sub {[]});

has environment => (is=>'rw', isa=>'HashRef', default => sub {{}});
has context2env => (is=>'rw', isa=>'HashRef', default => sub {{}});
has _env_backup => (is=>'rw', isa=>'HashRef', default => sub {{}});

sub prepare {
  my ($self) = @_;
  my %vars;
  my $ctx = $self->job()->context();
  for my $env_var (keys(%{$self->environment})) {
    $self->logger->debug(
      "Setting from config(environment) \$ENV{$env_var} = ".
      $self->environment->{$env_var}.
      " (Backup: '".$ENV{$env_var}."')"
    );
    $self->_env_backup->{$env_var} = $ENV{$env_var};
    $ENV{$env_var} = $self->environment->{$env_var};
    $vars{$env_var}=1;
  }

  for my $env_var (keys(%{$self->context2env})) {
    # upper case environment variables are more shell
    # style
    my $n_env_var = uc($env_var);
    $self->logger->debug(
      "Setting from job context \$ENV{$n_env_var} = ".
      $ctx->{$env_var}.
      " (Backup: '".$ENV{$n_env_var}."')"
    );
    $self->_env_backup->{$n_env_var} = $ENV{$n_env_var};
    $ENV{$n_env_var} = $ctx->{$env_var};
    $vars{$n_env_var}=1;
  }

  return {
    code => 0,
    message => "Preparation successful. Set the following ENV Vars: (".join(", ", keys(%vars)).")"
  };
}

sub execute {
  my ($self) = @_;

  for my $cmd (@{$self->commands}) {
    my @io;
    $self->logger->debug("Executing command '$cmd'");
    my $out = `$cmd 2>&1`;
    die $out if ($?);
    $self->logger->trace("Output on STDOUT:\n$out");
  }

  return {
    code => 0,
    message => "All commands on host succeed!"
  };
}

sub finalize {
  my ($self) = @_;
  my @vars;
  for my $env_var (keys(%{$self->_env_backup})) {
    $self->logger->debug(
      "Restoring \$ENV{$env_var} = '".($self->_env_backup->{$env_var}||'')."'"
    );
    $ENV{$env_var} = $self->_env_backup->{$env_var};
  }

  return {
    code => 0,
    message => "Finalization successful. Restored the following ENV Vars:".join(", ", @vars).")"
  };
}
__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

Kanku::Handler::ExecuteCommandOnHost - execute commands on host

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::ExecuteCommandOnHost
    options:
      environment: 
        CURL_CA_BUNDLE: /path/to/my/ca
      context2env: 
        ipaddress:
      commands:
        - curl https://$IPADDRESS/
        
=head1 DESCRIPTION

This handler allows the execution of arbitrary commands on the host system, 
e.g. for checking access rules from a remote site instead of localhost inside
the test vm.

=head1 OPTIONS

  environment : specify environment variables and their values for this job

  context2env : set an environment variable with the value from the context. Please be aware that the variable name will be converted to upper case in the environment

  commands    : list of commands to be executed

=head1 CONTEXT

=head2 getters

NONE

=head2 setters

NONE

=head1 DEFAULTS

NONE

=cut
