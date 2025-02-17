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
package Kanku::Cli::Hub::Test;

use MooseX::App::Command;
extends qw(Kanku::Cli);

use YAML::PP;
use Test::More;
use File::Find;
use Data::Dumper;
use Path::Tiny;
use Kanku::Util;
use Kanku::Config::Defaults;

with 'Kanku::Cli::Roles::Hub';

command_short_description  'Test Kankufile\'s in kanku-hub';

command_long_description '
This command tests all KankuFile\'s found in the current directory 
and subdirectories.
';

option 'dir' => (
  is      => 'rw',
  isa     => 'Str',
  lazy    => 1,
  default => q{.},
);

has 'dirs2test' => (
  is      => 'rw',
  isa     => 'HashRef',
  lazy    => 1,
  default => sub { {} },
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

  $self->prepare_gnupghome;
  $self->prepare_tc_list;

  plan tests => $self->no_of_tests;

  my $logdir = path($self->dir, '.log');
  if ($logdir->exists) {
    $_->remove for $logdir->children;
  } else{
    $logdir->mkdir;
  }


  my $cwd    = path($self->dir)->realpath;
  for my $d (sort keys(%{$self->dirs2test})) {
    my $tests = $self->dirs2test->{$d};
    my $du = $d;
    $du =~ s#^$cwd/(.*)#$1#;
    my $m = "Checking $du '%s'";
    $du =~ s#/#_#g;
    my $l = path($logdir->realpath, "/$du.log");
    chdir path($d)->realpath;
    for my $tc (@{$tests}) {
      my $cmd = 'kanku ' . join(' ', @{$tc});
      `$cmd --ll TRACE >> $l 2>&1`;
      system("cat", $l) if $::ENV{TEST_VERBOSE};
      ok($? == 0, sprintf($m, $cmd));
    }
    chdir $cwd;
  }
}

sub prepare_gnupghome {
  my ($self) = @_;
  my $dir    = $self->dir;

  $::ENV{GNUPGHOME} = $self->tmpdir->stringify;

  my @gpgimport = `gpg --import $dir/_maintainers/*.asc 2>&1`;
}

sub prepare_tc_list {
  my ($self)    = @_;
  my $logger    = $self->logger;
  my $dirs2test = $self->dirs2test;
  my $arch      = Kanku::Util->get_arch;

  for my $f (@{$self->kankufiles}) {
    my $kf        = path($f);
    my $dir       = $kf->parent;
    my $cicd_yml  = path($dir, '.kanku', 'cicd.yml');
    my $arch_yml  = path($dir, '.kanku', 'arch.yml');
    my @tests     = (['verify'], ['info'], ['destroy']);
    my $deftc     = 1;

    if ($arch_yml->is_file) {
      my $ypp = YAML::PP->new;
      my $yml = $ypp->load_file($arch_yml);
      my @match = grep { $_ eq $arch } @{$yml};
      next unless @match;
    }

    if ($cicd_yml->is_file) {
      my $ypp = YAML::PP->new;
      my $yml = $ypp->load_file($cicd_yml);
      if (@{$yml->{tests}->{order}||[]} > 0) {
	for my $t (@{$yml->{tests}->{order}}) {
	  my @type = grep { $t->{type} eq $_ } qw/jobs job_groups/;
	  croak("Unkown type: '$t->{type}'") unless (@type);
	  if ($type[0] eq 'jobs') {
	    for my $tt (@{$t->{$type[0]}}) {
	      push @tests, ['up', '-j', $tt], ['destroy'];
	    }
	  }
	  if ($type[0] eq 'job_groups') {
	    for my $tt (@{$t->{$type[0]}}) {
	      push @tests, ['up', '--jg', $tt];
	    }
	  }
	}
	$deftc = 0;
      }
    }

    push @tests, ['up'], ['destroy'] if $deftc;
    $dirs2test->{$dir->stringify} = \@tests;
    $self->no_of_tests($self->no_of_tests + scalar @tests);
  }
}
__PACKAGE__->meta->make_immutable;

1;
