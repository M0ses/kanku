# Copyright (c) 2026 SUSE LLC
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
package Kanku::Handler::WaitForPackage;

use Moose;
use Try::Tiny;
use Net::OBS::Client::Project;
use Kanku::Config::Defaults;
use Kanku::Helpers;
use Carp qw/confess croak/;

sub gui_config {
  [
    {
      param => 'obsurl',
      type  => 'text',
      label => 'OBS API URL',
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
      param => 'timeout',
      type  => 'text',
      label => 'Timeout in seconds',
    },
  ];
}

sub distributable { 1 }
with 'Kanku::Roles::Handler';

has 'obsurl' => (
  is      => 'rw',
  isa     => 'Str',
  lazy    => 1,
  builder => '_build_obsurl',
);

sub _build_obsurl {
  my ($self) = @_;
  return $self->job->context->{obsurl}
      || Kanku::Config::Defaults->get('Kanku::Config::GlobalVars', 'obsurl');
}

has ['project', 'package', 'repository'] => (
  is       => 'rw',
  isa      => 'Str',
  required => 1,
);

has 'arch' => (
  is      => 'rw',
  isa     => 'Str',
  lazy    => 1,
  builder => '_build_arch',
);

sub _build_arch {
  return Kanku::Config::Defaults->get('Kanku::Config::GlobalVars', 'arch');
}

has 'timeout' => (
  is      => 'rw',
  isa     => 'Int',
  lazy    => 1,
  default => 3600,
);

has 'poll_interval' => (
  is      => 'rw',
  isa     => 'Int',
  lazy    => 1,
  default => 30,
);

has 'use_oscrc' => (
  is      => 'rw',
  isa     => 'Bool',
  lazy    => 1,
  default => 1,
);

has auth_config => (
  is      => 'rw',
  isa     => 'HashRef',
  lazy    => 1,
  builder => '_build_auth_config',
);

sub _build_auth_config {
  my ($self)     = @_;
  my $cfg        = {};
  my $use_oscrc  =
    Kanku::Config::Defaults->get(__PACKAGE__, 'use_oscrc')
    // $self->use_oscrc;

  $self->logger->debug("use_oscrc: $use_oscrc");

  if (defined $use_oscrc) {
    if (!$use_oscrc) {
      my $default_credentials =
        Kanku::Config::Defaults->get(__PACKAGE__, $self->obsurl);
      my $user = Kanku::Config::Defaults->get(__PACKAGE__, 'obs_username');
      my $pass = Kanku::Config::Defaults->get(__PACKAGE__, 'obs_password');
      if ( $default_credentials || $user || $pass) {
        $cfg->{user} = $default_credentials->{obs_username} || $user || q{};
        $cfg->{pass} = $default_credentials->{obs_password} || $pass || q{};
      } else {
        $self->logger->debug("Using Net::OBS::Client config");
        my $net_credentials =
          Kanku::Config::Defaults->get('Net::OBS::Client', 'credentials');
        if (ref($net_credentials->{$self->obsurl}) eq 'HASH') {
          $cfg = {%{$net_credentials->{$self->obsurl}}};
        }
      }
    }
    $cfg->{use_oscrc} = $use_oscrc;
  } else {
    $cfg->{use_oscrc} = $self->use_oscrc;
  }
  $self->logger->debug("auth_config: " . Kanku::Helpers->dump_it($cfg));
  return $cfg;
}

sub prepare {
  my ($self) = @_;
  # Ensure required options are present during prepare phase.
  # This prevents execute failing midway if setup is invalid.
  croak "Missing required parameter 'project'" unless $self->project;
  croak "Missing required parameter 'package'" unless $self->package;
  croak "Missing required parameter 'repository'" unless $self->repository;

  return {
    code    => 0,
    state   => 'succeed',
    message => 'Preparation finished successfully',
  };
}

sub execute {
  my ($self) = @_;
  my $logger = $self->logger;

  my $obsurl        = $self->obsurl;
  my $project       = $self->project;
  my $package       = $self->package;
  my $repository    = $self->repository;
  my $arch          = $self->arch;
  my $timeout       = $self->timeout;
  my $poll_interval = $self->poll_interval;

  $logger->debug("Starting WaitForPackage...");
  $logger->debug("  OBS URL:       $obsurl");
  $logger->debug("  Project:       $project");
  $logger->debug("  Package:       $package");
  $logger->debug("  Repository:    $repository");
  $logger->debug("  Arch:          $arch");
  $logger->debug("  Timeout:       $timeout sec (0 = infinite)");
  $logger->debug("  Poll Interval: $poll_interval sec");

  my $start_time = time();

  while (1) {
    my $elapsed = time() - $start_time;

    # Initialize project client to check build/publish statuses
    my $prj = Net::OBS::Client::Project->new(
      name       => $project,
      repository => $repository,
      arch       => $arch,
      apiurl     => $obsurl,
      %{$self->auth_config},
    );

    # Query resultlist from OBS. This returns statuses for all packages
    # under the configured architecture and repository.
    my $res;
    try {
      $res = $prj->fetch_resultlist(arch => $arch);
    } catch {
      my $e = $_;
      $logger->error("Failed to fetch build resultlist from OBS: $e");
    };

    # We filter and process only the matching repository/arch entries.
    my $found_repo = 0;
    my @target_packages;

    if ($res && ref($res->{result}) eq 'ARRAY') {
      foreach my $repo_entry (@{$res->{result}}) {
        next if $repo_entry->{repository} ne $repository;
        next if $repo_entry->{arch} ne $arch;

        $found_repo = 1;

        if (ref($repo_entry->{status}) eq 'ARRAY') {
          # Match the specific package and any of its multibuild/flavor
          # subpackages (e.g. package:flavor)
          @target_packages = grep {
            $_->{package} eq $package ||
            $_->{package} =~ /^\Q$package\E:/
          } @{$repo_entry->{status}};
        }
      }
    }

    if (!$found_repo) {
      $logger->warn(
        "Repository '$repository' with arch '$arch' not found in result."
      );
    }

    # Now verify the build state of each target package.
    my $all_built_successfully = 1;
    my $has_terminal_failure   = 0;
    my @terminal_fail_packages;
    my @pending_packages;

    if (@target_packages) {
      foreach my $pkg_status (@target_packages) {
        my $pname = $pkg_status->{package};
        my $code  = $pkg_status->{code} || 'unknown';

        $logger->debug("  Package '$pname' status: $code");

        if ($code eq 'succeeded') {
          # This package completed building successfully.
          next;
        } elsif ($code =~ /^(failed|broken|unresolvable)$/) {
          # These indicate hard build errors on OBS. We abort early
          # rather than waiting for a hopeless timeout.
          $all_built_successfully = 0;
          $has_terminal_failure   = 1;
          push @terminal_fail_packages, "$pname ($code)";
        } else {
          # Any other state (building, scheduled, blocked, queued)
          # means we must keep waiting.
          $all_built_successfully = 0;
          push @pending_packages, "$pname ($code)";
        }
      }
    } else {
      # If no matching packages found in status list yet (e.g. initial setup)
      $logger->debug("  No build status found yet for package '$package'.");
      $all_built_successfully = 0;
      push @pending_packages, "$package (not_scheduled_yet)";
    }

    # If any package has failed terminal build, raise an error immediately.
    if ($has_terminal_failure) {
      croak(
        "WaitForPackage: Build failed for: " .
        join(', ', @terminal_fail_packages)
      );
    }

    # Verify if everything has finished building and the repository
    # publication status is completed.
    my $is_published = 0;
    if ($all_built_successfully) {
      my $p_code  = $prj->code // '';
      my $p_dirty = $prj->dirty // 0;

      $logger->debug(
        "  All builds succeeded. Project state: '$p_code' (dirty: $p_dirty)"
      );

      if ($p_code eq 'published' && !$p_dirty) {
        $is_published = 1;
      }
    }

    # Exit condition: successfully built AND published!
    if ($all_built_successfully && $is_published) {
      my $msg = "Package '$package' and all subpackages built and published.";
      $logger->debug("WaitForPackage: $msg");
      return {
        code    => 0,
        state   => 'succeed',
        message => $msg,
      };
    }

    # Check timeout condition
    if ($timeout > 0 && $elapsed >= $timeout) {
      my $pending_list = join(', ', @pending_packages);
      croak(
        "WaitForPackage: Timeout ($timeout sec) exceeded waiting for " .
        "package '$package'. Pending: $pending_list"
      );
    }

    # Informative sleep line
    my $time_left = $timeout > 0
      ? ($timeout - $elapsed) . "s remaining"
      : "infinite";

    $logger->debug(
      "Waiting for success/publication... " .
      "Sleeping $poll_interval sec. ($time_left)"
    );

    sleep $poll_interval;
  }
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Kanku::Handler::WaitForPackage

=head1 SYNOPSIS

Configuration example in your KankuFile:

  -
    use_module: Kanku::Handler::WaitForPackage
    options:
      obsurl: https://api.opensuse.org/public
      project: devel:kanku:images
      package: openSUSE-Leap-15.6-JeOS
      repository: images_leap_15_6
      timeout: 3600
      poll_interval: 30

=head1 DESCRIPTION

This handler queries the Open Build Service (OBS) API for the status of a
given package and its subpackages (flavors) for a repository and arch.
It polls until all builds succeeded and the repository is published.

=head1 OPTIONS

  obsurl        : OBS API URL (defaults to Kanku config obsurl)
  project       : OBS project name
  package       : Source package name
  repository    : OBS repository name
  arch          : Architecture (defaults to Kanku config arch)
  timeout       : Seconds to wait before timing out
                  (0 for infinite, default 3600)
  poll_interval : Seconds to sleep between polls (default 30)
  use_oscrc     : Use local oscrc config for authentication (default 1)

=head1 DEFAULTS

  timeout       : 3600
  poll_interval : 30
  use_oscrc     : 1

=cut
