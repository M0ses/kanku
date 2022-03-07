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
package Kanku::Roles::Config;

use Moose::Role;
use Path::Class::File;
use Path::Class::Dir;
use Data::Dumper;
use Kanku::YAML;
use YAML::PP;
use YAML::PP::Schema::Include;
use Try::Tiny;
use File::HomeDir;

with 'Kanku::Roles::Config::Base';

sub file {
  my ($self) = @_;
  my $home  = File::HomeDir->my_home;
  my @files = ("$home/.kanku/kanku-config.yml", '/etc/kanku/kanku-config.yml');
  for my $f (@files) {
    if (-f $f) {
      $self->logger->trace("Found Config file: $f");
      return Path::Class::File->new($f);
    }
    $self->logger->trace("Config file: $f not found");
  }
}

has config => (
  is      => 'rw',
  isa     => 'HashRef',
);

has last_modified => (
  is        => 'rw',
  isa       => "Int",
  default   => 0,
);

has views_dir => (
  is        => 'rw',
  isa       => "Str",
  default   => '/usr/share/kanku/views',
);

has cache_dir => (
  is        =>'rw',
  isa       =>'Str',
  lazy      => 1,
  default   => sub {
    return $_[0]->config()->{cache_dir};
  }
);

sub job_config {
  my ($self, $job_name) = @_;
  my ($cfg, $yml);
  $yml = $self->job_config_plain($job_name);
  $cfg = $self->load_job_config($job_name);

  if (ref($cfg) eq 'ARRAY') {
    return {tasks=>$cfg,arch=>'x64_64'};
  } elsif (ref($cfg) eq 'HASH') {
    return $cfg if (ref($cfg->{tasks}) eq 'ARRAY');
  }

  die "No valid job configuration found\n";
}

sub load_job_config {
  my ($self, $job_name, $yml) = @_;
  try {
    my $include = YAML::PP::Schema::Include->new;
    my $yp = YAML::PP->new( schema => [$include] );
    $include->yp($yp);
    if ($yml) {
      return $yp->load_string($yml);
    } else {
      return $yp->load_file("/etc/kanku/jobs/$job_name.yml");
    }
  } catch {
      die "Error while parsing job config yaml file for job '$job_name':\n$_";
  }
}

sub notifiers_config {
  my ($self,$job_name) = @_;
  my $cfg = $self->load_job_config($job_name);

  if (ref($cfg) eq 'HASH') {
    return $cfg->{notifiers} if (ref($cfg->{notifiers}) eq 'ARRAY');
  }

  # FALLBACK:
  # give back empty array ref if no config found
  return [];
}

sub job_config_plain {
  my $self      = shift;
  my $job_name  = shift;
  my $conf_file = Path::Class::File->new("/etc/kanku/jobs/$job_name.yml");
  my $content   = $conf_file->slurp();

  return $content;
}

sub job_group_config {
  my ($self, $name) = @_;
  my ($cfg, $yml);
  #$yml = $self->job_group_config_plain($name);
  $cfg = $self->load_job_group_config($name);

  if (ref($cfg) eq 'HASH') {
    return $cfg if (ref($cfg->{groups}) eq 'ARRAY');
  }

  die "No valid job configuration found\n";
}

sub load_job_group_config {
  my ($self, $name, $yml) = @_;
  try {
    my $include = YAML::PP::Schema::Include->new;
    my $yp = YAML::PP->new( schema => [$include] );
    $include->yp($yp);
    if ($yml) {
      return $yp->load_string($yml);
    } else {
      return $yp->load_file("/etc/kanku/job_groups/$name.yml");
    }
  } catch {
      die "Error while parsing job config yaml file for job '$name':\n$_";
  }
}

sub job_group_config_plain {
  my ($self, $name) = @_;
  my $conf_file = Path::Class::File->new("/etc/kanku/job_groups/$name.yml");
  my $content   = $conf_file->slurp();

  return $content;
}

1;
