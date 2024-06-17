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
package Kanku::Handler::RevertQcow2Snapshot;

use Moose;
use Kanku::Config;

sub _build_gui_config {
  [
    {
      param => 'disk_image_file',
      type  => 'text',
      label => 'Path to file to revert'
    },
    {
      param => 'snapshot_id',
      type  => 'text',
      label => 'Id of snapshot to apply'
    },
  ];
}
has 'distributable' => (is=>'ro', isa=>'Bool', default => 0);
with 'Kanku::Roles::Handler';

has [qw/disk_image_file/] => (is => 'rw',isa=>'Str');

has [qw/
      snapshot_id
/] => (is => 'rw',isa=>'Int');

sub execute {
  my $self = shift;

  my $s_id = $self->snapshot_id || 1;

  my $cmd = "qemu-img snapshot -a $s_id " . $self->disk_image_file;
  my @out = `$cmd 2>&1`;

  if ( $? ) {
    my $err = join ("\n",@out);
    die "$err\n";
  }

  return {
    code    => 0,
    message => "Reverted disk " . $self->disk_image_file ." successfully to snapshot: $s_id"
  };

}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Kanku::Handler::RevertQcow2Snapshot

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::RevertQcow2Snapshot
    options:
      disk_image_file: domain-additional-disk.qcow2
      ....

=head1 DESCRIPTION

This handler creates a new disk from the given parameters.


=head1 OPTIONS

    disk_image_file       : filename of the disk to create

    snapshot_id           : id of snapshot to revert to


=head1 CONTEXT

=head2 getters

=head2 setters

=head1 DEFAULTS

=cut

