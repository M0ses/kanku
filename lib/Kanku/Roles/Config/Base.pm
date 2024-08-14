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
use Carp qw/longmess cluck/;
use File::Basename;
use File::HomeDir;
use File::stat;
use Kanku::YAML;

with 'Kanku::Roles::Logger';

requires "file";
requires "job_config";

has config => (
  is      => 'rw',
  isa     => 'HashRef',
  lazy    => 1,
  builder => '_build_config',
);
sub _build_config {
  my ($self) = @_;
  return Kanku::YAML::LoadFile($self->file);
}

has cf => (
  is      => 'rw',
  isa     => 'HashRef',
  lazy    => 1,
  builder => '_build_cf',
);
sub _build_cf {
  my ($self) = @_;
  my $home  = File::HomeDir->my_home;
  my @search_path = (
    "$home/.config/kanku/",
    "$home/.kanku/",
    '/etc/kanku/',
  );
  for my $sp (@search_path) {
    my $f = File::Spec->canonpath($sp.'/kanku-config.yml');
    if (-f $f) {
      $self->logger->debug("Found Config file `$f`!");
      return Kanku::YAML::LoadFile($f);
    }
    $self->logger->debug("Config file '$f' not found!");
  }
  $self->logger->warn("No config file found! Using empty configuration.");
  return {};
}

has last_modified => (
  is        => 'rw',
  isa       => "Int",
  default   => 0
);

sub job_list {
  my ($self) = @_;
  return (map { basename($_) =~ m/^(.*)\.yml$/; $1; } glob('/etc/kanku/jobs/*.yml'));
}

sub job_group_list {
  my ($self) = @_;
  return (map { basename($_) =~ m/^(.*)\.yml$/; $1; } glob('/etc/kanku/job_groups/*.yml'));
}

1;
