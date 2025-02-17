# Copyright (c) 2024 SUSE LLC
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
package Kanku::Cli::Roles::Hub;


use Moose::Role;
use File::Find;
use Kanku::Config::Defaults;

has 'dir' => (
  is      => 'rw',
  isa     => 'Str',
  default => q{.},
);

has 'kankufiles' => (
  is      => 'rw',
  isa     => 'ArrayRef',
  lazy    => 1,
  builder => 'find_kankufiles',
);

sub find_kankufiles {
  my ($self)  = @_;
  my $logger  = $self->logger;
  my $excl    = Kanku::Config::Defaults->get(
    __PACKAGE__,
    'exclude_dirs',
  );

  my $dir     = $self->dir;
  my @files;

  find(
    sub {
      my $found;
      for my $d (@{$excl}) {
        $logger->debug("$d ::: $File::Find::dir");
	if ($File::Find::dir =~ /$d/) { $found = 1; }
      }
      return if $found;
      $_ =~ m/^KankuFile$/ && push @files, $File::Find::name;
    },
    $dir
  );

  return $self->kankufiles([sort @files]);
}

1;
