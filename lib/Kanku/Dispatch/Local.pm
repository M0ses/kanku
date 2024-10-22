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
package Kanku::Dispatch::Local;

use Moose;
use JSON::XS;
use Try::Tiny;

with 'Kanku::Roles::Logger';
with 'Kanku::Roles::Dispatcher';
with 'Kanku::Roles::Daemon';
with 'Kanku::Roles::Helpers';

use Kanku::Task;

has 'max_processes' => (is=>'rw',isa=>'Int',default=>1);

sub run_job {
  my ($self, $job) = @_;
  my $logger       = $self->logger();
  my $schema       = $self->schema();

  my $job_definition = $self->load_job_definition($job);
  if ( ! $job_definition) {
    $logger->error("No job definition found!");
    return "failed";
  }

  $self->start_job($job);

  my $state             = undef;
  my $args              = $self->prepare_job_args($job);

  return 1 if (! $args);

  $logger->trace("  -- args: ".Kanku::Helpers->dump_it($args));

  my $task;

  foreach my $sub_task (@{$job_definition->{tasks}}) {
    my $task_args = shift(@$args) || {};
    my %defaults = (
      job         => $job,
      module      => $sub_task->{use_module},
      final_args  => {%{$sub_task->{options} || {}},%{$task_args}},
    );
    my $un = $job->trigger_user;
    $logger->debug("--- trigger_user $un");
    $defaults{final_args}->{domain_name} =~ s{^($un-)?}{$un-}smx if ($un && exists $defaults{final_args}->{domain_name});
    $logger->debug('--- final_args'.Kanku::Helpers->dump_it($defaults{final_args}));

    try {
      my $start = time;
      $logger->info("Running task with handler $defaults{module}");
      $task = Kanku::Task->new(
	%defaults,
	options   => $sub_task->{options} || {},
	schema    => $self->schema,
	scheduler => $self,
	args      => $task_args,
      );

      my $tr = Kanku::Task::Local->new(
	%defaults,
	schema          => $self->schema
      );

      $task->run($tr);
      my $end = time;
      my $duration = $end - $start;
      $logger->info("Finished task ($defaults{module}) within $duration seconds");
      $job->state($task->state);
      die $task->result if $task->state eq 'failed';
    } catch {
      $logger->debug("setting job state to failed: '$_'");
      $job->state('failed');
      $job->result(encode_json({error_message=>$_}));
      # last task failed - so we undefine it
      $task = undef;
    };


    last if $job->skipped || !$task;
  }

  $self->end_job($job,$task);

  $self->run_notifiers($job,$task);

  return $job;
}

sub cleanup_on_startup {

}

sub cleanup_on_exit {

}

sub initialize {

}

sub end_job {
  my ($self, $job, $task) = @_;
  my $logger              = $self->logger;
  if ($task) {
    $job->state(($job->skipped) ? 'skipped' : $task->state);
  } else {
    $job->state('skipped') if ($job->skipped);
  }
  $job->end_time(time());
  $job->update_db();
  if (ref($job->context->{pwrand}) eq 'HASH') {
    while ( my ($user, $pw) = each %{$job->context->{pwrand}}) {
      $logger->error("Password for user '$user': $pw");
    }
  }
  my $msg = sprintf(
    "Finished job: %s (%d) with state '%s' in %s seconds",
    $job->name,
    $job->id,
    $job->state,
    $job->duration,
  );
  $logger->info($msg);
}


__PACKAGE__->meta->make_immutable();

1;

