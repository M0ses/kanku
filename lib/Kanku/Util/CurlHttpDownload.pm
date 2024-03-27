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
use File::Temp qw/ :mktemp /;
use File::Copy;
use Path::Class::File;
use Path::Class::Dir;
use Net::OBS::LWP::UserAgent;
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

  my $res;

  if ( $self->offline ) {
    $self->logger->warn("Skipping download from $url in offline mode");
  } else {
      $self->logger->info("Downloading $url");
      $self->logger->debug("  to file ".$file->stringify);

      my $cfg      = Kanku::Config->instance();
      my $neo_ua   = Net::OBS::LWP::UserAgent->new();
      #my $out_file = file($cfg->cache_dir, $self->_calc_output_file(0))->stringify;
      $self->_set_credentials($neo_ua, $url);

      my $ua    = Net::OBS::LWP::UserAgent->new();

      my $res = $neo_ua->mirror(
        url  => $self->url,
        etag => $self->etag,
        file => $file->stringify,
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

sub _set_credentials {
  my ($self, $c, $url) = @_;
  my $uri        = URI->new($url);

  my $creds = Kanku::Config::Defaults->get('Net::OBS::Client','credentials');
  for my $cred (keys %{$creds}) {
    $self->logger->debug("cred: $cred / url: ".$self->url);
    if ($self->url =~ /^$cred/) {
      if ($creds->{$cred}->{sigauth_credentials}) {
        $c->sigauth_credentials($creds->{$cred}->{sigauth_credentials});
      } elsif ($creds->{$cred}->{basic_credentials}) {
        $c->basic_credentials($creds->{$cred}->{basic_credentials});
      }
    }
    return;
  }
  return;
}


__PACKAGE__->meta->make_immutable;

1;
