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

package Kanku::Cli::Hub::Gpgimport;

use MooseX::App::Command;
extends qw(Kanku::Cli);

#use YAML::PP;
#use Test::More;
#use File::Find;
use Data::Dumper;
use Path::Tiny;
use Net::OBS::LWP::UserAgent;
use JSON::XS qw/decode_json/;
#use Kanku::Util;
#use Kanku::Config::Defaults;


command_short_description  'Import gpg keys of kanku-hub maintainers';

command_long_description '
This command imports gpg keys of kanku-hub maintainers into your gpg keyring.
';

option 'hub_url' => (
  is      => 'rw',
  isa     => 'Str',
  lazy    => 1,
  default => q{https://hub.kanku.info},
  cmd_aliases   =>[qw/hub-url H/],
);

option 'gnupghome' => (
  is      => 'rw',
  isa     => 'Str',
  lazy    => 1,
  default => q{},
  cmd_aliases   =>[qw/G/],
);

option 'interactive' => (
  is      => 'rw',
  isa     => 'Bool',
  lazy    => 1,
  default => 0,
  cmd_aliases   =>[qw/i/],
);


sub run {
  my ($self)  = @_;
  my $logger  = $self->logger;

  my $neo_ua   = Net::OBS::LWP::UserAgent->new();
  my $response = $neo_ua->get($self->hub_url.'/_kanku/hub.json');

  if (!$response->is_success) {
    $logger->error($response->status_line);
    return 1;
  }

  my $json = $response->decoded_content;
  my $data = decode_json($json);

  if ($self->gnupghome) {
    my $gnupghome = Path::Tiny->new($self->gnupghome);
    $::ENV{GNUPGHOME} = $self->gnupghome;
    if (!$gnupghome->exists) {
      $gnupghome->mkdir;
      $gnupghome->chmod(0700);
      `gpg -q -k`;
    }
  }

  for my $m (@{$data->{maintainers}}) {
    $logger->info("Importing gpg for maintainer: $m->{alias} <$m->{mail}>\n");
    $response = $neo_ua->get($self->hub_url."/_maintainers/$m->{alias}.asc");
    if (!$response->is_success) {
      $logger->error($response->status_line);
      next;
    }
    my $tmp = Path::Tiny->tempfile();
    $tmp->spew($response->decoded_content);
    `gpg --import $tmp`;
  }

  return 0;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

sub prepare_gnupghome {
  my ($self) = @_;
  my $dir    = $self->dir;

  $::ENV{GNUPGHOME} = $self->tmpdir->stringify;

  my @gpgimport = `gpg --import $dir/_maintainers/*.asc 2>&1`;
}

sub build_kankufiles {
  my ($self)  = @_;
  my @files;

  if (@{$self->extra_argv}) {
    for my $kf (@{$self->extra_argv}) {
      if (!path($kf)->is_file) {
        croak("KankuFile $kf not found or is not a regular file");
      }
      push @files, $kf;
    }
    return $self->kankufiles([sort @files]);
  }

  my $logger  = $self->logger;
  my $excl    = Kanku::Config::Defaults->get(
    'Kanku::Cli::Hub::Test', 
    'exclude_dirs',
  );
  my $dir     = $self->dir;

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
