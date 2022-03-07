# Copyright (c) 2021 SUSE LLC
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
package Kanku::Roles::Config::Base;

use Moose::Role;
use Path::Class::File;
use Data::Dumper;
use Kanku::YAML;
use Path::Class qw/dir/;

with 'Kanku::Roles::Logger';

requires "file";
requires "job_config";

has config => (
  is      => 'rw',
  isa     => 'HashRef',
);

has cf => (
  is      => 'rw',
  isa     => 'HashRef',
  lazy    => 1,
  default => sub {
    my ($self) = @_;
    my $home  = File::HomeDir->my_home;
    my @files = ("$home/.kanku/kanku-config.yml", '/etc/kanku/kanku-config.yml');
    for my $f (@files) {
      if (-f $f) {
        $self->logger->debug("Found Config file '$f'!");
        return Kanku::YAML::LoadFile($f);
      }
      $self->logger->debug("Config file '$f' not found!");
    }
    $self->logger->debug("No config file found! Using empty configuration.");
    return {};
  }
);

has last_modified => (
  is        => 'rw',
  isa       => "Int",
  default   => 0
);

has log_dir => (
  is      => 'rw',
  isa     => 'Object',
  lazy    => 1,
  default => sub {
    return Path::Class::Dir->new('/var/log/kanku');
  }
);

sub _build_config { return Kanku::YAML::LoadFile($_[0]->file) }

around 'config' => sub {
  my ($orig, $self) = @_;
  my $cfg_file      = $self->file->stringify;

  die "Configuration file $cfg_file doesn`t exists\n" unless -f $cfg_file;

  my $mtime = $self->file->stat->mtime;
  my $ltime = $self->last_modified;

  if ($mtime != $ltime) {
    if ($ltime) {
      $self->logger->debug("Modification of config file detected. Re-reading ($mtime/$ltime)");
    } else {
      $self->logger->debug("Initial read of config file '$cfg_file'");
    }
    $self->last_modified($self->file->stat->mtime);
    return $self->$orig( $self->_build_config() );
  }

  return $self->$orig();
};

sub job_list {
  my $self  = shift;
  my @files = dir('/etc/kanku/jobs')->children;
  my @result;
  for my $f (@files) {
    push(@result, $1) if ($f =~ /.*\/(.*)\.yml$/);
  }
  return @result;
}

sub job_group_list {
  my $self  = shift;
  my @files = dir('/etc/kanku/job_groups')->children;
  my @result;
  for my $f (@files) {
    push(@result, $1) if ($f =~ /.*\/(.*)\.yml$/);
  }
  return @result;
}

1;
