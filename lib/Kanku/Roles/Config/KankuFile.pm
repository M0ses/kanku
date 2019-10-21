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
use Path::Class::File;
use Path::Class::Dir;
use Data::Dumper;
use Cwd;

with 'Kanku::Roles::Config::Base';

has 'log_dir' => (is=>'rw',isa=>'Object',default=>sub {Path::Class::Dir->new(getcwd(),'.kanku','log')});

has '_file'   => (is=>'rw',isa=>'Object', default => sub { Path::Class::File->new(getcwd(),'KankuFile') });

sub file {
  my ($self, $file)  = @_;
  if ($file) {
    $self->_file(Path::Class::File->new($file));
  } elsif ($ENV{KANKU_CONFIG}) {
    $self->_file(Path::Class::File->new($ENV{KANKU_CONFIG}));
  }

  return $self->_file;
};

sub job_config {
  my $self      = shift;
  my $job_name  = shift;

  return $self->config->{jobs}->{$job_name};
}

sub notifiers_config {
	# no notifiers in KankuFile
	return []
}

sub job_list {
  return keys(%{$_[0]->config->{jobs}});
}

1;
