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
package Kanku::Roles::Dispatcher;

use Moose::Role;
use POSIX;
use JSON::XS;
use Data::Dumper;
use Try::Tiny;

use Kanku::Config;
use Kanku::Config::Defaults;
use Kanku::Job;

with 'Kanku::Roles::ModLoader';
with 'Kanku::Roles::DB';

has 'config' => (
  is      =>'rw',
  isa     =>'Object',
  lazy    => 1,
  builder => '_build_config',
);
sub _build_config {
  return Kanku::Config->instance;
}

has '_shutdown_detected' => (is=>'rw',isa=>'Bool',default=>0);

=head1 NAME

Kanku::Roles::Dispatcher - A role for dispatch modules

=head1 REQUIRED METHODS

=head2 run_job - Run a job

=cut

requires "run_job";

=head1 METHODS

=head2 execute_notifier - run a configured notification module

=cut

sub run {
  my ($self) = @_;
  my $logger = $self->logger;
  my @child_pids;

  $self->initialize();

  $self->cleanup_dead_jobs();

  try {
    $self->cleanup_on_startup();
  } catch {
    $logger->warn($_);
  };

  while (1) {
    my $job_list = $self->get_todo_list();

    while (my $job = shift(@$job_list)) {
      my $pid = fork();

      if (! $pid ) {
        $SIG{'INT'} = $SIG{'TERM'} = sub { exit 0 };
        $logger->debug("Child starting with pid $$ -- $self");
        try {
          my $res = $self->run_job($job);
          $logger->debug("Got result from run_job");
          $logger->trace(Dumper($res));
        }
        catch {
          $logger->error("raised exception");
          my $e = shift;
          $logger->error($e);
        };
        $logger->debug("Before exit: $$");
        exit 0;
      } else {
        push (@child_pids,$pid);

        # wait for childs to exit
        while ( @child_pids >= $self->max_processes ) {
          @child_pids = grep { waitpid($_,WNOHANG) == 0 } @child_pids;
          last if ( $self->detect_shutdown );
          sleep(1);
          $logger->debug("ChildPids: (@child_pids) max_processes: ".$self->max_processes."\n");
        }
      }
      last if ( $self->detect_shutdown );
    }
    last if ( $self->detect_shutdown );
    sleep 1;
  }

  kill('TERM',@child_pids);

  my $wcnt = 0;

  while ( @child_pids ) {
    # log only every minute
    $logger->debug("Waiting for childs to exit: (@child_pids)") if (! $wcnt % 60);
    $wcnt++;
    @child_pids = grep { waitpid($_,WNOHANG) == 0 } @child_pids;
    sleep(1);
  }

  $self->cleanup_on_exit();

  $self->cleanup_dead_jobs();

  return;
}


sub cleanup_dead_jobs {
  my ($self, $worker_name) = @_;
  my $logger = $self->logger;
  my $result = {
   execute  => {message=>"Cleanup dead jobs"},
   finalize => {message=>"Cleanup dead jobs"},
   prepare  => {message=>"Cleanup dead jobs"},
  };

  if ($worker_name) {
    $logger->debug("Cleaning up dead jobs ($worker_name)");
  } else {
    $logger->debug('Cleaning up dead jobs');
  }

  my %worker_filter;
  if ($worker_name) {
    %worker_filter = (workerinfo=>{like=>"$worker_name:%"});
  }

  my $dead_jobs = $self->schema->resultset('JobHistory')->search(
    { state => ['running','dispatching'], %worker_filter }
  );

  my %job_filter;
  if ($worker_name) {
    my @job_ids;
    while (my $job = $dead_jobs->next) {
      push @job_ids, $job->id;
      my $pid = $job->masterinfo;
      $logger->debug("Killing: $pid");
      kill('TERM', $pid);
      my $kid;
      do {
        $kid = waitpid($pid, WNOHANG);
      } while $kid > 0;
      $logger->debug("Killed: $pid");
    }
    if (@job_ids) {
      %job_filter = (job_id => {'-in'=>\@job_ids})
    }
  }

  $dead_jobs->update({ state => 'failed', end_time => time()});

  my $dead_tasks = $self->schema->resultset('JobHistorySub')->search(
    { state => ['running'], %job_filter }
  );

  $dead_tasks->update({
    state  => 'failed',
    result => encode_json($result),
  });


  $logger->debug("Cleaning up dead jobs finished");

  return;
}

sub run_notifiers {
  my ($self, $job, $last_task) = @_;
  my $logger    = $self->logger();
  my $notifiers = $self->config->notifiers_config($job->name());

  foreach my $notifier (@{$notifiers}) {
    try {
      $self->execute_notifier($notifier, $job, $last_task);
    }
    catch {
      my $e = $_;
      $logger->error("Error while sending notification");
      $logger->error($e);
    };
  }
}

sub execute_notifier {
  my ($self, $options, $job, $task) = @_;
  my $logger    = $self->logger;
  my $state     = $job->state;
  my $cfg       = $self->config->{"Kanku::Notifier"} || {};

  $logger->debug("Job state: $state // $options->{states}");

  my @in        = grep { $state eq $_ } (split(/\s*,\s*/,$options->{states}));

  $logger->trace("\@in: '@in'");

  return if (! @in);

  my $mod = $options->{use_module};
  die "No use_module definition in config (job: $job)" if ( ! $mod );

  my $args = $options->{options} || {};
  die "args for $mod not a HashRef" if ( ref($args) ne 'HASH' );

  $self->load_module($mod);

  my $notifier = $mod->new(
    options   => $args,
    job_id    => $job->id,
    state     => $state,
    duration  => ($job->end_time > $job->start_time) ? $job->end_time - $job->start_time : 0,
    kanku_url => Kanku::Config::Defaults->get('Kanku::Notifier', 'kanku_url'),
    context   => $job->context,
  );

  my $jname = $job->name;
  my $jid   = $job->id;
  $notifier->short_message("Job $jname($jid) has exited with state '$state'");

  my $result;
  try {
    $result = decode_json($task->result)->{error_message}
              || 'No errors found in task result';
  } catch {
    $result = 'Error while decoding result of task from job '.
      $job->id . ":\n\n$_\nJSON:\n".$task->result."\n";
    $logger->error($result);
  };

  $notifier->full_message($result);

  $notifier->notify();

  return;
}

sub load_job_definition {
  my ($self, $job)   = @_;
  my $job_definition = undef;

  $self->logger->debug("Loading definition for job: ".$job->name);

  try {
    my $kci = Kanku::Config->instance;
    $job_definition = $kci->job_config($job->name);
  }
  catch {
    $job->exit_with_error($_);
  };
  return $job_definition;
}

sub prepare_job_args  {
  my ($self, $job)      = @_;
  my $args              = [];
  my $parse_args_failed = 0;

  try {
    my $args_string = $job->db_object->args();

    if ($args_string) {
      $args = decode_json($args_string);
    }
    die "args not containting a ArrayRef" if (ref($args) ne "ARRAY" );
  }
  catch {
    $job->exit_with_error($_);
  };

  $self->logger->trace("  -- args:".Dumper($args));

  return $args;
}

sub get_todo_list {
  my $self    = shift;
  my $schema  = $self->schema;
  my $todo = [];
  my $job_groups = {};
  my $rs = $schema->resultset('JobHistory')->search({state=>['scheduled','triggered']},{ order_by => { -asc => 'creation_time' }} );

  JOB: while ( my $ds = $rs->next )   {
    my @awf; # all wait for
    my $wait_for = $ds->wait_for();

    while (my $jwf = $wait_for->next) {
      my $njwf = $jwf->wait_for;
      if ($njwf->state =~ /^(scheduled|triggered|running|dispatching)$/) {
        $self->logger->trace("Job ".$ds->id." is still waiting for Job ".$njwf->id);
	next JOB;
      }
    }

    # Check if another job_group is running with the same job group
    # name
    my $jg_id = $ds->job_group_id;
    if ($jg_id) {
      my $current_group = $schema->resultset('JobGroup')->find($jg_id);
      my $jg_name = $current_group->name;
      my $groups = $schema->resultset('JobGroup')->search(
        {
          id         => {"!=" => $jg_id},
          name       => $jg_name,
          start_time => {'>'=>0},
          end_time   => 0,
        },
        {
          order_by => { -asc => 'creation_time' }
        },
      );
      my $gcount = $groups->count;
      $self->logger->trace(" -- gcount for '$jg_name': $gcount $jg_id");
      if ($gcount || $job_groups->{$jg_name}) {
        $self->logger->trace(" -- Found already running job group $jg_name");
        next JOB;
      } else {
        $job_groups->{$jg_name}++;
        $self->logger->debug(" -- Found no running job group $jg_name");
      }
    }

    push (
      @$todo,
      Kanku::Job->new(
        db_object    => $ds,
        id           => $ds->id,
        state        => $ds->state,
        name         => $ds->name,
        skipped      => 0,
        scheduled    => ( $ds->state eq 'scheduled' ) ? 1 : 0,
        triggered    => ( $ds->state eq 'triggered' ) ? 1 : 0,
        trigger_user => $ds->trigger_user,
	job_group_id => $ds->job_group_id,
      )
    );
  }
  return $todo;
}

sub start_job {
  my ($self,$job) = @_;

  $self->logger->debug("Starting job: ".$job->name." (".$job->id.")");
  my $stime = time();
  $job->start_time($stime);
  $job->state("running");
  $job->update_db();
}

1;
