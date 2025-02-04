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
