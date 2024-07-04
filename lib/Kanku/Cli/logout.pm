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
package Kanku::Cli::logout; ## no critic (NamingConventions::Capitalization)

use MooseX::App::Command;
extends qw(Kanku::Cli);

with 'Kanku::Roles::Logger';
with 'Kanku::Cli::Roles::Remote';

command_short_description  'logout from your remote kanku instance';

command_long_description '
This command will proceeced a logout from your remote kanku instance and delete
the local session cookie
';

sub run {
  my ($self) = @_;
  my $logger = $self->logger;
  my $kr     = $self->connect_restapi();

  if ( $kr->logout() ) {
    $logger->error('Logout failed on the remote side');
  } else {
    $logger->info('Logout succeed');
  }

  return 0;
}

__PACKAGE__->meta->make_immutable;

1;
