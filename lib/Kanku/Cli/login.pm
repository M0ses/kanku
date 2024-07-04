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
package Kanku::Cli::login; ## no critic (NamingConventions::Capitalization)

use strict;
use warnings;
use MooseX::App::Command;
extends qw(Kanku::Cli);

use Term::ReadKey;
use Carp;
use Kanku::YAML;

with 'Kanku::Cli::Roles::Remote';

command_short_description  'login to your remote kanku instance';

command_long_description  '
With this command you can login to your remote kanku instance.

';

sub run {
  my ($self) = @_;
  my $logger = $self->logger;

  # Please note the priority of options
  # * command line options
  # * rc_file options
  # * manual input

  if ( -f $self->rc_file ) {

    $self->settings(Kanku::YAML::LoadFile($self->rc_file));

    if ( ! $self->apiurl ) {
      $self->apiurl( $self->settings->{apiurl} || q{});
    }
    if ( ! $self->keyring ) {
      $self->keyring( $self->settings->{keyring} || q{});
    }
    if ( ! $self->user ) {
      $self->user( $self->settings->{$self->apiurl}->{user} || q{});
    }
  }

  $self->choose_keyring() if (!$self->keyring);

  while ( ! $self->apiurl ) {
    print 'Please enter your apiurl: ';
    my $url = <STDIN>;
    chomp $url;
    $self->apiurl($url) if $url;
  }

  $logger->debug('apiurl: ' .  $self->apiurl);

  $self->connect_restapi();

  if ( $self->session_valid ) {

    $self->save_settings();

    $logger->info('Already logged in.');
    $logger->info(' Please use logout if you want to change user');


    return { success => 1 }
  }

  while ( ! $self->user ) {
    print 'Please enter your user: ';
    my $user = <STDIN>;
    chomp $user;
    $self->user($user) if $user;
  }
  my $keyring;
  if($self->keyring && $self->keyring ne 'None') {
    my $krmod  = my $krpkg = $self->settings->{keyring};
    $krmod =~ s#::#/#g;
    require "$krmod.pm";
    $keyring = $krpkg->new(app=>'kanku', group => 'kanku');
    if(! $self->password) {
      $self->password($keyring->get_password($self->user, $self->apiurl) || q{});
    }
  }

  while ( ! $self->password ) {

     print "Please enter your password for the remote server:\n";
     ReadMode('noecho');
     my $read = <STDIN>;
     chomp $read;

     $self->password($read || qw{});

     ReadMode('restore');
  }

  $self->user($self->user);
  $self->password($self->password);

  if ( $self->login() ) {
    # Store new default settings
    $keyring->set_password($self->user, $self->password, $self->apiurl) if $keyring;
    $self->save_settings();
    $logger->info('Login succeed!');
  } else {
    $logger->error('Login failed!');
    exit 1;
  }

  return;
}

sub save_settings {
  my $self    = shift;

  $self->settings->{apiurl}                    = $self->apiurl;
  $self->settings->{keyring}                   = $self->keyring;
  $self->settings->{$self->apiurl}->{user}     = $self->user;
  # Cleanup old settings from former buggy implementation
  delete $self->settings->{user};
  delete $self->settings->{password};

  Kanku::YAML::DumpFile($self->rc_file, $self->settings);
  chmod 0600, $self->rc_file;

  return 0;
}

sub choose_keyring {
  my ($self) = @_;
  my @keyrings = qw/KDEWallet Gnome/;
  my @found_keyrings = ('None');

  for my $keyring (@keyrings) {
    my $mod = "Passwd/Keyring/$keyring.pm";
    my $pkg = "Passwd::Keyring::$keyring";
    eval { require "$mod"; import $pkg };
    push @found_keyrings, $pkg unless $@;
  }

  if (@found_keyrings == 1) {
    $self->logger->warn(
      'No keyring modules found. Please install Passwd::Keyring::KDEWallet or '.
      'Passwd::Keyring::Gnome if you want to use a keyring manager!'
    );
    $self->keyring($found_keyrings[0]);
    return;
  }

  print "Please choose one of the following keyring managers to store your password:\n";
  my $cnt = 0;
  for my $keyring (@found_keyrings) {
    print "($cnt) $keyring\n";
    $cnt++;
  }
  print "\n\n";

  while (1) {
    my $choice = <STDIN>;
    chomp($choice);
    if ($choice =~ /^\d+$/) {
      my $kr = $self->keyring($found_keyrings[$choice]||q{});
      return $kr if $kr;
    }
    print "Invalid input! Please try again\n";
  }

}

__PACKAGE__->meta->make_immutable;

1;
