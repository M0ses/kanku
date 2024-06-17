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
package Kanku::Roles::Handler;


use Moose::Role;

requires 'execute';
requires 'distributable';
requires '_build_gui_config';

has 'last_run_result' => (
  is => 'rw',
  isa => 'HashRef'
);

has 'job_definition' => (
  is => 'rw',
  isa => 'HashRef'
);

has 'logger' => (
  is => 'rw',
  isa => 'Object'
);

has 'job' => (
  is => 'rw',
  isa => 'Object'
);

has 'schema' => (
  is  => 'rw',
  isa => 'Object'
);

has 'running_remotely' => (
  is  => 'rw',
  isa => 'Bool',
  default => 0,
);

has gui_config => (
  is      => 'ro',
  isa     => 'ArrayRef',
  lazy    => 1,
  builder => '_build_gui_config',
);

has cfg => (
  is      => 'ro',
  isa     => 'HashRef',
  lazy    => 1,
  builder => '_build_cfg'
);
sub _build_cfg { return Kanku::Config->instance()->config(); }

sub prepare {

  return {
    code    => 0,
    message => "Nothing to do!"
  }

}

sub finalize {

  return {
    code    => 0,
    message => "Nothing to do!"
  }

}

sub evaluate_console_credentials {
  my ($self) = @_;
  my $ctx  = $self->job()->context();

  $self->domain_name($ctx->{domain_name}) if ( ! $self->domain_name && $ctx->{domain_name});
  $self->login_user($ctx->{login_user})   if ( ! $self->login_user  && $ctx->{login_user});
  $self->login_pass($ctx->{login_pass})   if ( ! $self->login_pass  && $ctx->{login_pass});

  # prefer randomized password
  $self->login_pass($ctx->{pwrand}->{$self->login_user})
    if $ctx->{pwrand}->{$self->login_user};

}

1;

