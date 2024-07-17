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
package Kanku::Cli::Startvm;

use strict;
use warnings;
use MooseX::App::Command;
extends qw(Kanku::Cli);

use Kanku::Config;
use Kanku::Util::VM;

with 'Kanku::Cli::Roles::VM';

command_short_description 'Start kanku VM';

command_long_description 'This command can be used to start an already existing VM';

sub run {
  my ($self)  = @_;
  my $logger  = $self->logger;
  my $dn      = $self->domain_name;
  my $vm      = Kanku::Util::VM->new(
    domain_name => $dn,
    log_file    => $self->log_file,
    log_stdout  => $self->log_stdout,
  );

  $logger->debug("Searching for domain: $dn");

  if ($vm->dom) {
    if ( $vm->state eq 'on' ) {
      $logger->warn("Domain $dn already running");
    } else {
      $logger->info("Starting domain: $dn");
      $vm->dom->create();
    }
  } else {
    $logger->fatal("Domain $dn doesn`t exist");
    return 1;
  }

  return 0;
}

__PACKAGE__->meta->make_immutable;

1;
