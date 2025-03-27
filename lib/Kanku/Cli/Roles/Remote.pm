# Copyright (c) 2016 SUSE LLC
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
package Kanku::Cli::Roles::Remote;

use strict;
use warnings;

use MooseX::App::Role;

use LWP::UserAgent;
use JSON::XS;
use HTTP::Cookies;
use HTTP::Request;
use Carp;
use URI;

use Kanku::YAML;
use Kanku::TypeConstraints;
use Kanku::Config::Defaults;

option 'apiurl' => (
  isa           => 'URL',
  is            => 'rw',
  cmd_aliases   => 'a',
  documentation => 'Url to your kanku remote instance',
  required      => 1,
);

option 'user' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'u',
  documentation => 'Login user to to connect to your kanku remote instance',
  required      => 1,
);

option 'password' => (
  isa           => 'Password',
  is            => 'rw',
  cmd_aliases   => 'p',
  documentation => 'Login password to connect to your kanku remote instance',
  required      => 1,
);

option 'keyring' => (
  isa           => 'KeyringBackend',
  is            => 'rw',
  cmd_aliases   => 'k',
  documentation => 'Name of keyring backend (KDEWallet/Gnome/Memory)',
  required      => 1,
);

option 'as_admin' => (
  isa           => 'Bool',
  is            => 'rw',
  cmd_aliases   => 'aa',
  documentation => 'execute remote command as admin',
);

has cookie_jar => (
  is        =>'rw',
  isa       =>'Object',
  #required  => 1,
  lazy      => 1,
  default   => sub {
    return HTTP::Cookies->new(
      file            => $_[0]->_cookie_jar_file,
      autosave        => 1,
      ignore_discard  => 1,
    );
  },
);

has _cookie_jar_file => (
  is        =>'rw',
  isa       =>'Str',
  lazy      => 1,
  required  => 1,
  default   => "$::ENV{'HOME'}/.kanku_cookiejar",
);

has login_url => (
  is        => 'rw',
  isa       => 'Str',
  lazy	    => 1,
  builder   => '_build_login_url',
);
sub _build_login_url {
  my ($self) = @_;
  my $au = $self->apiurl; 
  $au =~ s/\/$//; 
  return "$au/rest/login.json"
}

has logout_url => (
  is        => 'rw',
  isa       => 'Str',
  lazy	    => 1,
  builder   => '_build_logout_url',
);
sub _build_logout_url {
  my ($self) = @_;
  my $au = $self->apiurl;
  $au =~ s/\/$//;
  return "$au/rest/logout.json"
}

has ua => (
  is        => 'rw',
  isa       => 'Object',
  builder   => '',
  lazy      => 1,
  builder   => '_build_ua',
);
sub _build_ua {
  return LWP::UserAgent->new(
    cookie_jar => $_[0]->cookie_jar,
    ssl_opts => {
      verify_hostname => 0,
      SSL_verify_mode => 0x00
    },
  );
}


sub connect_restapi {
  my ($self) = @_;
  return $self;
}

sub login {
  my $self     = shift;
  my $data     = { username=>$self->user,password=>$self->password };
  my $content  = encode_json($data);
  my $response = $self->ua->post( $self->login_url, Content => $content);


  if ($response->is_success) {
    my $result = decode_json($response->decoded_content);
    if ( $result->{authenticated} ) {
      $self->cookie_jar->extract_cookies($response);
      $self->cookie_jar->save($self->_cookie_jar_file);
      return 1;
    } else {
      return 0;
    }
  } else {
     $self->logger->debug('login_url: '.$self->login_url);
     croak($response->status_line);
  }

}

sub logout {
  my $self = shift;

  $self->ua->cookie_jar->load();

  if ( ! $self->session_valid ) {
    $self->logger->warn('No valid session found');
    $self->logger->warn('Could not proceed with logout');

    return 1;
  }

  my $request = HTTP::Request->new(POST => $self->logout_url);
  $self->cookie_jar->add_cookie_header( $request );

  my $response = $self->ua->request($request);

  if ($response->is_success) {
    unlink $self->_cookie_jar_file ||
      croak('Could not remove '.$self->_cookie_jar_file.": $!");
  } else {
     croak($response->status_line);
  }
  return;
}

sub session_valid {
  my $self = shift;
  return 0 if ( ! -f $self->_cookie_jar_file );

  $self->ua->cookie_jar->load();

  my $request = HTTP::Request->new(POST => $self->login_url);
  $self->cookie_jar->add_cookie_header( $request );

  my $response = $self->ua->simple_request($request);

  if ($response->is_success) {
    my $result = decode_json($response->decoded_content);
    return $result->{authenticated};
  } else {
     croak($response->status_line);
  }

}

sub get_json {
  my ($self, %opts) = @_;

  croak("No path given!\n") if ( ! $opts{path} );

  return 0 if ( ! -f $self->_cookie_jar_file );

  $self->ua->cookie_jar->load();

  my @param_arr;

  while (my ($p,$v) = each %{$opts{params}}) {
    if ((ref $v) eq "ARRAY") {
      push @param_arr, "$p=$_" for @{$v};
    } else {
      push @param_arr, "$p=$v";
    }
  }

  my $param_string = join q{&}, @param_arr;
  my $au  = $self->apiurl;
  $au =~ s/\/$//;
  my $url = "$au/rest/$opts{path}.json" . ( ($param_string) ? "?$param_string" : q{} ) ;
  $self->logger->debug("GET Request: '$url'");
  my $request = HTTP::Request->new(GET => $url);

  $self->cookie_jar->add_cookie_header( $request );

  my $response = $self->ua->simple_request($request);

  if ( $response->code == 302 ) {
      if ( ! $self->login() ) {
	croak("Failed to login\n");
      }

      $response = $self->ua->simple_request($request);
  }

  if ($response->is_success) {
    my $result;
    $self->logger->trace('decoded_content: '.$response->decoded_content);
    $result = decode_json($response->decoded_content);
    return $result;
  } else {
     $self->logger->debug("url: $url");
     croak($response->status_line ."\n");
  }
  return;
}

sub post_json {
  my ($self,%opts) = @_;

  croak("No path given!\n") if ( ! $opts{path} );
  croak("No data given!\n") if ( ! $opts{data} );

  return 0 if ( ! -f $self->_cookie_jar_file );
  $self->ua->cookie_jar->load();

  my @param_arr;

  while (my ($p,$v) = each %{$opts{params}}) {
    push  @param_arr, "$p=$v";
  }

  my $au      = $self->apiurl;
  $au         =~ s/\/$//;
  my $pstr    = join q{&}, @param_arr;
  my $url     = "$au/rest/$opts{path}.json".(($pstr) ? "?$pstr" : q{});
  my $data;
  my $ct;

  if (ref $opts{data}) {
    $data = encode_json($opts{data});
    $ct   = 'application/json';
  } else {
    $data = $opts{data};
    $ct   = 'application/x-www-form-urlencoded';
  }

  my $request = HTTP::Request->new(
    POST => $url,
    [
      'Content-Type'     => $ct,
    ],
    $data
  );

  $self->cookie_jar->add_cookie_header($request);

  my $response = $self->ua->simple_request($request);

  if ( $response->code == 302 ) {
      if ( ! $self->login() ) {
	die "Failed to login\n";
      }
      $response = $self->ua->simple_request($request);
  }
  if ($response->is_success) {
    my $result = decode_json($response->decoded_content);
    return $result;
  } else {
     $self->logger->debug("url: $url");
     die $response->status_line ."\n";
  }
}

sub put_json {
  my ($self, %opts) = @_;

  croak("No path given!\n") if ( ! $opts{path} );
  croak("No data given!\n") if ( ! $opts{data} );

  return 0 if ( ! -f $self->_cookie_jar_file );

  $self->ua->cookie_jar->load();

  my @param_arr;

  while (my ($p,$v) = each %{$opts{params}}) {
    push @param_arr, "$p=$v";
  }

  my $au      = $self->apiurl;
  $au         =~ s/\/$//;
  my $pstr    = join q{&}, @param_arr;
  my $url     = "$au/rest/$opts{path}.json".(($pstr) ? "?$pstr" : q{});
  my $data;
  my $ct;

  if (ref $opts{data}) {
    $data = encode_json($opts{data});
    $ct   = 'application/json';
  } else {
    $data = $opts{data};
    $ct   = 'application/x-www-form-urlencoded';
  }

  my $request = HTTP::Request->new(
    PUT => $url,
    [
      'Content-Type'     => $ct,
    ],
    $data
  );

  $self->cookie_jar->add_cookie_header($request);

  my $response = $self->ua->simple_request($request);

  if ( $response->code == 302 ) {
      if ( ! $self->login() ) {
	croak("Failed to login\n");
      }
      $response = $self->ua->simple_request($request);
  }
  if ($response->is_success) {
    my $result = decode_json($response->decoded_content);
    return $result;
  } else {
     $self->logger->debug("url: $url");
     croak($response->status_line ."\n");
  }
  return;
}

sub delete_json {
  my ($self, %opts) = @_;

  croak("No path given!\n") if (! $opts{path});

  return 0 if ( ! -f $self->_cookie_jar_file );

  $self->ua->cookie_jar->load();

  my @param_arr;

  while (my ($p,$v) = each %{$opts{params}}) {
    push @param_arr, "$p=$v";
  }

  my $au      = $self->apiurl;
  $au         =~ s/\/$//;
  my $pstr    = join q{&}, @param_arr;
  my $url     = "$au/rest/$opts{path}.json".(($pstr) ? "?$pstr" : q{});
  my $data;
  my $ct;

  if (ref $opts{data}) {
    $data = encode_json($opts{data});
    $ct   = 'application/json';
  } else {
    $data = $opts{data};
    $ct   = 'application/x-www-form-urlencoded';
  }

  my $request = HTTP::Request->new(
    DELETE => $url,
    [
      'Content-Type'     => $ct,
    ],
    $data
  );

  $self->cookie_jar->add_cookie_header($request);

  my $response = $self->ua->simple_request($request);

  if ( $response->code == 302 ) {
      if (! $self->login) {
	croak("Failed to login\n");
      }
      $response = $self->ua->simple_request($request);
  }
  if ($response->is_success) {
    my $result = decode_json($response->decoded_content);
    return $result;
  } else {
     $self->logger->debug("url: $url");
     croak($response->status_line ."\n");
  }
}

1;
