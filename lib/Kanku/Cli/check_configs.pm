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
package Kanku::Cli::check_configs;     ## no critic (NamingConventions::Capitalization)

use MooseX::App::Command;
extends qw(Kanku::Cli);

with 'Kanku::Roles::Logger';
use Try::Tiny;
use Kanku::Config;

command_short_description  'Check kanku config files';

command_long_description '
Check kanku config files
';

option 'jobs' => (
  isa           => 'Bool',
  is            => 'rw',
  cmd_aliases   => 'j',
  documentation => 'check job files (Kankufile in devel mode - /etc/kanku/jobs/*.yml in server mode).',
  default       => 0,
);

option 'server' => (
  isa           => 'Bool',
  is            => 'rw',
  cmd_aliases   => 's',
  documentation => 'server mode',
  default       => 0,
);

option 'devel' => (
  isa           => 'Bool',
  is            => 'rw',
  cmd_aliases   => 'd',
  documentation => 'developer mode',
  default       => 0,
);

sub run {
  my ($self) = @_;
  my $logger = $self->logger;
  my $ret    = 0;

  if ($self->server) {
    Kanku::Config->initialize();
    my $kci = Kanku::Config->instance;

    # job_list
    for my $job (sort $kci->job_list) {
      my $NOT = ' not';
      try {
	$kci->job_config($job);
	$NOT = q{};
      } catch {
        $logger->debug("Failed to load job config $job:\n$_");
        $ret = 1;
      };
      $logger->info("Checking job $job -$NOT ok");
    }

    # job_group_list
    for my $job_group (sort $kci->job_group_list) {
      my $NOT = ' not';
      try {
	$kci->job_group_config($job_group);
	$NOT = q{};
      } catch {
        $logger->debug("Failed to load job config $job_group:\n$_");
        $ret = 1;
      };

      $logger->info("Checking job_group $job_group -$NOT ok");
    }

  } elsif ($self->devel) {
    my $NOT = ' not';
    try {
      Kanku::Config->initialize(class=>'KankuFile');
      Kanku::Config->instance->job_list();
      $NOT = q{};
    } catch {
      $logger->debug("Failed to load KankuFile:\n$_");
      $ret = 1;
    };
    $logger->info("KankuFile -$NOT ok");
  } else {
    $logger->error("Please choose --server or --devel");
    return 1;
  }

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
