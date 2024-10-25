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
package Kanku::Cli::Status;

use MooseX::App::Command;
extends qw(Kanku::Cli);

use Kanku::Util::VM;

with 'Kanku::Cli::Roles::VM';

command_short_description 'Show status of kanku VM';

command_long_description  '
This command can be used to show the status of a VM.

';

sub run {
  my ($self)  = @_;
  my $logger  = $self->logger;

  $logger->debug('Searching for domain: '.$self->domain_name);
  my $vm = Kanku::Util::VM->new(domain_name=>$self->domain_name);
  my $state = $vm->state();
  if ($state eq 'on' ) {
    my $ip    = $vm->get_ipaddress();
    $logger->info("VM is running ($ip)");
    $self->print_formatted(
      {
	domain_name => $self->domain_name,
	state       => 'on',
	ipaddress   => ($ip||qw{}),
      },
    );
  } elsif ( $state eq 'off' ) {
    $logger->error('VM isn`t running');
  } elsif ( $state eq 'unknown' ) {
    $logger->warn('VM is in state "unknown"');
  } else {
    $logger->fatal("Kanku::Util::VM returned an impossible state '$state'");
    return 1;
  }
  return 0;
}

__PACKAGE__->meta->make_immutable;

1;
