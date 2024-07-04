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
package Kanku::Daemon::Dispatcher;

use Moose;
use Try::Tiny;

with 'Kanku::Roles::Daemon';

use Kanku::Dispatch::Local;
use Kanku::Dispatch::RabbitMQ;


sub run {
  my ($self) = @_;
  my $cfg = Kanku::Config->instance();

  my $mod = $cfg->config->{dispatcher} || "Kanku::Dispatch::Local";
  my $daemon = $mod->new();
  try {
    $daemon->run();
  } catch {
    $daemon->logger->fatal("Error while running dispatcher: $_");
  };
}

__PACKAGE__->meta->make_immutable;

1;
