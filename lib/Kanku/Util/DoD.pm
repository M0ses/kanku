# Copyright (c) 2015 SUSE LLC
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
package Kanku::Util::DoD;

use Moose;
use Data::Dumper;
use HTTP::Request;
use Template;
use Net::OBS::Client::BuildResults;
use Net::OBS::Client::Project;
use Net::OBS::Client::Package;
use Kanku::Util::CurlHttpDownload;
use Kanku::Config;
use Kanku::Helpers;
use Kanku::Config::Defaults;
use Carp qw/confess croak/;

with 'Kanku::Roles::Logger';

has project => (
  is      => 'rw',
  isa     => 'Str',
);

has repository => (
  is      => 'rw',
  isa     => 'Str',
  default => 'images',
);

has arch => (
  is      => 'rw',
  isa     => 'Str',
  builder => '_build_arch',
);
sub _build_arch {
  Kanku::Config::Defaults->get('Kanku::Config::GlobalVars', 'arch');
}

has package => (
  is      => 'rw',
  isa     => 'Str',
  default => q{},
);

has images_dir => (
  is      => 'rw',
  isa     => 'Str',
  builder => '_build_images_dir',
);

sub _build_images_dir {
   Kanku::Config::Defaults->get('Kanku::Config::GlobalVars', 'images_dir');
}

has base_url => (
  is      => 'rw',
  isa     => 'Str',
  builder => '_build_base_url',
);

sub _build_base_url {
   Kanku::Config::Defaults->get('Kanku::Config::GlobalVars', 'base_url');
}

has download_url => (
  is      =>'rw',
  isa     =>'Str',
  lazy    => 1,
  builder => '_build_download_url',
);

sub _build_download_url {
  my $self = shift;

  my $prj = $self->project();
  $prj =~ s{:}{:/}g;

  return $self->base_url . "$prj/" . $self->repository . q{/};
}

has obsurl => (
  is      =>'rw',
  isa     =>'Str',
  lazy    => 1,
  builder =>'_build_obsurl',
);

sub _build_obsurl {
   Kanku::Config::Defaults->get('Kanku::Config::GlobalVars', 'obsurl');
}

has get_image_file_from_url_cb => (
  is      => 'rw',
  isa     => 'CodeRef',
);

has get_image_file_from_url => (
  is      => 'rw',
  isa     => 'HashRef',
  lazy    => 1,
  builder => '_build_get_image_file_from_url',
);

sub _build_get_image_file_from_url {
  my ($self) = @_;
  my $result = [];
  my $logger = $self->logger;

  $self->get_image_file_from_url_cb(\&_sub_get_image_file_from_url_cb);

  confess("No project set") unless $self->project;


  my $build_results = Net::OBS::Client::BuildResults->new(
    project     => $self->project,
    repository  => $self->repository,
    arch        => $self->arch,
    package     => $self->package,
    apiurl      => $self->obsurl,
    %{$self->auth_config},
  );
  my $binlist = $build_results->binarylist();
  $logger->trace("\$binlist = ".Kanku::Helpers->dump_it($binlist));
  my $record = $self->get_image_file_from_url_cb->($self,$binlist);
  if ( $record ) {
    $record->{url} = $self->download_url .$record->{prefix}. $record->{filename};
    $record->{bin_url} = $self->obsurl . '/build/'.$self->project.q{/}.$self->repository.q{/}.$self->arch.q{/}.$self->package."/$record->{filename}";
    $record->{obs_username} = $build_results->user;
    $record->{obs_password} = $build_results->pass;
  }
  $self->logger->trace("\$record = ".Kanku::Helpers->dump_it($record));
  return $record || {};
}

has [qw/skip_all_checks skip_check_project skip_check_package/ ] => (is => 'ro', isa => 'Bool',default => 0 );
has [qw/use_oscrc/ ] => (is => 'ro', isa => 'Bool',default => 1);

has auth_config => (
  is => 'rw',
  isa => 'HashRef',
  lazy => 1,
  builder => '_build_auth_config',
);
sub _build_auth_config {
  my ($self)     = @_;
  my $cfg        = {};
  my $use_oscrc  = Kanku::Config::Defaults->get(__PACKAGE__, 'use_oscrc') || $self->use_oscrc;
  $self->logger->debug("use_oscrc: $use_oscrc");

  if (defined $use_oscrc) {
    if (!$use_oscrc) {
      my $default_credentials = Kanku::Config::Defaults->get(__PACKAGE__, $self->obsurl);
      my $user = Kanku::Config::Defaults->get(__PACKAGE__, 'obs_username');
      my $pass = Kanku::Config::Defaults->get(__PACKAGE__, 'obs_password');
      if ( $default_credentials || $user || $pass) {
	$cfg->{user} = $default_credentials->{obs_username} || $user || q{};
	$cfg->{pass} = $default_credentials->{obs_password} || $pass || q{};
      } else {
	$self->logger->debug("Using Net::OBS::Client config");
	my $net_credentials = Kanku::Config::Defaults->get('Net::OBS::Client', 'credentials');
	$cfg = {%{$net_credentials->{$self->obsurl}}} if (ref($net_credentials->{$self->obsurl}) eq 'HASH');
      }
    }
    $cfg->{use_oscrc} = $use_oscrc;
  } else {
    $cfg->{use_oscrc} = $self->use_oscrc;
  }
  $self->logger->debug("auth_config: ".Kanku::Helpers->dump_it($cfg));
  return $cfg;
}

has preferred_extension => (
  is      => 'rw',
  isa     => 'Str',
  lazy    => 1,
  default => q{},
);

sub download {
  my $self  = shift;
  my $fn    = $self->get_image_file_from_url()->{filename};
  my $url   = $self->download_url . $fn;
  my $file  = $self->images_dir() . q{/} . $fn;

  $self->logger->debug(' -- state of skip_all_checks : '.$self->skip_all_checks);

  $self->check_before_download() unless $self->skip_all_checks;

  my $curl = Kanku::Util::CurlHttpDownload->new(
      url         => $url,
      output_file => $file,
      %{$self->auth_config},
  );

  return $curl->download();

}

sub check_before_download {
  my $self = shift;

  if (!$self->skip_check_project()) {
      my $prj = Net::OBS::Client::Project->new(
          name        => $self->project,
          repository  => $self->repository,
          arch        => $self->arch,
          apiurl      => $self->obsurl,
	  %{$self->auth_config},
      );

      if ($prj->dirty or $prj->code ne 'published') {
        my ($p, $r, $a, $u) = ( $self->project,
                                $self->repository,
                                $self->arch,
                                $self->obsurl,);
        croak("Project '$p' on '$u' not ready yet.\n"
             ."Please check 'osc r $p -a $a -r $r'\n"
	     ."Or use '--skip_all_checks' option\n"
        );
      }
  }

  if (!$self->skip_check_package()) {
      my $pkg = Net::OBS::Client::Package->new(
          name        => $self->package,
          project     => $self->project,
          repository  => $self->repository,
          arch        => $self->arch,
          apiurl      => $self->obsurl,
	  %{$self->auth_config},
      );

      if ( $pkg->code ne 'succeeded' ) {
        my ($p, $r, $a, $u, $pkg) = ($self->project,
                                     $self->repository,
                                     $self->arch,
                                     $self->obsurl,
                                     $self->package,);
        croak("Package '$p/$pkg' not ready yet\n"
             ."Please check 'osc r $p $pkg -a $a -r $r'\n"
	     ."Or use '--skip_all_checks' option\n"
        );
      }
  }

}

sub _sub_get_image_file_from_url_cb {
    my $self = shift;
    my $arg = shift;
    my $reg = qr/\.(qcow2(\.xz)?|raw(\.xz)?|vmdk(.xz)?|vdi(.xz)?|vhdfixed\.xz|install.iso|iso)$/;
    my %all_images;

    foreach my $bin (@{$arg}) {
       $all_images{$1} = $bin if $bin->{filename} =~ $reg;
       $bin->{prefix} = ($bin->{filename} =~ /\.iso$/ ) ? 'iso/' : q{};
    }
    $self->logger->debug('all_images = '.Dumper(\%all_images));
    if ($self->preferred_extension) {
      if (!$all_images{$self->preferred_extension}) {
        croak('Found no images with preferred_extention "'.$self->preferred_extension.q{"});
      }
      return $all_images{$self->preferred_extension};
    } else {
      if (%all_images > 1) {
        croak('More than one matching image found - please specify preferred_extension in your configuration');
      }
      return [values %all_images]->[0];
    }
}

__PACKAGE__->meta->make_immutable();

1;
