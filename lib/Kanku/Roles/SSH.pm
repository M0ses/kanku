# Copyright (c) 2017 SUSE LLC
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
package Kanku::Roles::SSH;

use Moose::Role;

use Carp;
use Path::Tiny;
use Data::Dumper;
use Libssh::Session q(:all);

use Kanku::Config::Defaults;

with 'Kanku::Roles::Logger';

requires 'timeout';

has 'passphrase' => (
  is	  => 'rw',
  isa	  => 'Str',
  default => ''
);

has 'privatekey_path' => (
  is	  => 'rw',
  isa	  => 'Str',
  lazy	  => 1,
  builder => '_build_privatekey_path',
);
sub _build_privatekey_path {
  return $_[0]->job->context->{privatekey_path}
    || Kanku::Config::Defaults->get('Kanku::Roles::SSH', 'privatekey_path');
}

has 'publickey_path' => (
  is	  => 'rw',
  isa	  => 'Str',
  lazy	  => 1,
  builder => '_build_publickey_path',
);
sub _build_publickey_path {
  return $_[0]->job->context->{publickey_path}
    || Kanku::Config::Defaults->get('Kanku::Roles::SSH', 'publickey_path');
}

has 'ipaddress' => (
  is	  => 'rw',
  isa	  => 'Str',
  lazy    => 1,
  builder => '_build_ipaddress',
);
sub _build_ipaddress { $_[0]->job->context->{ipaddress} || '' }

has 'username' => (
  is	  => 'rw',
  isa	  => 'Str',
  lazy    => 1,
  builder => '_build_username',
);
sub _build_username { 'root' }


has 'password' => (
  is	  => 'rw',
  isa	  => 'Str',
  lazy    => 1,
  builder => '_build_password',
);
sub _build_password { 'kankudai' }

has 'port' => (
  is	  => 'rw',
  isa	  => 'Int',
  lazy    => 1,
  builder => '_build_port',
);
sub _build_port { 22 }

has 'connect_timeout' => (
  is	  => 'rw',
  isa	  => 'Int',
  builder => '_build_connect_timeout',
);

sub _build_connect_timeout { 300 }

has [ qw/job ssh/ ] => (
  is => 'rw',
  isa => 'Object'
);

has auth_type => (
  is=>'rw',
  isa=>'Str',
  lazy => 1,
  builder => '_build_auth_type',
);
sub _build_auth_type {
  return Kanku::Config::Defaults->get('Kanku::Roles::SSH', 'auth_type');
}

has ENV => (
  is      =>'rw',
  isa     =>'HashRef',
  lazy    => 1,
  builder => '_build_ENV',
);

sub _build_ENV {{}}

has 'logverbosity' => (
  is      => 'rw',
  isa     => 'Int',
  lazy    => 1,
  builder => '_build_logverbosity',
);
sub _build_logverbosity {
  return Kanku::Config::Defaults->get('Kanku::Roles::SSH', 'logverbosity');
}


sub get_defaults {
  my ($self) = @_;
  my $logger = $self->logger;
  my $cfg    = Kanku::Config::Defaults->get('Kanku::Roles::SSH');

  if (! $self->privatekey_path ) {
    if ( $cfg->{privatekey_path} ) {
      $self->privatekey_path($cfg->{privatekey_path});
    } elsif ( $::ENV{HOME} ) {
      my $key_path = "$::ENV{HOME}/.ssh/id_rsa";
      $self->privatekey_path($key_path) if ( -f $key_path);
    }
  }

  $logger->debug(' - get_defaults: privatekey_path - '.$self->privatekey_path);

  $self->publickey_path($cfg->{publickey_path}) if $cfg->{publickey_path};

  if (! $self->publickey_path && $self->privatekey_path) {
    my $key_path = $self->privatekey_path.".pub";
    $self->publickey_path($key_path) if ( -f $key_path);
  }

  $logger->debug(' - get_defaults: publickey_path - '.$self->publickey_path);

  return 1;
}

sub connect {
  my ($self)  = @_;
  my $logger  = $self->logger;


  my $results = [];
  my $ip      = $self->ipaddress;
  my $port    = $self->port;
  my $timeout = $self->connect_timeout;

  my $cc      = 0; # Connection Counter

  $logger->info("Connecting to $ip (Timeout: $timeout)!");

  my $ssh;
  my $key_auth = ( $self->auth_type eq 'agent') ? 1 : 0;
  my $lv_str2const = {
    SSH_LOG_NOLOG     => SSH_LOG_NOLOG,
    SSH_LOG_WARNING   => SSH_LOG_WARNING,
    SSH_LOG_PROTOCOL  => SSH_LOG_PROTOCOL,
    SSH_LOG_PACKET    => SSH_LOG_PACKET,
    SSH_LOG_FUNCTIONS => SSH_LOG_FUNCTIONS,
  };
  my $lv = Kanku::Config::Defaults->get(
    'Kanku::Roles::SSH',
    'logverbosity'
  );
  my %options = (
      Host => $ip,
      Port => $port,
      User => $self->username,
      LogVerbosity => $lv_str2const->{$lv} || 0,
    );

  $logger->debug("Connecting to $ip (Timeout: $timeout)!");

  if ( $self->auth_type eq 'publickey') {
    my $privkey  = path($self->privatekey_path);
    my $identity = $privkey->absolute->stringify;
    my $sshdir   = $privkey->dirname;
    $options{Identity} = $identity if $identity;
    $options{SshDir}   = $sshdir   if $sshdir;
    $key_auth=1;
  }
  $logger->debug("Options: ".Dumper(\%options));
  while ($cc < $timeout) {
    $ssh = Libssh::Session->new(SkipKeyProblem=>1);
    $ssh->options(%options);
    if ($ssh->connect(connect_only=>1) != SSH_OK) {
      my $e = $ssh->error;
      $logger->trace("Retry connecting ($cc): $e");
      sleep 1;
    } else {
      $logger->debug("Connected successfully to $ip after $cc retries.");
      $timeout = 0;
    }
    $cc++;
  }

  $self->ssh($ssh);

  $logger->debug(' - SSH_AUTH_SOCK: '.($::ENV{SSH_AUTH_SOCK} || q{}));
  $logger->debug(
      "Using the following login data:\n" .
          "auth_type  : " . ( $self->auth_type || '' )        . "\n".
          "username   : " . ( $self->username || '' )         . "\n".
          "pubkey     : " . ( $self->publickey_path || '' )   . "\n".
          "privkey    : " . ( $self->privatekey_path || '' )  . "\n".
          "passphrase : " . ( $self->passphrase || '' )       . "\n".
          "password   : " . ( $self->password || '' )         . "\n"
  );
  my $auth_result;

  if ( $key_auth ) {
    $auth_result = $ssh->auth_publickey_auto();
  } elsif ( $self->auth_type eq 'password' ) {
    $logger->debug('Using password authentication');
    $auth_result = $ssh->auth_password(password => $self->password);
  } else {
    croak("ssh auth_type not known!\n");
  }

  if ($auth_result != SSH_AUTH_SUCCESS) {
    my $type = $self->auth_type;
    my $user = $self->username;
    my $msg = "";
    my $err = $ssh->error || q{};
    if ( $type eq 'agent' ) {
      $msg = "Have you added your ssh key to ssh-agent by running ssh-add?";
    } elsif ($type eq 'publickey') {
      $msg = "Using pubkey auth (pub/priv): "
             . $self->publickey_path.'/'.$self->privatekey_path."\n";
    }
    croak("Could not authenticate as user $user ($type)! $err\n$msg");
  }

  return $ssh;
}

sub exec_command {
  my $self = shift;
  my $cmd  = shift;
  my $ssh  = $self->ssh;

  for my $key (keys(%{$self->ENV})) {
    my $val = $self->ENV->{$key};
    $cmd = "export $key='$val'; $cmd";
  }

  $self->logger->info("Executing command: $cmd");

  my $ret = $ssh->execute_simple(cmd=>$cmd, timeout=>$self->timeout, timeout_nodata=>$self->timeout);

  if ($ret->{exit_code}) {
    croak("Command '$cmd' failed:\n\nSTDOUT:\n".($ret->{stdout}|| q{})."\n".($ret->{stderr}|| q{})."\n");
  }

  return $ret;
}

1;

__END__

=head1 NAME

Kanku::Roles::SSH - A generic role for handling ssh connections using Net::SSH2

=head1 SYNOPSIS

  package Kanku::Handler::MySSHHandler;
  use Moose;
  with 'Kanku::Roles::SSH';

  sub execute {
    my ($self) = @_;

    ...

    $self->get_defaults();

    $self->connect();

    # SEE Libssh::Session::execute_simple for further information
    my $ret = $self->exec_command("/bin/true");
  }

=head1 DESCRIPTION

This module contains a generic role for handling ssh connections in kanku using Net::SSH2

=head1 METHODS


=head2 get_defaults



=head2 connect



=head2 exec_command



=head1 ATTRIBUTES

  ipaddress         : IP address of host to connect to

  publickey_path    : path to public key file (optional)

  privatekey_path   : path to private key file

  passphrase        : password to use for private key

  username          : username used to login via ssh

  connect_timeout   : time to wait for successful connection to host

  job               : a Kanku::Job object (required for context)

  ssh2              : a Net::SSH2 object (usually created by role itself)

  auth_type	    : SEE Net::SSH2 for further information

=head1 CONTEXT

=head2 getters

  ipaddress

  publickey_path

  privatekey_path

=head2 setters

  NONE


=head1 DEFAULTS

  privatekey_path       : $HOME/.ssh/id_rsa

  publickey_path        : $HOME/.ssh/id_rsa.pub

  username              : root

  connect_timeout	: 300 (sec)

  auth_type		: agent

=cut
