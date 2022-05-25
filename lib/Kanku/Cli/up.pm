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
package Kanku::Cli::up; ## no critic (NamingConventions::Capitalization)

use strict;
use warnings;

use MooseX::App::Command;
extends qw(Kanku::Cli);

with 'Kanku::Cli::Roles::Schema';
with 'Kanku::Cli::Roles::VM';

use Carp;

use Kanku::Config;
use Kanku::Job;
use Kanku::JobList;
use Kanku::Dispatch::Local;
use Kanku::Util::VM;

command_short_description 'start the job defined in KankuFile';

command_long_description 'start the job defined in KankuFile';

option 'offline' => (
    isa           => 'Bool',
    is            => 'rw',
    cmd_aliases   => 'o',
    documentation => 'offline mode',
);

option 'job_name' => (
    isa           => 'Str',
    is            => 'rw',
    cmd_aliases   => 'j',
    documentation => 'job to run',
);

option 'pool' => (
    isa           => 'Str',
    is            => 'rw',
    cmd_aliases   => 'p',
    documentation => 'libvirt storage pool to use for images',
);

option 'skip_all_checks' => (
    isa           => 'Bool',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'Skip all checks when downloading from OBS server e.g.',
);

option 'skip_check_project' => (
    isa           => 'Bool',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'Skip checks if project is ready when downloading from OBS',
);

option 'skip_check_package' => (
    isa           => 'Bool',
    is            => 'rw',
    #cmd_aliases   => 'X',
    documentation => 'Skip checks if package is ready when downloading from OBS',
);

option 'skip_check_domain' => (
    isa           => 'Bool',
    is            => 'rw',
    documentation => 'Skip check if domain already exists',
    default       => 0,
);

sub run {
  my ($self)  = @_;
  my $logger  = Log::Log4perl->get_logger;
  my $cfg     = $self->cfg;

  my $schema  = $self->schema;

  croak("Could not connect to database\n") if ! $schema;

  $logger->debug(__PACKAGE__ . '->execute()');

  $self->job_name($cfg->config->{default_job}) if ! $self->job_name;
  my $dn = $self->domain_name;
  my $vm      = Kanku::Util::VM->new(
    domain_name => $dn,
    log_file    => $self->log_file,
    log_stdout  => $self->log_stdout,
  );

  if (!$self->skip_check_domain) {
    $logger->debug("Searching for domain: $dn");
    if ($vm->dom) {
      $logger->fatal("Domain $dn already exists");
      exit 1;
    }
  }

  $logger->debug('offline mode: ' . ($self->offline   || 0));
  $logger->debug('job_name: '     . ($self->job_name  || q{}));

  my $job_config = $cfg->job_config($self->job_name);

  croak("No such job found\n") if ! $job_config;

  my $ds = $schema->resultset('JobHistory')->create({
      name          => $self->job_name,
      creation_time => time,
      last_modified => time,
      state         => 'triggered',
  });

  my $job = Kanku::Job->new(
        db_object => $ds,
        id        => $ds->id,
        state     => $ds->state,
        name      => $ds->name,
        skipped   => 0,
        scheduled => 0,
        triggered => 0,
        context   => {
          domain_name        => $dn,
          login_user         => $cfg->config->{login_user},
          login_pass         => $cfg->config->{login_pass},
          offline            => $self->offline            || 0,
          skip_all_checks    => $self->skip_all_checks    || 0,
          skip_check_project => $self->skip_check_project || 0,
          skip_check_package => $self->skip_check_package || 0,
          log_file    => $self->log_file,
          log_stdout  => $self->log_stdout,
        },
  );
  @ARGV=(); ## no critic (Variables::RequireLocalizedPunctuationVars)
  Kanku::Config->initialize();
  if ($self->pool) {
    Kanku::Config->instance->cf->{'Kanku::Handler::CreateDomain'}->{pool_name} = $self->pool;
  }
  my $dispatch = Kanku::Dispatch::Local->new(schema=>$schema);
  my $result   = $dispatch->run_job($job);
  my $ctx      = $job->context;
  if ( $result->state eq 'succeed' ) {
      $logger->info('domain_name : ' . ( $ctx->{domain_name} || q{}));
      $logger->info('ipaddress   : ' . ( $ctx->{ipaddress}   || q{}));
  } elsif ( $result->state eq 'skipped' ) {
    $logger->warn('Job was skipped');
    $logger->warn('Please see log to find out why');
  } else {
      $logger->error('Failed to create domain: ' . ( $ctx->{domain_name} || q{}));
      $logger->error("ipaddress   : $ctx->{ipaddress}") if $ctx->{ipaddress};
  };

  return;
}

__PACKAGE__->meta->make_immutable;

1;
