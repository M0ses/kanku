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
package Kanku::Cli::CheckConfigs::Devel;

use MooseX::App::Command;
extends qw(Kanku::Cli);

use Try::Tiny;

with 'Kanku::Cli::Roles::VM';

use Kanku::Config;

command_short_description  'Check kanku config file';

command_long_description '
Check kanku config files
';

sub run {
  my ($self) = @_;
  my $logger = $self->logger;
  my $ret    = 0;

  my $NOT = ' not';
  try {
    Kanku::Config->initialize(class=>'KankuFile', file => $self->file);
    Kanku::Config->instance->job_list();
    $NOT = q{};
  } catch {
    $logger->debug("Failed to load KankuFile:\n$_");
    $ret = 1;
  };
  $logger->info("KankuFile -$NOT ok");

  return $self->_print_footer($ret);
}

sub _print_footer {
  my ($self, $ret) = @_;
  if ($ret) {
    $self->logger->error("Errors while checking configs!");
  } else {
    $self->logger->info("All checked configs ok!");
  }
  return $ret;
}

__PACKAGE__->meta->make_immutable;

1;
