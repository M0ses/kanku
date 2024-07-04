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
use File::Spec;
use Cwd;

with 'Kanku::Roles::Config::Base';

has 'views_dir' => (
  is      =>'rw',
  isa     =>'Str',
  default => '/usr/share/kanku/views',
);

has 'log_dir' => (
  is=>'rw',
  isa=>'Str',
  builder => '_build_log_dir',
);
sub _build_log_dir {
  return File::Spec->canonpath(getcwd(),'.kanku','log');
}

has '_file' => (
  is      =>'rw',
  isa     =>'Str',
  builder => '_build__file',
);
sub _build__file {
  my ($self)  = @_;

  # FIXME:
  # change `KankuFile` to something like $self->kankufile
  #
  return File::Spec->canonpath(getcwd(), 'KankuFile');
}

sub file {
  my ($self, $file)  = @_;
  my $f = File::Spec->canonpath(
    $file
    || $ENV{KANKU_CONFIG}
    || getcwd()."/KankuFile"
  );
  $self->_file($f) if $f;
  return $self->_file;
};

sub job_config {
  my ($self, $job_name) = @_;

  return {
    tasks => $self->config->{jobs}->{$job_name}
  };
}

sub notifiers_config {
	# no notifiers in KankuFile
	return []
}

sub job_list {
  my ($self) = @_;
  return (keys %{$self->config->{jobs}});
}

1;
