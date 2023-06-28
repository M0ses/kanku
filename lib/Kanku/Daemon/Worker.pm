package Kanku::Daemon::Worker;

use Moose;

our $VERSION = "0.0.1";

use POSIX;
use JSON::XS;
use Try::Tiny;
use Sys::CPU;
use Sys::LoadAvg qw( loadavg );
use Sys::MemInfo qw(totalmem freemem);
use Carp;
use Net::Domain qw/hostfqdn/;
use UUID qw/uuid/;
use MIME::Base64;

use Kanku::RabbitMQ;
use Kanku::Config;
use Kanku::Task::Local;
use Kanku::Job;
use Kanku::Airbrake;
use Kanku::Util;

with 'Kanku::Roles::Logger';
with 'Kanku::Roles::ModLoader';
with 'Kanku::Roles::DB';
with 'Kanku::Roles::Daemon';
with 'Kanku::Roles::Helpers';

has child_pids            => (is=>'rw', isa => 'ArrayRef'
                              , default => sub {[]});
has worker_id             => (is=>'rw', isa => 'Str'
                              , default => sub {uuid()});

has kmq                   => (is=>'rw', isa => 'Object');
has remote_key_name => (is=>'rw', isa => 'Str');
has local_key_name  => (is=>'rw', isa => 'Str');

has hostname              => (is=>'rw',
                              isa => 'Str',
                              default => sub {
                                my $timeout = 300;
                                while ($timeout > 0) {
                                  my $hn = hostfqdn();
                                  return $hn if $hn;
                                  $timeout--;
                                  sleep 1;
                                }
                                my $msg = "Could not get hostname within $timeout sec";
                                $_[0]->logger->fatal($msg);
                                croak("$msg\n");
                              },
);

has arch => (
  is => 'rw',
  isa => 'Str',
  default => sub { return Kanku::Util::get_arch(); },
);

sub run {
  my $self          = shift;
  my $logger        = $self->logger();
  my @childs;
  my $pid;

  # for host queue
  $pid = fork();

  if (! $pid ) {
    my $hn = $self->hostname;
    $self->local_key_name($hn) if ($hn);
    $self->listen_on_queue(
      routing_key    => 'kanku.to_all_hosts',
    );
  } else {
    push(@childs,$pid);
  }

  # wait for advertisements
  $pid = fork();

  if (! $pid ) {
    $self->listen_on_queue(
      routing_key   => 'kanku.to_all_workers'
    );
  } else {
    push(@childs,$pid);
  }

  my $rabbit_config = Kanku::Config->instance->config->{'Kanku::RabbitMQ'};
  my $kmq = Kanku::RabbitMQ->new(%{$rabbit_config});
  $kmq->shutdown_file($self->shutdown_file);
  $kmq->connect();

  $kmq->publish(
    'kanku.to_dispatcher',
    encode_json({
      action        => 'started_worker',
      hostname      => $self->hostname,
    }),
  );

  while (@childs) {
    @childs = grep { waitpid($_,WNOHANG) == 0 } @childs;
    $logger->trace("Active Childs: (@childs)");

    $logger->trace("Sending heartbeat");
    $kmq->publish(
      'kanku.to_dispatcher',
      encode_json({
        action        => 'worker_heartbeat',
        hostname      => $self->hostname,
        current_time  => time(),
        active_childs => \@childs
      }),
    );

    sleep(1);
  }

  $kmq->publish(
    'kanku.to_dispatcher',
    encode_json({
      action        => 'shutdown_worker',
      hostname      => $self->hostname,
    }),
  );

  $kmq->queue->disconnect;

  $logger->info("No more childs running, returning from Daemon->run()!");
  return;
}

sub listen_on_queue {
  my ($self,%opts)  = @_;
  my $rabbit_config = Kanku::Config->instance->config->{'Kanku::RabbitMQ'};
  my $logger        = $self->logger();
  my $kmq;
  try {
    $kmq = Kanku::RabbitMQ->new(%{$rabbit_config});
    $kmq->shutdown_file($self->shutdown_file);
    $kmq->connect();
    $kmq->create_queue(
      routing_key   => $opts{routing_key},
    );
    $self->local_key_name($opts{routing_key});
  } catch {
    $logger->error("Could not create queue for exchange $opts{exchange_name}: $_");
  };
  my @seen;
  $logger->info("Starting worker process (arch: ".$self->arch.")");
  while(1) {
    try {
      my $msg = $kmq->recv(1000);
      if ($msg) {
	my $data;
	my $body = $msg->{body};
	# Extra try/catch to get better debugging output
	# like adding body to log message
	try {
          $logger->trace("Got message: $body");
	  $data = decode_json($body);
	} catch {
	  die("Error in JSON:\n$_\n$body\n");
	};

        $logger->debug('Got action from msg: ' . ($data->{action}||q{}));

	if ( $data->{action} eq 'send_task_to_all_workers' ) {
          $logger->trace('$data ='.$self->dump_it($data));
	  my $answer = {
	    action => 'task_confirmation',
	    task_id => $data->{task_id},
	    # answer_key is needed on dispatcher side
	    # to distinguish the results per worker host
	    answer_key => $self->local_key_name
	  };
	  $logger->debug($self->dump_it($data));
	  $self->remote_key_name($data->{answer_key});
	  $kmq->publish(
	    $self->remote_key_name,
	    encode_json($answer),
	  );

	  $self->handle_task($data,$kmq);
          $self->remote_key_name('');
	} elsif ( $data->{action} eq 'advertise_job' ) {
          my @seen_already = grep { $data->{job_id} == $_ } @seen;
          if (! @seen_already) {
            push @seen, $data->{job_id};
	    if ($data->{arch} eq $self->arch or $data->{arch} eq 'any') {
	      $logger->debug("arch matched $data->{arch} - handling advertisement");
              $self->handle_advertisement($data, $kmq);
	    } else {
	      $logger->debug("arch didn`t match. got $data->{arch} but have ".$self->arch);
            }
          } else {
	    $logger->debug("Duplicate job advertisment detected (job_id: $data->{job_id})");
          }
	} else {
	  $logger->warn("Unknown action: ". $data->{action});
	}
      } else {
        # reset @seen if queue is empty, to avoid memory leak
        # if no message there the queue might be empty and
        # no duplicates in the queue any more
        @seen = ();
      }
    } catch {
      $logger->error($_);
      #$self->airbrake->notify_with_backtrace($_, {context=>{pid=>$$,worker_id=>$self->worker_id}});
      if ($_ =~ /^(recv: a SSL error occurred|AMQP socket not connected)/) {
        try {
          $kmq->reconnect;
        } catch {
          $logger->error($_);
          die $_;
        };
      }
      sleep 1;
    };

    if ($self->detect_shutdown) {
      $logger->info("AllWorker process detected shutdown - exiting");
      exit 0;
    }
  }
}

sub handle_advertisement {
  my ($self, $data, $kmq) = @_;
  my $logger = $self->logger();

  $logger->debug("Starting to handle advertisement");

  if ( $data->{answer_key} ) {
      $logger->debug("\$data = ".$self->dump_it($data));
      $self->remote_key_name($data->{answer_key});
      my $job_id = $data->{job_id};
      $self->local_key_name("job-$job_id-".$self->worker_id);
      my $answer = "Process '$$' is applying for job '$job_id'";

      my $job_kmq = Kanku::RabbitMQ->new(
        %{$kmq->connect_info},
        routing_key => $self->local_key_name,
      );
      $job_kmq->connect();
      $job_kmq->create_queue();

      my $application = {
        job_id	      => $job_id,
        message	      => $answer ,
        worker_fqhn   => hostfqdn(),
        worker_pid    => $$,
        answer_key    => $self->local_key_name,
        resources     => collect_resources(),
        action        => 'apply_for_job'
      };
      $logger->debug("Sending application for job_id $job_id with routing_key ".$self->remote_key_name);
      $logger->trace("\$application =".$self->dump_it($application));

      my $json    = encode_json($application);
      $kmq->publish(
        $self->remote_key_name,
        $json,
      );

      # TODO: Need timeout
      my $timeout = 10 * 1000;
      $logger->debug("Waiting $timeout for offer_job (job_id: $job_id)");
      my $msg = $job_kmq->recv($timeout);
      if ( $msg ) {
        my $body = decode_json($msg->{body});
        if ( $body->{action} eq 'offer_job' ) {
          $logger->info("Starting with job ".$job_id);
          $logger->trace("\$msg =".$self->dump_it($msg));
          $logger->trace("\$body =".$self->dump_it($body));

          $self->handle_job($job_id,$job_kmq);
        } elsif ( $body->{action} eq 'decline_application' ) {
          $logger->debug("Nothing to do - application declined");
          $self->remote_key_name('');
          $self->local_key_name('');
        } else {
          $logger->error("Answer on application for job $job_id unknown");
          $logger->trace("\$msg =".$self->dump_it($msg));
          $logger->trace("\$body =".$self->dump_it($body));
        }
      } else {
          $logger->error("Got no answer for application (job_id: $job_id)");
          #$self->airbrake->notify_with_backtrace("Got no answer for application (job_id: $job_id)");
      }
      $job_kmq->destroy_queue();
  } else {
    $logger->error('No answer queue found. Ignoring advertisement');
    $logger->debug($self->dump_it($data));
  }

  return;
}

sub handle_job {
  my ($self,$job_id,$job_kmq) = @_;
  my $logger = $self->logger;

  $SIG{TERM} = sub {
    my $answer = {
	action        => 'aborted_job',
	error_message => "Aborted job because of TERM signal",
        job_id        => $job_id,
    };

    $logger->info("Sending 'aborted_job' because of TERM signal to routing_key'".$self->remote_key_name);

    $job_kmq->publish(
      $self->remote_key_name,
      encode_json($answer),
    );

    exit 0;
  };

  try  {
    my $task_wait = 10000;
    $logger->debug("Waiting $task_wait msec for tasks on queue: ".$job_kmq->queue_name." with routing_key: ".$job_kmq->routing_key);
    while (1){
      my $task_msg = $job_kmq->recv($task_wait);
      $logger->debug("Waiting for new task for job $job_id");
      if ( $self->detect_shutdown ) {
	my $answer = {
	    action        => 'aborted_job',
	    error_message => "Aborted job because of daemon shutdown",
            job_id        => $job_id,
	};

	$logger->info("Sending action 'aborted_job' because of daemon shutdown to routing_key '".$self->remote_key_name."'");

	$job_kmq->publish(
	  $self->remote_key_name,
	  encode_json($answer),
	);

	exit 0;
      }
      if ( $task_msg ) {
        $logger->trace("\$task_msg = $task_msg");
        my $task_body = decode_json($task_msg->{body});
        $logger->debug("Got new message while waiting for tasks");
        $logger->debug("task action/job_id: $task_body->{action}/".($task_body->{job_id}||'undef'));
        if (
           $task_body->{action} eq 'task' and $task_body->{job_id} == $job_id
        ){
          $logger->info("Job $task_body->{job_id} is starting task $task_body->{task_args}->{module}");
          $self->handle_task($task_body,$job_kmq,$job_id);
        }
        if ( $task_body->{action} eq 'finished_job' and $task_body->{job_id} == $job_id) {
          $logger->debug("Got finished_job for job_id: $job_id");
          return;
        }
        $logger->debug("Waiting for next task");
      }
    }
  } catch {
    my $e = $_;
    $logger->debug("EXCEPTION REFERENCE: ".ref($e));
    if ((ref($e) || '') =~ /^Moose::Exception::/ ) {
      $logger->debug("Converting exeption to string");
      $e = $e->trace->as_string;
    } elsif (( ref($e) || '') eq 'Sys::Virt::Error' ) {
      $logger->debug("Converting exeption 'Sys::Virt::Error' to string");
      $e = $e->message;
    }

    $logger->error($e);

    $job_kmq->publish(
      $self->remote_key_name,
      encode_json({
        action        => 'finished_task',
        error_message => $e
      }),
    );
    my $task_msg = $job_kmq->recv(10000);
    my $task_body = decode_json($task_msg->{body});
    if ( $task_body->{action} eq 'finished_job' and $task_body->{job_id} == $job_id) {
      $logger->debug("Got finished_job for job_id: $job_id");
    } else {
      $logger->debug("Unknown answer when waitingin for finish_job:");
      $logger->trace("\$task_body =".$self->dump_it($task_body));
    }
  };

  $logger->debug("Exiting handle_job for job_id: $job_id");

  return;
}

sub handle_task {
  my ($self, $data, $job_kmq, $job_id) = @_;

  confess "Got no task_args" if (! $data->{task_args});

  # create object from serialized data
  my $job = Kanku::Job->new($data->{task_args}->{job});
  $data->{task_args}->{job}=$job;

  my $task   = Kanku::Task::Local->new(%{$data->{task_args}},schema => $self->schema);

  my $result;
  try {
    $result = $task->run();
  } catch {
    $self->logger->error("An error occurred while running Task: $_");
    $result = {
      state         => 'failed',
      error_message => $_
    };
  };
  $self->logger->debug('Sending Task Result for job '.$job->id ." to routing_key ".$job_kmq->routing_key);
  $self->_send_task_result($job_kmq, $job, $result);
  return;
}

sub _send_task_result {
  my ($self, $job_kmq, $job, $result) = @_;
  my $logger = $self->logger;

  $logger->debug("Sending task result (state: $result->{state}) to ".$self->remote_key_name." ROUTINGKEY: ".$job_kmq->routing_key);

  $result->{result} = encode_base64($result->{result}) if ($result->{result});

  my $answer = {
      action        => 'finished_task',
      result        => $result,
      answer_key    => $self->local_key_name,
      job           => $job->to_json
  };

  $logger->trace("\$answer = ".$self->dump_it($answer));

  $job_kmq->publish(
    $self->remote_key_name,
    encode_json($answer),
  );

  return;
}

sub collect_resources {

  return {
	total_cpus	  => Sys::CPU::cpu_count(),
	free_cpus	  => Sys::CPU::cpu_count() - 1, # TODO - calculate how much CPU's used by running VM's
	total_ram	  => totalmem(),
	free_ram	  => freemem,
	load_avg	  => [ loadavg() ]
  }

}

__PACKAGE__->meta->make_immutable();
1;
