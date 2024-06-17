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
package Kanku::Handler::OBSCheck;

use Moose;
use Kanku::Util::DoD;
use Try::Tiny;
use Data::Dumper;
use Carp;

sub _build_gui_config {
  [
    {
      param => 'api_url',
      type  => 'text',
      label => 'API URL',
    },
    {
      param => 'skip_all_checks',
      type  => 'checkbox',
      label => 'Skip all checks',
    },
    {
      param => 'project',
      type  => 'text',
      label => 'Project',
    },
    {
      param => 'package',
      type  => 'text',
      label => 'Package',
    },
    {
      param => 'repository',
      type  => 'text',
      label => 'Repository',
    },
    {
      param => 'preferred_extension',
      type  => 'text',
      label => 'Extension (qcow2, raw, etc.)',
    },
  ];
}
has 'distributable' => (is=>'ro', isa=>'Bool', default => 1);
with 'Kanku::Roles::Handler';

has dod_object => (
  is      =>'rw',
  isa     =>'Object',
  lazy    => 1,
  builder => '_build_dod_object',
);
sub _build_dod_object  {
  my ($self) = @_;
  Kanku::Util::DoD->new(
    skip_all_checks     => $self->skip_all_checks,
    skip_check_project  => $self->skip_check_project,
    skip_check_package  => $self->skip_check_package,
    project             => $self->project,
    package             => $self->package,
    arch                => $self->arch,
    api_url             => $self->api_url,
    preferred_extension => $self->preferred_extension,
    use_oscrc           => $self->use_oscrc,
  );
}

has ['api_url','project','package'] => (is=>'rw',isa=>'Str',required=>1);

has '+api_url' => (default => 'https://api.opensuse.org/public');

has ['base_url', 'repository', 'preferred_extension', 'arch'] => (is=>'rw',isa=>'Str');
has '+preferred_extension' => (lazy => 1, default => q{});
has '+arch' => (lazy => 1, default => 'x86_64');
has _changed => (is=>'rw',isa=>'Bool',default=>0);

has _binary => (is=>'rw',isa=>'HashRef',lazy=>1,default=>sub { { } });

has [qw/skip_check_project skip_check_package skip_download/ ] => (
  is      => 'ro',
  isa     => 'Bool',
  default => 0,
);

has [qw/offline skip_all_checks use_oscrc/ ] => (is => 'rw', isa => 'Bool',default => 0 );
has [qw/use_oscrc/ ] => (is => 'rw', isa => 'Bool',default => 0);

sub prepare {
  my $self      = shift;
  my $ctx       = $self->job()->context();

  $self->offline(1)           if ( $ctx->{offline} );
  $self->skip_all_checks(1)   if ( $ctx->{skip_all_checks} );

  return {
    state => 'succeed',
    message => 'Preparation finished successfully',
  };
}

sub execute {
  my $self = shift;

  if ($self->offline) {
    return $self->get_from_history();
  }

  my $last_run  = $self->last_run_result();
  my $dod       = $self->dod_object();

  if ( $self->base_url ) {
    # prevent from errors because of missing trailing slash
    if (  $self->base_url !~ q{/$} ) { $self->base_url($self->base_url.q{/}) }
    $dod->base_url($self->base_url);
  }
  $dod->base_url($self->base_url)     if $self->base_url;
  $dod->repository($self->repository) if $self->repository;

  $self->logger->debug('Checking project: ' . $dod->project);

  my $binary    = $dod->get_image_file_from_url();

  my $ctx       = $self->job()->context();

  # check if $binary is HashRef to prevent Moose from
  # crashing the whole application with an exception
  # if value is undef
  $self->_binary($binary) if ( ref($binary) eq 'HashRef');

  # Don`t check for skipping if no last run found
  # or Job was triggered instead of scheduled
  # triggered jobs coming from external
  # and have higher priority
  if (
      $last_run and
      (! $self->job->triggered) and
      (! $self->skip_all_checks)
  ) {
    my $prep_result = $last_run->{prepare}->{binary};
    foreach my $key (qw/mtime filename size/) {
      my $bv = $binary->{$key} || q{};
      my $pv = $prep_result->{$key} || q{};
      if ( $bv ne $pv ) {
        $self->logger->debug('Change detected');
        $self->_changed(1);
      }
    }
  } else {
    $self->_changed(1);
  }

  if ( ! $self->_changed ) {
    $self->logger->debug('Setting job skipped');
    $self->job->skipped(1);
    return {
      code    => 0,
      state   => 'skipped',
      message => 'execution skipped because binary did not change since last run',
    };
  }

  try {
    $dod->check_before_download() unless $self->skip_all_checks;
  }
  catch {
    my $e = $_;
    if (! ref($e) && $e =~ /^(Project|Package) not ready yet$/ ) {
      $self->logger->warn($e);
      $self->job->skipped(1);
      return {
	code    => 0,
	state   => 'skipped',
	message => $e,
      };
    }
    croak($e);
  };

  $ctx->{vm_image_url}   = $binary->{url};
  $ctx->{obs_direct_url} = $binary->{bin_url};
  $ctx->{public_api}     = $binary->{public_api};
  $ctx->{obs_filename}   = $binary->{filename};
  $ctx->{obs_username}   = $binary->{obs_username};
  $ctx->{obs_password}   = $binary->{obs_password};

  $ctx->{obs_project}    = $self->project;
  $ctx->{obs_package}    = $self->package;
  $ctx->{obs_repository} = $self->repository;
  $ctx->{obs_arch}       = $self->arch;
  $ctx->{api_url}        = $self->api_url;

  if (!($ctx->{vm_image_url} or $ctx->{obs_direct_url})) {
    croak("Neither vm_image_url nor obs_direct_url found\n"
      ."HINT: Try \n\nosc api /build/"
      . $dod->project .q{/}
      . $dod->repository .q{/}
      . $dod->arch .q{/}
      . $dod->package
      . "\n\nfor further debugging\n");
  }

  $self->update_history();

  return {
    code    => 0,
    state   => 'succeed',
    message => 'Sucessfully checked project '.$self->project.' under url '
                 .$self->api_url ."\n"
                 .' ('
                 .    "vm_image_url: $ctx->{vm_image_url}, "
                 .    "obs_direct_url: $ctx->{obs_direct_url}"
                 .')',
  };
}

sub update_history {
  my $self = shift;

  my $rs = $self->schema->resultset('ObsCheckHistory')->update_or_create(
    {
      api_url     => $self->api_url,
      project     => $self->project,
      package     => $self->package,
      check_time  => time(),
      vm_image_url=> $self->job->context->{vm_image_url},
    },
    {
      unique_obscheck => [$self->api_url,$self->project,$self->package],
    },
  );

  return;
}

sub get_from_history {
  my $self = shift;
  my $ctx  = $self->job->context;
  my $rs = $self->schema->resultset('ObsCheckHistory')->find(
    {
      api_url     => $self->api_url,
      project     => $self->project,
      package     => $self->package,
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

1;
__END__

=head1 NAME

Kanku::Handler::OBSCheck

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::OBSCheck
    options:
      api_url: https://api.opensuse.org/public
      project: devel:kanku:images
      package: openSUSE-Leap-15.0-JeOS
      repository: images_leap_15_0


=head1 DESCRIPTION

This handler downloads a file from a given url to the local filesystem and sets vm_image_file.

=head1 OPTIONS

  api_url             : API url to OBS server

  base_url            : Url to use for download

  project             : project name in OBS

  package             : package name to search for in project

  repository          : repository name to search for in project/package

  skip_all_checks     : skip checks all checks on project/package on obs side before downloading image

  skip_check_project  : skip check of project state before downloading image

  skip_check_package  : skip check of package state before downloading image

  skip_download       : no changes detected in OBS skip downloading image file if found in cache

  offline             : proceed in offline mode (skip download and lookup last
                        downloaded image in database)

=head1 CONTEXT

=head2 getters

  offline

  skip_all_checks


=head2 setters

  vm_image_url

  api_url

=head1 DEFAULTS

NONE

=cut

