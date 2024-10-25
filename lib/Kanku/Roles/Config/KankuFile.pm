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
package Kanku::Roles::Config::KankuFile;

use Moose::Role;

use Kanku::File;

has 'views_dir' => (
  is      =>'rw',
  isa     =>'Str',
  default => '/usr/share/kanku/views',
);

sub file;
has 'file' => (
  is      =>'rw',
  isa     =>'Str',
  builder => '_build_file',
);
sub _build_file {
  my ($self, $file)  = @_;
  my $f = Kanku::File->lookup_file(
    $file
      || $::ENV{KANKU_CONFIG}
      || "KankuFile"
  ); 
  return "$f";
};

sub job_config {
  my ($self, $job_name) = @_;

  return {
    tasks => $self->config->{jobs}->{$job_name}
  };
}

sub notifiers_config {
  my ($self, $job_name) = @_;
  my $nc = $self->config->{notifiers};
  return (ref($nc->{$job_name}) eq 'ARRAY') ? $nc->{$job_name} : [];
}

sub job_list {
  my ($self) = @_;
  return (keys %{$self->config->{jobs}});
}

with 'Kanku::Roles::Config::Base';

1;
