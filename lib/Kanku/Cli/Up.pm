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
package Kanku::Cli::Up;

use MooseX::App::Command;
extends qw(Kanku::Cli);


with 'Kanku::Cli::Roles::Schema';
with 'Kanku::Cli::Roles::VM';

use Carp;
use Cwd;

use Kanku::Config;
use Kanku::Config::Defaults;

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
    isa           => 'ArrayRef',
    is            => 'rw',
    cmd_aliases   => 'j',
    documentation => 'jobs to run',
);

option 'job_group' => (
    isa           => 'Str',
    is            => 'rw',
    cmd_aliases   => 'jg',
    documentation => 'job group to run',
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
    cmd_aliases   => [qw/skip-all-checks sac/],
    documentation => 'Skip all checks when downloading from OBS server e.g.',
);

option 'skip_check_project' => (
    isa           => 'Bool',
    is            => 'rw',
    documentation => 'Skip checks if project is ready when downloading from OBS',
);

option 'skip_check_package' => (
    isa           => 'Bool',
    is            => 'rw',
    documentation => 'Skip checks if package is ready when downloading from OBS',
);

option 'skip_check_domain' => (
    isa           => 'Bool',
    is            => 'rw',
    documentation => 'Skip check if domain already exists',
    cmd_aliases   => 'S',
    default       => 0,
);

sub run {
  my ($self)  = @_;
  Kanku::Config->initialize(class=>'KankuFile', file=>$self->file); 
  my $logger  = $self->logger;
  my $config  = $self->kankufile_config;
  my $rc      = 0;
  my $schema  = $self->schema;
  croak("Could not connect to database\n") if ! $schema;

  $logger->debug(__PACKAGE__ . '->run();');

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
      return 129;
    }
  }

  $logger->debug('offline mode: ' . ($self->offline   || 0));

  my $jobs = [];

  if ($self->job_group && ref($config->{job_groups}->{$self->job_group}) eq 'ARRAY') {
    $jobs = $config->{job_groups}->{$self->job_group};
  } elsif (ref($self->job_name) eq 'ARRAY') {
    for (my $i=0; $i <= @{$self->job_name}; $i++) {
      push @$jobs, $self->job_name->[$i+1] if $self->job_name->[$i+1];
      $i++;
    }
  } else {
    $jobs->[0] = $config->{default_job} if ! $self->job_name;
  }

  for my $jname (@$jobs) {
    croak("Error in config for job '$jname'") unless ref($config->{jobs}->{$jname}) eq 'ARRAY';
  }

  for my $jname (@$jobs) {
    my $ds = $schema->resultset('JobHistory')->create({
	name          => $jname,
	creation_time => time,
	last_modified => time,
	state         => 'triggered',
    });

    $logger->info("Starting kanku job `$jname` with id `".$ds->id."`");
    $logger->info("Current  domain_name: `$dn`");
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
	    login_user         => $config->{login_user},
	    login_pass         => $config->{login_pass},
	    offline            => $self->offline            || 0,
	    skip_all_checks    => $self->skip_all_checks    || 0,
	    skip_check_project => $self->skip_check_project || 0,
	    skip_check_package => $self->skip_check_package || 0,
	    log_file    => $self->log_file,
	    log_stdout  => $self->log_stdout,
	  },
    );
    @ARGV=(); ## no critic (Variables::RequireLocalizedPunctuationVars)
    if ($self->pool) {
      #Kanku::Config->instance->cf->{'Kanku::Handler::CreateDomain'}->{pool_name} = $self->pool;
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
	$rc = 128;
    };
  }

  return $rc;
}

__PACKAGE__->meta->make_immutable;

1;
