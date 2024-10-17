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
#
package Kanku::Cli::Login;

use strict;
use warnings;
use MooseX::App::Command;
extends qw(Kanku::Cli);

use Kanku::YAML;

with 'Kanku::Cli::Roles::Remote';

command_short_description  'login to your remote kanku instance';

command_long_description  <<'EOF';
With this command you can login to your remote kanku instance.

EOF

option ['+apiurl', '+user', '+password', '+keyring'] => (cmd_term=>1);
option ['+password'] => (cmd_term_input_hidden=>1);

sub run {
  my ($self) = @_;
  my $logger = $self->logger;

  if ( $self->session_valid ) {
    $logger->info('Already logged in.');
    $logger->info(' Please use logout if you want to change user');

    return 0;
  }

  if ( $self->login() ) {
    $logger->info('Login succeed!');
    $self->save_settings();
    return 0;
  }

  $logger->error('Login failed!');
  return 1;
}

sub save_settings {
  my ($self) = @_;

  $self->_api_config_data->{$self->apiurl} ||= {};

  my $keyring;
  if ($self->keyring && $self->keyring ne 'None') {
    my $krmod  = my $krpkg = 'Passwd::Keyring::'.$self->keyring;
    $krmod =~ s{::}{/}g;
    require "$krmod.pm";
    $keyring = $krpkg->new(app=>'kanku', group => 'kanku');
    $keyring->set_password($self->user, $self->password, $self->apiurl);
  } else {
    $self->_api_config_data->{$self->apiurl}->{password} = $self->password;
  }

  $self->_api_config_data->{apiurl}  = $self->apiurl;
  $self->_api_config_data->{keyring} = $self->keyring;
  $self->_api_config_data->{$self->apiurl}->{user} = $self->user;

  Kanku::YAML::DumpFile($self->api_config, $self->_api_config_data);
  chmod 0600, $self->api_config;

  return 0;
}

__PACKAGE__->meta->make_immutable;

1;
