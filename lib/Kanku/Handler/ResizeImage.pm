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
use Path::Class::File;
use Data::Dumper;

with 'Kanku::Roles::Handler';

has [qw/
      vm_image_file
      disk_size
/] => (is => 'rw',isa=>'Str');

has 'disk_size'         => ( is => 'rw',isa => 'Str' );

has 'use_cache'         => ( is => 'rw',isa => 'Bool' );

has gui_config => (
  is => 'ro',
  isa => 'ArrayRef',
  lazy => 1,
  default => sub {
      [
        {
          param => 'disk_size',
          type  => 'text',
          label => 'New disk size'
        },
      ];
  }
);

sub distributable { 1 }

sub execute {
  my $self = shift;
  my $ctx  = $self->job->context();
  my ($img,$size);

  $ctx->{use_cache} = $self->use_cache if defined $self->use_cache;

  if ( $ctx->{use_cache} ) {
    $self->vm_image_file(Path::Class::File->new($ctx->{cache_dir},$ctx->{vm_image_file})->stringify);
  } else {
    $self->vm_image_file($ctx->{vm_image_file});
  }

  # 0 means that format is the same as suffix
  my %supported_formats = (
    qcow2    => 0,
    raw      => 0,
    img      => 'raw',
    vhdfixed => 'raw'
  );
  my $supported_suf = join('|', keys(%supported_formats));
  if ( $self->vm_image_file =~ /\.($supported_suf)$/ ) {
    my $ext = $1;
    if ( $self->disk_size ) {
      my $format = "-f " . ( $supported_formats{$ext} || $ext );
      $img  = $self->vm_image_file;
      $size = $self->disk_size;
      `qemu-img resize $format $img $size`;
    }
  } else {
    die "Image file has wrong suffix '".$self->vm_image_file."'.\nList of supported suffixes: <$supported_suf> !\n";
  }

  return "Sucessfully resized image '$img' to $size"
}

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

=head1 DEFAULTS

=cut
