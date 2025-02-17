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
package Kanku::Cli::Hub::Sign;

use MooseX::App::Command;
extends qw(Kanku::Cli);

use Test::More;
use Kanku::Config::Defaults;

with 'Kanku::Cli::Roles::Hub';

command_short_description  'Sign Kankufile\'s in kanku-hub';

command_long_description '
This command signs all KankuFile\'s found in the current directory 
and subdirectories.
';

option 'dir' => (
  is      => 'rw',
  isa     => 'Str',
  default => q{.},
);

option 'dryrun' => (
  is      => 'rw',
  isa     => 'Bool',
  default => 0,
);

option 'force' => (
  is            => 'rw',
  isa           => 'Bool',
  documentation => 'force overwrite of existing signatures',
  cmd_aliases   => [qw/f/],
  lazy          => 1,
  default       => 0,
);

has 'tmpdir' => (
  is      => 'rw',
  isa     => 'Object',
  lazy    => 1,
  default => sub { Path::Tiny->tempdir },
);

sub run {
  my ($self)  = @_;
  my $logger  = $self->logger;
  my $kfl = $self->kankufiles;
  plan tests => scalar(@$kfl);
  for my $kf (@{$kfl}) {
    my $asc = "$kf.asc";
    my @out = `gpg --verify $asc 2>&1`;
    my $rc = $?;
    ok($rc == 0, "Checking $kf");
    if ($rc && !$self->dryrun) {
      if (-f $asc && $self->force) {
	$logger->debug("Removing $asc");
        unlink $asc || croak("Error while unlinking file `$asc`: $!");
      }
      my @out = `GNUPGHOME= gpg -b -a $kf`;
    }
  }
}

__PACKAGE__->meta->make_immutable;

1;
