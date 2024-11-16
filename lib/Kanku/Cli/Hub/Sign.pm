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

use YAML::PP;
use Test::More;
use File::Find;
use Data::Dumper;
use Path::Tiny;
use Kanku::Util;
use Kanku::Config::Defaults;

command_short_description  'Test Kankufile\'s in kanku-hub';

command_long_description '
This command tests all KankuFile\'s found in the current directory 
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

has 'kankufiles' => (
  is      => 'rw',
  isa     => 'ArrayRef',
  lazy    => 1,
  builder => 'find_kankufiles',
);

has 'tmpdir' => (
  is      => 'rw',
  isa     => 'Object',
  lazy    => 1,
  default => sub { Path::Tiny->tempdir },
);

has 'no_of_tests' => (
  is      => 'rw',
  isa     => 'Int',
  default => 0,
);

sub run {
  my ($self)  = @_;
  my $logger  = $self->logger;
  #my $config  = Kanku::Config::Defaults->get('Kanku::Cli::Hub::Test');
  $self->prepare_gnupghome;
  my $kfl = $self->kankufiles;
  plan tests => scalar(@$kfl);
  for my $kf (@{$kfl}) {
    my @out = `gpg --verify $kf.asc 2>&1`;
    my $rc = $?;
    ok($rc == 0, "Checking $kf");
    if ($rc && !$self->dryrun) {
      my @out = `GNUPGHOME= gpg -b -a $kf`; 
    }
  }
}

sub prepare_gnupghome {
  my ($self) = @_;
  my $dir    = $self->dir;

  $::ENV{GNUPGHOME} = $self->tmpdir->stringify;

  my @gpgimport = `gpg --import $dir/_maintainers/*.asc 2>&1`;
}

sub find_kankufiles {
  my ($self)  = @_;
  my $logger  = $self->logger;
  my $excl    = Kanku::Config::Defaults->get(
    'Kanku::Cli::Hub::Sign', 
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

__PACKAGE__->meta->make_immutable;

1;

__END__
#!/usr/bin/bash
BD=$(dirname $0)/
FL=$(find -name KankuFile|sort)
case $1 in 
  check)
    for kf in $FL;do
      P=`dirname $kf`
      F=`basename $kf`
      T=$(echo $P|perl -p -e "s#$BD##"|perl -p -e 's#/#.#g')
      cd $P
      gpg --verify $F.asc >> /dev/null 2>&1 \
	&& echo "ok - $T" \
	|| echo "not ok - $T"
      cd - 1>/dev/null
    done
  ;;
  sign)
    for kf in $FL;do
      P=`dirname $kf`
      F=`basename $kf`
      cd $P
      gpg --verify $F.asc >> /dev/null 2>&1 \
	&& echo "ok - $P" \
	|| {
	  echo "not ok - $P";
          rm -f $F.asc
	  gpg -b -a $F
        }
      cd - 1>/dev/null
    done
  ;;
  *)
    echo "Usage: "`basename $0`" <check|sign>"
    exit 1
  ;;
esac
