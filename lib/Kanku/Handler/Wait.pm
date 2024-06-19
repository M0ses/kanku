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
package Kanku::Handler::Wait;

use Moose;

sub _build_gui_config {
  [
    {
      param => 'delay',
      type  => 'text',
      label => 'Time in sec to wait'
    },
    {
      param => 'reason',
      type  => 'text',
      label => 'Description for reason to wait'
    },
  ];
}
has 'distributable' => (is=>'ro', isa=>'Int', default => 0);
with 'Kanku::Roles::Handler';

has [qw/delay reason/] => (is=>'rw',isa=>'Str');

sub execute {
  my $self = shift;

  sleep $self->delay;

  my $reason = $self->reason || "Not configured";

  return {
    code => 0,
    message => "Slept for " . $self->delay . ". Reason: $reason"
  };
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

Kanku::Handler::Wait

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::Wait
    options:
      delay: 120
      reason: Give XY the change to finish his job

=head1 DESCRIPTION

This handler simply waits for given delay in seconds and the reason wil be logged for documenation purposes.


=head1 OPTIONS


    delay                 : sleep for n seconds

    reason                : message to be logged


=head1 CONTEXT

=head2 getters

NONE

=head2 setters

NONE

=head1 DEFAULTS

    reason                : "Not configured"    images_dir     /var/lib/libvirt/images


=cut

