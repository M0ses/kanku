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
package Kanku::Util::CurlHttpDownload;

use Moose;
use Data::Dumper;
use HTTP::Request;
use Template;
use Kanku::Util::HTTPMirror;
use File::Temp qw/ :mktemp /;
use File::Copy;
use Path::Class::File;
use Path::Class::Dir;
use Kanku::Config;
with 'Kanku::Roles::Logger';

has output_dir => (
  is        => 'rw',
  isa       => 'Str',
);

has output_file => (
  is        => 'rw',
  isa       => 'Str',
);

has url => (
  is        =>'rw',
  isa       =>'Str',
  required  => 1
);

has [ qw/offline use_temp_file/ ] => (
  is        =>'rw',
  isa       =>'Bool',
  default   => 0
);

has cache_dir => (
  is        =>'rw',
  isa       =>'Str',
  lazy      => 1,
  default   => sub { return Kanku::Config->instance->config()->cache_dir; },
);

has [qw/username password/] => (
  is        => 'rw',
  isa       => 'Str',
);

has [qw/etag/] => (
  is        => 'rw',
  isa       => 'Str|Undef',
  default   => q{},
);

sub download {
  my $self  = shift;
  my $url   = $self->url;


  my $file  = undef;

  if ( $self->output_file ) {
    if ( $self->output_dir ) {
      $self->logger->warn('ATTENTION: You have set output_dir _and_ output_file - output_file will be preferred');
    }
    $file = Path::Class::File->new($self->cache_dir,$self->output_file);
  }
  elsif ( $self->output_dir )
  {
    # combine filename from url with output_dir
    my $od = $self->output_dir;
    die "output_dir is not an absolute path" if ( $od !~ /^\// );
    my @parts = split(/\//,$url);
    my $fn    = pop @parts;
    my @od_parts = split(/\//,$od);
    $file     = Path::Class::File->new('/',@od_parts,$fn);
  }
  else
  {
    die "Neither output_dir nor output_file given";
  }

  $| = 1;  # autoflush

  if ( $self->use_temp_file ) {
      $file = Path::Class::File->new(mktemp($file->stringify."-XXXXXXXX"));
  };

  ( -d $file->parent ) || $file->parent->mkpath;

  my $res;

  if ( $self->offline ) {
    $self->logger->warn("Skipping download from $url in offline mode");
  } else {
      $self->logger->info("Downloading $url");
      $self->logger->debug("  to file ".$file->stringify);

      my $ua    = Kanku::Util::HTTPMirror->new();

      my %request;

      my $uri       = URI->new($url);
      my $authority = $uri->authority;

      # user/pass will be removed from uri automatically by LWP::UserAgent
      my @auth = split(/\@/, $authority, 2);
      if ($auth[1]) {
        my ($user, $pass) = split(/:/, $auth[0], 2);
        my $new_user      = ($self->username || $user);
        my $new_pass      = ($self->password || $pass);
        my $new_authority = $new_user;
        $new_authority .= ":$new_pass" if ($new_authority && $new_pass);
        $new_authority .= $auth[1];
        $uri->authority($new_authority);
      }

      # Add ETag to request header
      my $header = [];
      push @$header, ('If-None-Match', $self->etag) if ($self->etag);

      $self->logger->debug("final URI: ".$uri->canonical);

      my $req = HTTP::Request->new(GET => $uri, $header);

      $res = $ua->mirror(
        url  => $uri->canonical,
        file => $file->stringify,
        etag => $self->etag,
        %request,
      );

      if ( $res->code == 200 ) {
        $self->logger->debug("  download succeed");
      } elsif ( $res->code == 304 ) {
        $self->logger->debug("  skipped download because file not modified");
      } else {
        die "Download failed from $url: '".$res->code."'\n";
      }
  }

  return ($file->stringify, $res->header('ETag'));
}

__PACKAGE__->meta->make_immutable;

1;
