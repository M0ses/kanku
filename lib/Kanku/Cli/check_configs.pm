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

use strict;
use warnings;

use MooseX::App::Command;
extends qw(Kanku::Cli);

use Kanku::Config;

command_short_description  'Check kanku config files';

command_long_description 'Check kanku config files';

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
  my $logger  = Log::Log4perl->get_logger;
  my $result = 0;

  if ($self->server) {
    Kanku::Config->initialize();
    for my $job (sort Kanku::Config->instance()->job_list) {
      eval { Kanku::Config->instance()->job_config($job); };
      if($@) {
        $logger->error("Failed to load job config $job:\n$@");
        $result = 1;
      } else {
        $logger->debug("$job - ok");
      }
    }
    for my $job (sort Kanku::Config->instance()->job_group_list) {
      eval { Kanku::Config->instance()->job_group_config($job); };
      if($@) {
        $logger->error("Failed to load job config $job:\n$@");
        $result = 1;
      } else {
        $logger->debug("$job - ok");
      }
    }
  } elsif ($self->devel) {
    eval { 
      Kanku::Config->initialize(class=>'KankuFile'); 
      Kanku::Config->instance->job_list();
    };
    if($@) {
      $logger->error("Failed to load KankuFile:\n$@");
      $result = 1;
    } else {
      $logger->debug("KankuFile - ok");
    }
  } else {
    $logger->error("Please choose --server or --devel");
    return 1;
  }

  if ($result) {
    $logger->error("Errors while checking configs!");
  } else {
    $logger->info("All checked configs ok!");
  }

  return $result;
}

#__PACKAGE__->meta->make_immutable;
1;
