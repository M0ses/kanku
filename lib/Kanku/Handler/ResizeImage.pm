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
package Kanku::Handler::ResizeImage;

use Moose;

use Path::Tiny;

use Kanku::Config;
use Kanku::Util::VM::Image;

sub gui_config {
  [
    {
      param => 'disk_size',
      type  => 'text',
      label => 'New disk size',
    },
  ];
}
sub distributable { 1 }
with 'Kanku::Roles::Handler';

has [qw/
      vm_image_file
      disk_size
/] => (is => 'rw',isa=>'Str');

sub execute {
  my $self = shift;
  my $ctx  = $self->job->context();
  my $cfg = Kanku::Config->instance();
  my ($tmp);

  my $img  = ($ctx->{vm_image_file} =~ m#/#)
    ? path($ctx->{vm_image_file})
    : path($cfg->cache_dir, $ctx->{vm_image_file});
  my $size = $self->disk_size;

  my $img_obj = Kanku::Util::VM::Image->new();

  $ctx->{tmp_image_file} = $img_obj->resize_image($img, $size);

  return "Sucessfully resized image '$ctx->{tmp_image_file}' to $size";
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Kanku::Handler::ResizeImage

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::ResizeImage
    options:
      disk_size: 100G

=head1 DESCRIPTION

This handler resizes a downloaded image to a given size using 'qemu-img'

=head1 OPTIONS

    disk_size      : new size of disk in GB

=head1 CONTEXT

=head2 getters

 cache_dir

 vm_image_file

=head2 setters

 tmp_image_file

=head1 DEFAULTS

=cut
