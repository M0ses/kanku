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
package Kanku::Cli::rr; ## no critic (NamingConventions::Capitalization)

use strict;
use warnings;

use MooseX::App::Command;
extends qw(Kanku::Cli);

with 'Kanku::Cli::Roles::Remote';

use Kanku::YAML;

command_short_description  'remove remote from your config';

command_long_description   '
This command will remove the given apiurl from your local config and
perform a logout on the remote server

';

sub run {
  my ($self)  = @_;
  my $logger  = $self->logger;
  my $kr      = $self->connect_restapi();
  my $apiurl  = $self->settings->{apiurl};

  if (!$apiurl) {
      $self->logger->warn('No apiurl found in config file. Aborting!');
      return 1;
  }

  my $user   = $self->settings->{$apiurl}->{user};
  delete $self->settings->{$apiurl};
  Kanku::YAML::DumpFile($self->rc_file, $self->settings);

  if (!$user) {
    $self->logger->warn("No user found in config file for apiurl '$apiurl'. Aborting!");
    return 1;
  }

  if ( my $ls = $kr->logout() ) {
    $logger->warn('Logout failed on the remote side');
  } else {
    $logger->debug('Logout succeed');
  }

  if ($self->settings->{keyring}  && $self->settings->{keyring} ne 'None') {
    if ($user) {
      my $krmod  = my $krpkg = $self->settings->{keyring};
      $krmod =~ s#::#/#g;
      require "$krmod.pm";
      $logger->debug("Removing '$user || $apiurl' from $krpkg");
      my $keyring = $krpkg->new(app=>'kanku', group=>'kanku');
      $keyring->clear_password($user, $apiurl);
    }
  }

  return 0;
}

__PACKAGE__->meta->make_immutable;

1;
