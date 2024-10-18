package Kanku::Dispatch::RabbitMQ;


=head1 NAME

Kanku::Dispatch::RabbitMQ - TODO: comment

=head1 SYNOPSIS

|scheduler.pl <required-options> [optional options]

=head1 DESCRIPTION

FIXME: add a useful description

=head1 AUTHORS

Frank Schreiner, <fschreiner@suse.de>

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use Moose;

use JSON::XS;
use POSIX;
use Try::Tiny;
use Carp;
use Kanku::RabbitMQ;
use Kanku::Task;
use Kanku::Task::Local;
use Kanku::Task::Remote;
use Kanku::Task::RemoteAll;

with 'Kanku::Roles::Dispatcher';
with 'Kanku::Roles::ModLoader';
with 'Kanku::Roles::Daemon';
with 'Kanku::Roles::Helpers';

has kmq => (is=>'rw',isa=>'Object');

has job => (is=>'rw',isa=>'Object');

has job_queue => (is=>'rw',isa=>'Object');

has job_remote_routing_key => (is=>'rw', isa=>'Str');

has job_local_routing_key => (is=>'rw', isa=>'Str');

has wait_for_workers => (is=>'ro',isa=>'Int',default=>1);

has rabbit_config => (
  is      => 'rw',
  isa     => 'HashRef',
  lazy    => 1,
  default => sub { Kanku::Config->instance->cf->{"Kanku::RabbitMQ"} || {}; }
);

has active_workers => (
  is      => 'rw',
  isa     => 'HashRef',
  lazy    => 1,
  default => sub { {} },
);

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

  my $mp = scalar(@{Kanku::Config->instance->cf->{'Kanku::LibVirt::HostList'}||[]}) || 1;
  $logger->debug("max_processes: $mp\n");

  my $pid1 = fork();
  if (!$pid1) {
    $logger->debug("Started watcher $$ ");
    my $rmq = Kanku::RabbitMQ->new(%{$self->rabbit_config});
    $rmq->shutdown_file($self->shutdown_file);
    $rmq->connect() || die "Could not connect to rabbitmq\n";
    $rmq->create_queue(routing_key=>'kanku.to_dispatcher');
    while (1) {
      my $msg = $rmq->recv(1000);
      if ($msg ) {
	  my $data;
	  $logger->trace("got message: ".$self->dump_it($msg));
	  my $body = $msg->{body};
	  try {
	    $data = decode_json($body);
	    $logger->trace("Received data for dispatcher: ".$self->dump_it($data));
	    if ($data->{action} eq "worker_heartbeat") {
	      $logger->trace("Received heartbeat from worker: $data->{hostname} sent at $data->{current_time}");
	      delete $data->{action};
	      my $hn = delete $data->{hostname};
	      $self->active_workers->{$hn} = $data;
	    } elsif ($data->{action} eq "started_worker" or $data->{action} eq "shutdown_worker") {
              $self->cleanup_dead_jobs($data->{hostname});
	    } else {
	      $logger->error("Unknown action recived: $data->{action}");
	    }
	  } catch {
	    $logger->debug("Error in JSON:\n$_\n$body\n");
	  };
      }
      foreach my $hn (keys(%{$self->active_workers})) {
	my $data = $self->active_workers->{$hn};
	$self->schema->resultset('StateWorker')->update_or_create({
	   hostname    => $hn,
	   last_seen   => $data->{current_time},
	   last_update => time(),
	   info        => encode_json($data),
	});
      }
      $logger->trace('Active Workers('.time().'): ' . $self->dump_it($self->active_workers));
      last if ( $self->detect_shutdown );
    }
  }

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
          $logger->trace($self->dump_it($res));
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
        while ( @child_pids >= $mp ) {
          @child_pids = grep { waitpid($_,WNOHANG) == 0 } @child_pids;
          last if ( $self->detect_shutdown );
          sleep(1);
          $logger->trace("ChildPids: (@child_pids)\n");
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

sub run_job {
  my ($self, $job) = @_;

  my $logger       = $self->logger();

  $self->job($job);

  $job->masterinfo($$);
  $job->state('dispatching');
  $job->update_db();

  if (my $jgid = $job->job_group_id) {
    my $group = $self->schema->resultset('JobGroup')->find({id=>$jgid});
    if (!$group->start_time) {
      $logger->debug("Setting start_time for job_group_id: $jgid");
      $group->start_time(time());
      $group->update;
    }
  }

  $self->notify_queue->send({
    type           => 'job_change',
    event          => 'dispatching',
    message        => "Dispatching job (".$job->name."/".$job->id.")",
    name           => $job->name,
    id             => $job->id
  });

  $self->job_local_routing_key("kanku.job-".$job->id);

  # job definition should be parsed before advertising job
  # if no valid job definition it should not be advertised
  my $job_definition = $self->load_job_definition($job);
  my $args           = $self->prepare_job_args($job);

  my $rmq = Kanku::RabbitMQ->new(%{$self->rabbit_config});
  $rmq->shutdown_file($self->shutdown_file);
  $rmq->connect() || die "Could not connect to rabbitmq\n";
  $rmq->create_queue(routing_key=>$self->job_local_routing_key);
  $self->job_queue($rmq);

  my $applications={};;

  while (! keys(%{$applications})) {
    $applications = $self->advertise_job(
      $rmq,
      {
	 answer_key       => $self->job_local_routing_key,
	 job_id	  	  => $job->id,
	 arch             => $job_definition->{arch} || 'x86_64',
      }
    );
    die "shutdown detected while waiting for applications" if ($self->detect_shutdown);
    sleep 1;
  }

  $logger->trace("List of all applications:\n" . $self->dump_it($applications));

  # pa = prefered_application
  my ($pa, $declined_applications) = $self->score_applications($applications);

  $self->decline_applications($declined_applications);

  my $result = $self->send_job_offer($rmq, $pa);

  $self->notify_queue->send({
    type          => 'job_change',
    event         => 'sending',
    message       => "Sending job (".$job->name."/".$job->id.") to worker ($pa->{worker_fqhn},$pa->{worker_pid})",
    name           => $job->name,
    id             => $job->id
  });

  $self->job_remote_routing_key($pa->{answer_key});

  $self->start_job($job);

  $job->workerinfo($pa->{worker_fqhn}.":".$pa->{worker_pid}.":".$self->job_remote_routing_key);
  $logger->trace("Result of job offer:\n".$self->dump_it($result));
  $logger->trace("  -- args:\n".$self->dump_it($args));

  my $last_task;

  try {
    foreach my $sub_task (@{$job_definition->{tasks}}) {
      my $task_args = shift(@$args) || {};
      #$self->logger->debug("ROUTING_KEY: ".$rmq->routing_key." QUEUE: ".$rmq->queue_name);
      $last_task = $self->run_task(
	job       => $job,
	options   => $sub_task->{options} || {},
	module    => $sub_task->{use_module},
	scheduler => $self,
	args      => $task_args,
	kmq       => $rmq,
	routing_key => $self->job_local_routing_key,
      );

      last if ( $last_task->state eq 'failed' or $job->skipped);
    }
    $job->state($last_task->state);
  } catch {
    $logger->debug("setting job state to failed: '$_'");
    $job->state('failed');
    $job->result(encode_json({error_message=>$_}));
    # last task failed - so we undefine it
    $last_task = undef;
  };

  $self->notify_queue->send({
    type          => 'job_change',
    event         => 'finished',
    result        => $job->state,
    message       => "Finished job (".$job->name."/".$job->id.") with result: ".$job->state,
    name          => $job->name,
    id            => $job->id
  });

  $self->send_finished_job($self->job_remote_routing_key, $job->id);

  $self->end_job($job,$last_task);

  $self->run_notifiers($job,$last_task);

  $rmq->destroy_queue();
  $rmq->queue->disconnect;

  return $job->state;
}

sub run_task {
  my $self = shift;
  my %opts = @_;
  my $job  = $self->job;
  my $mod  = $opts{module};
  my $distributable = $self->check_task($mod);
  my $logger = $self->logger;

  $logger->debug("Starting with new task");

  my %defaults = (
    job         => $opts{job},
    module      => $opts{module},
    final_args  => {%{$opts{options} || {}},%{$opts{args} || {}}},
  );

  # trigger_user is only set if a non-Admin triggered a job
  # then domain name should look like "$trigger_user-$domain_name"
  # to avoid overwriting
  my $un = $job->trigger_user || "";
  $logger->debug("--- trigger_user $un");
  $defaults{final_args}->{domain_name} =~ s{^($un-)?}{$un-}smx if ($un && $defaults{final_args}->{domain_name});
  $logger->trace('--- final_args = '.$self->dump_it($defaults{final_args}));

  my $task = Kanku::Task->new(
    %defaults,
    schema       => $self->schema,
    scheduler    => $opts{scheduler},
    notify_queue => $self->notify_queue
  );

  my $tr;

  if ( $distributable < 0 ) {
    croak("The configured module $mod is not distributable!\n");
  } elsif ( $distributable == 0 ) {
    $tr = Kanku::Task::Local->new(
      %defaults,
      schema          => $self->schema
    );
  } elsif ( $distributable == 1 ) {
    $logger->debug("--- Calling Kanku::Task::Remote - ".$self->job_queue->routing_key);
    $logger->debug("--- Calling Kanku::Task::Remote - ".$opts{routing_key});
    $self->job_queue->routing_key($self->job_remote_routing_key);
    $tr = Kanku::Task::Remote->new(
      %defaults,
      job_queue  => $self->job_queue,
      daemon	 => $self,
      answer_key =>  $self->job_local_routing_key,
    );
  } elsif ( $distributable == 2 ) {
    $tr = Kanku::Task::RemoteAll->new(
      %defaults,
      kmq => $opts{kmq},
      local_key_name => $opts{routing_key},
    );
  } else {
    croak("Unknown distributable value '$distributable' for module $mod\n");
  }

  return $task->run($tr);
}

sub check_task {
  my ($self,$mod) = @_;

  $self->load_module($mod);
  return $mod->distributable();
}

sub decline_applications {
  my ($self, $declined_applications) = @_;
  my $rmq = Kanku::RabbitMQ->new(%{$self->rabbit_config});
  $rmq->shutdown_file($self->shutdown_file);
  $rmq->connect() || die "Could not connect to rabbitmq\n";

  foreach my $queue( keys(%$declined_applications) ) {
    $rmq->queue_name($queue);
    $rmq->publish(
      $queue,
      encode_json({action => 'decline_application'}),
    );
  }

}

sub send_job_offer {
  my ($self,$rmq,$prefered_application)=@_;
  my $logger = $self->logger;

  $logger->debug("Offering job for prefered_application $prefered_application->{worker_fqhn}");
  $logger->trace("\$prefered_application = ".$self->dump_it($prefered_application));

  $rmq->publish(
    $prefered_application->{answer_key},
    encode_json(
      {
        action			=> 'offer_job',
        answer_key		=> $prefered_application->{answer_key}
      }
    ),
  );
}

sub send_finished_job {
  my ($self, $aq, $job_id)=@_;
  my $logger = $self->logger;


  $logger->debug("Sending finished_job for job_id $job_id to queue $aq");

  $self->job_queue->publish(
    $aq,
    encode_json(
      {
        action  => 'finished_job',
        job_id  => $job_id
      }
    ),
  );
}

sub score_applications {
  my ($self,$applications) = @_;

  my $pref;

  my @keys = keys(%$applications);

  $self->logger->debug("Keys of applications: '@keys'");

  my $key = shift(@keys);

  my $ret = $applications->{$key};
  delete $applications->{$key};

  return ($ret,$applications);

}

sub advertise_job {
  my $self                  = shift;
  my ($rmq,$opts)           = @_;
  my $all_applications      = {};
  my $logger                = $self->logger;

  my $data = encode_json({action => 'advertise_job', %$opts});

  my $wcnt = 0;

  while(! %$all_applications ) {

    $logger->debug('Publishing application (routing key: kanku.to_all_workers): '.$self->dump_it($data));

    $rmq->publish(
      'kanku.to_all_workers',
      $data,
    );

    $logger->debug('Wait for workers: '.$self->wait_for_workers);

    sleep($self->wait_for_workers);

    $logger->debug('Looking for applications on : '.$rmq->queue_name);

    while ( my $msg = $rmq->recv(1000) ) {
      if ($msg ) {
          my $data;
          $logger->trace("got message:\n".$self->dump_it($msg));
          my $body = $msg->{body};
          try {
            $data = decode_json($body);
            $logger->debug("Incomming application for $data->{job_id} from $data->{worker_fqhn} ($data->{worker_pid}))");
            $all_applications->{$data->{answer_key}} = $data;
          } catch {
            $logger->debug("Error in JSON:\n$_\n$body\n");
          };
      }
    }

    # log only every 60 seconds
    $logger->debug("No application so far (wcnt: $wcnt)") if (! $wcnt % 60);
    $wcnt++;
  }

  $logger->debug(" Got ".%{$all_applications}." applications");

  return $all_applications;
}

sub cleanup_on_startup {
  my ($self) = @_;
  $self->cleanup_dead_job_groups;
}

sub cleanup_on_exit {
  my ($self) = @_;
  $self->cleanup_dead_job_groups;
}

sub initialize {
  my ($self) = @_;
  my $rmq = Kanku::RabbitMQ->new(%{$self->rabbit_config});
  $rmq->shutdown_file($self->shutdown_file);
  $rmq->connect() || die "Could not connect to rabbitmq\n";
}

sub cleanup_dead_job_groups {
  my ($self) = @_;
  my $logger = $self->logger;
  my @dead_job_groups = $self->schema->resultset('JobGroup')->search({
    start_time  => { '>', 0},
    end_time    => 0,
  });
  for my $jg (@dead_job_groups) {
    $logger->warn("Found dead job_group with id ".$jg->id);
    $jg->end_time(time());
    $jg->update();
  }

}

sub end_job {
  my ($self, $job, $task) = @_;
  if ($task) {
    $job->state(($job->skipped) ? 'skipped' : $task->state);
  } else {
    $job->state('skipped') if ($job->skipped);
  }
  $job->end_time(time());
  $job->update_db();

  if ( $job->state eq 'failed') {
    $self->clean_up_wait_for($job->id);
  }

  $self->logger->debug("Finished job: ".$job->name." (".$job->id.") with state '".$job->state."'");
  my $jgid = $job->job_group_id;
  if ($jgid) {
     my $schema  = $self->schema;
     my $remaining_jobs = $schema->resultset('JobHistory')->search(
       {
         job_group_id => $job->job_group_id,
         state=>{-not_in=>['succeed','failed','skipped']},
       }
     );
     if (! $remaining_jobs->count) {
       my $group = $schema->resultset('JobGroup')->find({id=>$job->job_group_id});
       $group->end_time(time());
       $group->update;
     } else {
       $self->logger->debug("Found Remaining Jobs: ".$remaining_jobs->count);
     }
  } else{
    $self->logger->debug("No Job Group ID found");
  }
}

sub clean_up_wait_for {
  my ($self, $job_id) = @_;
  my $schema  = $self->schema;
  my $rs = $schema->resultset('JobWaitFor')->search({wait_for_job_id=>$job_id});
  my $todo = [];
  while ( my $ds = $rs->next )   {
    $ds->job->update({state=>'skipped'});
    $self->clean_up_wait_for($ds->job->id);
  }
}

1;
