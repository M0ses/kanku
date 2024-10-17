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
package Kanku::Handler::ImageDownload;

use Moose;
use Kanku::Util::CurlHttpDownload;
use Try::Tiny;
use Path::Tiny;
use Archive::Cpio;

use Kanku::Config;
use Kanku::Config::Defaults;

extends 'Kanku::Handler::HTTPDownload';

sub gui_config {[]}
sub distributable { 1 }
with 'Kanku::Roles::Handler';

has [qw/vm_image_file url/] => (is=>'rw', isa=>'Str');
has 'offline'               => (is=>'rw', isa=>'Bool', default=>0);

sub prepare {
  my $self = shift;
  my $ctx  = $self->job()->context();

  $self->offline(1)   if ($ctx->{offline});

  return {
    state => 'succeed',
    message => "Preparation finished successfully"
  };
}

sub execute {
  my $self   = shift;
  my $ctx    = $self->job()->context();
  my $logger = $self->logger;

  if ( $self->offline ) {
    return $self->get_from_history();
  }

  if (! $self->url ) {
    if ( $ctx->{vm_image_url} ) {
      $self->url($ctx->{vm_image_url});
    } elsif ( $ctx->{obs_direct_url} ) {
      $self->url($ctx->{obs_direct_url});
    } else {
      die "Neither vm_image_url nor obs_direct_url found in context"
    }
  }
  my $cfg  = Kanku::Config->instance();

  my $curl = Kanku::Util::CurlHttpDownload->new(
    url       => $self->url,
    etag      => $self->get_etag,
    cache_dir => $cfg->cache_dir,
  );


  my @_of = split '/', $self->url;
  my $_outfile = ($ctx->{vagrant_boxfile}) ? $ctx->{vagrant_boxfile} : pop @_of;
  $curl->output_file($_outfile);

  $logger->debug("Using output file: ".$curl->output_file);

  $ctx->{vm_image_file} = $curl->output_file;

  my $tmp_file;
  my $etag;

  try {
    ($tmp_file, $etag) = $curl->download();
  } catch {
    my $e = $_;

    die $e if ( $e !~ /'404'$/);
    die $e if ( ! $ctx->{obs_direct_url} );

    $logger->warn("Failed to download: ".$curl->url);

    $logger->debug("obs_direct_url = $ctx->{obs_direct_url}");
    $curl->url($ctx->{obs_direct_url});

    $logger->info("Trying alternate url ".$curl->url);

    if (! $ctx->{public_api} ) {
      $curl->username($ctx->{obs_username}) if $ctx->{obs_username};
      $curl->password($ctx->{obs_password}) if $ctx->{obs_password};
    }
    ($tmp_file, $etag) = $curl->download();
  };

  $self->update_history($tmp_file, $etag);

  $self->remove_old_images($tmp_file);

  return {
    state => 'succeed',
    message => 'Downloading '.$curl->url." to $tmp_file succeed"
  };
}

sub _calc_output_file {
  my ($self) = @_;
  return [split '/', $self->url]->[-1];
}

sub update_history {
  my ($self, $vm_image_file, $etag) = @_;
  my $ctx = $self->job()->context();

  my $rs = $self->schema->resultset('ImageDownloadHistory')->update_or_create(
    {
      vm_image_url    => $self->url,
      vm_image_file   => $vm_image_file,
      download_time   => time(),
      etag            => $etag,
      project         => $ctx->{obs_project},
      package         => $ctx->{obs_package},
      repository      => $ctx->{obs_repository},
      arch            => $ctx->{obs_arch},
    },
    { key => 'primary' }
  );
}

sub get_etag {
  my ($self) = @_;
  my $ctx = $self->job->context;
  my $filter = {vm_image_url => $ctx->{vm_image_url}};
  my $rs = $self->schema->resultset('ImageDownloadHistory')->find($filter);

  return q{} unless $rs;
  return $rs->etag;
}

sub get_from_history {
  my $self = shift;
  my $ctx = $self->job->context;

  $self->logger->debug("searching for '".$ctx->{vm_image_url}."' in download history");

  my $rs = $self->schema->resultset('ImageDownloadHistory')->find(
    {
      vm_image_url    => $ctx->{vm_image_url},
    }
  );

  die "Could not find result for vm_image_url: $ctx->{vm_image_url}\n" unless $rs;

  $ctx->{vm_image_file} = $rs->vm_image_file;

  return {
    state => 'succeed',
    message => "Sucessfully found vm_image_file '$ctx->{vm_image_file}' in database"
  };

}

sub remove_old_images {
  my ($self, $file) = @_;
  my $ctx           = $self->job->context;
  my $logger        = $self->logger;

  my $rs = $self->schema->resultset('ImageDownloadHistory')->search(
    {
       project    => $ctx->{obs_project},
       package    => $ctx->{obs_package},
       repository => $ctx->{obs_repository},
       arch       => $ctx->{obs_arch},
       vm_image_file => {'-not_like' => $file},
    }
  );
  foreach my $img ($rs->all()) {
    $logger->debug("removing file: " . $img->vm_image_file);
    unlink $img->vm_image_file;
  }
  $rs->delete;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Kanku::Handler::ImageDownload

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::ImageDownload
    options:
      url: http://example.com/path/to/image.qcow2
      output_file: /tmp/mydomain.qcow2


=head1 DESCRIPTION

This handler downloads a file from a given url to the local filesystem and sets vm_image_file.

=head1 OPTIONS

  url             : url to download file from

  vm_image_file   : absolute path to file where image will be store in local filesystem

  offline         : proceed in offline mode (skip download and lookup last
                    downloaded image in database)


=head1 CONTEXT

=head2 getters

  vm_image_url

  domain_name

=head2 setters

  vm_image_file

=head1 DEFAULTS

NONE

=cut
