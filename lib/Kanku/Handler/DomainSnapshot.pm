# Copyright (c) 2022 SUSE LLC
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
package Kanku::Handler::DomainSnapshot;

use Moose;

use Kanku::Util::VM;

sub _build_gui_config {
  [
    {
      param => 'name',
      type  => 'text',
      label => 'Snapshot name'
    },
  ];
}
sub distributable { 1 }
with 'Kanku::Roles::Handler';

has [qw/action name domain_name login_user login_pass/] => (is=>'rw', isa=>'Str');
has '+action' => (default=>'create');

sub execute {
  my ($self) = @_;
  my $ctx    = $self->job()->context();
  my $action = $self->action;
  $self->domain_name($ctx->{domain_name})       if ( ! $self->domain_name && $ctx->{domain_name});
  $self->login_user($ctx->{login_user})         if ( ! $self->login_user  && $ctx->{login_user});
  $self->login_pass($ctx->{login_pass})         if ( ! $self->login_pass  && $ctx->{login_pass});
  $self->name($ctx->{snapshot_name})            if ( ! $self->name  && $ctx->{snapshot_name});

  my $vm     = Kanku::Util::VM->new(
                domain_name   => $self->domain_name,
                snapshot_name => $self->name || 'current',
                login_user    => $self->login_user || 'root',
                login_pass    => $self->login_pass || 'kankudai',
              );

  if ($action eq 'create') {
    $vm->create_snapshot;
  } elsif ($action eq 'revert') {
    $vm->revert_snapshot;
  } elsif ($action eq 'remove') {
    $vm->remove_snapshot;
  } else {
    die "Action '$action' is not one of the known actions (create/revert/remove)\n";
  }


  return {
    code => 0,
    message => "Action '$action' for snapshot '". $self->name."' in domain '".$self->domain_name."' succeed."
  };
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

Kanku::Handler::DomainSnapshot

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::DomainSnapshot
    options:
      delay: 120
      reason: Give XY the change to finish his job

=head1 DESCRIPTION

This handler helps you to manage domain snapshots.


=head1 OPTIONS


    command             : possible commands: create/delete/revert

    name                : name of snapshot


=head1 CONTEXT

=head2 getters

NONE

=head2 setters

NONE

=head1 DEFAULTS

    command		: create

    name		: current


=cut

