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
package Kanku::Handler::HTTPDownload;

use Moose;
use Kanku::Util::CurlHttpDownload;

sub gui_config {[]}
sub distributable { 1 }
with 'Kanku::Roles::Handler';

has dod_object => (
  is      =>'rw',
  isa     =>'Object',
  lazy    => 1,
  default => sub  {
    my $self = shift;
    Kanku::Util::CurlHttpDownload->new( url => $self->url );
  },
);

has ['url'] => (is=>'rw',isa=>'Str',required=>1);
has ['output_file','output_dir'] => (is=>'rw',isa=>'Str');

sub prepare {
  my $self = shift;

  my $dod  = $self->dod_object();

  $dod->logger($self->logger)           if $self->logger;
  $dod->output_dir($self->output_dir)   if $self->output_dir;
  $dod->output_file($self->output_file) if $self->output_file;


  # Don`t check for skipping if no last run found
  # or Job was triggered instead of scheduled
  # triggered jobs coming from external
  # and have higher priority
  return {
    code    => 0,
    message => "Preparation successful"
  };
}

sub execute {
  my $self = shift;
  my $dod  = $self->dod_object();


  my $file = $dod->download();

  die "Error while downloading $file " . $self->url if (! -f $file );

  $self->job()->context()->{vm_image_file} = $file;

  return {
    state => 'succeed',
    message => "Sucessfully downloaded image to $file"
  };
}

1;

__END__

=head1 NAME

Kanku::Handler::HTTPDownload

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::HTTPDownload
    options:
      url: http://example.com/path/to/image.qcow2
      output_file: /tmp/mydomain.qcow2


=head1 DESCRIPTION

This handler downloads a file from a given url to an output_file or output_dir in the filesystem of the host.

=head1 OPTIONS

  url         : url to download file from

  output_file : absolute path to output_file

  output_dir  : absolute path to directory where file is stored (filename will be preserved).

=head1 CONTEXT

=head2 getters

NONE

=head2 setters

  vm_image_file

=head1 DEFAULTS

NONE

=cut

