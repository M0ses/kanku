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
package Kanku::Handler::Vagrant;

use strict;
use warnings;

use Moose;

use URI;
use Carp;
use JSON::XS;
use Try::Tiny;
use Path::Tiny;
use Archive::Tar;

use Kanku::Config::Defaults;
use Net::OBS::LWP::UserAgent;

sub gui_config {
  [
    {
      param => 'base_url',
      type  => 'text',
      label => 'Base URL',
    },
    {
      param => 'box',
      type  => 'text',
      label => 'Vagrant Box name',
    },
    {
      param => 'box_version',
      type  => 'text',
      label => 'Vagrant Box version',
    },
    {
      param => 'offline',
      type  => 'checkbox',
      label => 'Offline mode',
    },
  ];
}
sub distributable { 0 }
with 'Kanku::Roles::Handler';

has 'base_url' => (
  is      =>'rw',
  isa     =>'Str',
  builder => '_build_base_url',
);
sub _build_base_url {
  my ($self) = @_;
  Kanku::Config::Defaults->get(__PACKAGE__, 'base_url');
}

has 'box' => (
  is      =>'rw',
  isa     =>'Str',
  builder => '_build_box',
);
sub _build_box {
  my ($self) = @_;
  Kanku::Config::Defaults->get(__PACKAGE__, 'box');
}

has 'box_version' => (
  is      =>'rw',
  isa     =>'Str',
  builder => '_build_box_version',
);
sub _build_box_version {
  my ($self) = @_;
  Kanku::Config::Defaults->get(__PACKAGE__, 'box_version');
}

has 'login_user' => (
  is      =>'rw',
  isa     =>'Str',
  builder => '_build_login_user',
);
sub _build_login_user {
  my ($self) = @_;
  Kanku::Config::Defaults->get(__PACKAGE__, 'login_user');
}

has 'login_pass' => (
  is      =>'rw',
  isa     =>'Str',
  builder => '_build_login_pass',
);
sub _build_login_pass {
  my ($self) = @_;
  Kanku::Config::Defaults->get(__PACKAGE__, 'login_pass');
}

has offline => (
  is      => 'rw',
  isa     => 'Bool',
  builder => '_build_offline',
);
sub _build_offline {
  return 0;
}

sub prepare {
  my ($self)    = @_;
  my $ctx       = $self->job()->context();

  $self->offline(1)           if ( $ctx->{offline} );
  $ctx->{login_user} = $self->login_user;
  $ctx->{login_pass} = $self->login_pass;


  return {
    state => 'succeed',
    message => "Done.",
  };
}

sub _get_provider {
  my ($self, $name, $data) = @_;
  for my $p (@{$data->{providers}}) {
    return $p if $p->{name} eq $name;
  }
  return;
}

sub _get_data_by_version {
  my ($self, $data) = @_;
  for my $v (@{$data->{versions}}) {
    return $v if ($self->box_version eq 'latest' or $v->{version} eq $self->box_version);
  }
}

sub execute {
  my ($self) = @_;
  my $ctx    = $self->job()->context();
  my $logger = $self->logger;

  if ( $self->offline ) {
    return $self->get_from_history();
  }


  # FIXME: offline needs to be implemented
  my $ua     = LWP::UserAgent->new();
  my $url    = $self->base_url.'/'.$self->box;
  $logger->debug("Searching for libvirt provider in $url");

  my $res    = $ua->get($url, 'Accept' => 'application/json');
  croak($res->status_line) unless $res->code == 200;

  my $json = decode_json($res->content);

  my $box_data = $self->_get_data_by_version($json);
  my $provider = $self->_get_provider('libvirt', $box_data);

  if (!$provider) {
    croak(
      "Could not find libvirt provider for box.".
      " Please check the following url! $url"
    );
  }

  my $uri  = URI->new($provider->{url});
  my $path = $uri->path;

  my $code = 300;
  my $durl = $provider->{url};

  $logger->debug("Download URL for libvirt provider: $durl");

  while ($code < 400) {
    $res  = $ua->head($durl);
    $code = $res->code;
    last if $code == 200;
    $durl = $res->header('Location');
    $logger->debug("new location: $durl");
  }

  my $cache_dir = Kanku::Config::Defaults->get('Kanku::Config::GlobalVars', 'cache_dir');
  path($cache_dir)->mkdir;

  my $duri     = URI->new($durl);
  my $dpath    = $duri->path;

  my @parts    = split('/', $dpath);
  my $dfile    = pop @parts;
  my $box_file = $self->box;
  $box_file    =~ s#/#--#g;
  $cache_dir   =~ s#/+$##;
  my $outfile  =  "$cache_dir/VAGRANTBOX-$box_file-$dfile.tar.gz";

  $ctx->{vm_image_url} = $durl;

  my $neo_ua = Net::OBS::LWP::UserAgent->new();

  my $dl_res = $neo_ua->mirror(
    url  => $durl,
    file => $outfile,
  );

  my $tar = Archive::Tar->new($outfile);
  my @box_files = $tar->get_files('box.img');
  croak('Unknown vagrant box file format') if @box_files > 1 || !@box_files;
  my $qcow2 = $outfile;
  $qcow2 =~ s#.tar.gz$#.qcow2#;
  $box_files[0]->extract($qcow2);
  $ctx->{vm_image_file} = $qcow2;
  $ctx->{image_type}    = 'vagrant';

  $self->update_history;

  return {
    code    => 0,
    state   => 'succeed',
    message => "Downloaded $durl -> $outfile",
  };
}

sub update_history {
  my ($self) = @_;

  my $rs = $self->schema->resultset('ObsCheckHistory')->update_or_create(
    {
      obsurl      => $self->base_url,
      project     => $self->box,
      package     => $self->box_version,
      check_time  => time(),
      vm_image_url=> $self->job->context->{vm_image_url},
    },
    {
      unique_obscheck => [$self->base_url, $self->box, $self->box_version],
    },
  );

  return;
}

sub get_from_history {
  my $self = shift;
  my $ctx  = $self->job->context;

  my $rs = $self->schema->resultset('ObsCheckHistory')->find(
    {
      obsurl      => $self->base_url,
      project     => $self->box,
      package     => $self->box_version,
    },
  );

  croak('Could not found last entry in database') if (! $rs);

  $ctx->{vm_image_url} = $rs->vm_image_url;


  return {
    code    => 0,
    state   => 'succeed',
    message => "Sucessfully fetch vm_image_url '$ctx->{vm_image_url}' from database",
  };
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

Kanku::Handler::Vagrant

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::Vagrant
    options:
      box: opensuse/Tumbleweed.x86_64


=head1 DESCRIPTION

This handler downloads a file from a given url to the local filesystem and sets vm_image_file.

=head1 OPTIONS

  base_url            : API url to search for boxes

  box                 : Vagrant box name like specified in Vagrantfile

  box_version         : Optional version for vagrant box (default: latest)

  offline             : proceed in offline mode (skip download and lookup last
                        downloaded image in database)

=head1 CONTEXT

=head2 getters

  offline



=head2 setters

  image_type

  vm_image_url

  vm_image_file

  login_user

  login_pass

=head1 DEFAULTS

NONE

=cut

