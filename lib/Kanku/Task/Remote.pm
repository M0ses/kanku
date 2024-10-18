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
package Kanku::Task::Remote;

=head1 NAME

Kanku::Task::Remote - Run task on specific worker

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

TODO - add a useful description

=head1 AUTHORS

Frank Schreiner, <fschreiner@suse.de>

=cut

use Moose;

with 'Kanku::Roles::Logger';

use Data::Dumper;
use JSON::XS;
use Try::Tiny;
use MIME::Base64;
use Carp;

has job => (
  is=>'rw',
  isa=>'Object',
);

has module => (
  is=>'rw',
  isa=>'Str',
);

has [qw/job_queue daemon/] => (
  is=>'rw',
  isa=>'Object',
);

has wait_for_workers => (
  is=>'ro',
  isa=>'Int',
  default=>1,
);

has final_args => (
  is=>'rw',
  isa=>'HashRef',
);

has rabbit_config => (
  is      => 'rw',
  isa     => 'HashRef',
  lazy    => 1,
  default => sub {
    Kanku::Config->instance->config->{'Kanku::RabbitMQ'} || {};
  },
);

has answer_key => (
  is=>'rw',
  isa=>'Str',
);


sub run {
  my ($self)      = @_;
  my $kmq         = $self->job_queue;
  my $all_workers = {};
  my $logger      = $self->logger;

  $logger->debug('Starting new remote task');

  my $job = $self->job;

  my $data = encode_json(
    {
      action => 'task',
      answer_key => $self->answer_key,
      job_id => $job->id,
      task_args => {
        job       => {
          context     => $job->context,
          name        => $job->name,
          id          => $job->id,
        },
        module      => $self->module,
        final_args  => {%{$self->final_args}, 'running_remotely'=>1},
      }
    }
  );

  $logger->debug('Sending remote job: '.$self->module);
  $logger->debug(' - channel: '.$kmq->channel);
  $logger->debug(' - routing_key '.$kmq->routing_key);
  $logger->debug(' - queue_name '.$kmq->queue_name);
  $logger->debug(' - answer_key '.$self->answer_key);
  $logger->trace(Dumper($data));

  $kmq->publish(
	$kmq->routing_key,
	$data,
  );

  $logger->debug('Waiting for result on queue: '.$self->job_queue->queue_name.'/'.$self->job_queue->routing_key);
  # Wait for task results from worker
  my $result;
  my $wait_for_answer = 10000;
  while (1){
    my $msg = $self->job_queue->recv($wait_for_answer);
    if ( $msg ) {
      my $indata;
      $logger->debug('Incoming task result');
      $logger->trace(Dumper($msg));
      my $body = $msg->{body};

      try {
	$indata = decode_json($body);
      } catch {
	$logger->debug("Error in JSON:\n$_\n$body\n");
      };

      $logger->debug("Received $indata->{action}");

      if (
	$indata->{action} eq 'finished_task' or
	$indata->{action} eq 'aborted_job'
      ) {
	$logger->trace("Content of \$data:\n".Dumper($data));
	if ( $indata->{error_message} ) {
	  croak($indata->{error_message});
	} else {
	  my $jobd = decode_json($indata->{job});
          $logger->trace('Content of $indata->result: '.Dumper($indata->{result}));

          try {
            $indata->{result}->{result} = decode_base64($indata->{result}->{result}) if ($indata->{result}->{result});
            $result = $indata->{result};
          } catch {
            $logger->fatal("Error while decoding base64: $_");
            $logger->debug(Dumper($indata));
            $indata->{result} = "Error while decoding base64: $_";
          };

	  $self->job->context($jobd->{context});
	  last;
	}
      } elsif ($indata->{action} eq 'apply_for_job') {
        $logger->warn("Got application from $indata->{worker_fqhn} for already running job($indata->{job_id}). Declining!");
        my $rmq = Kanku::RabbitMQ->new(%{$self->rabbit_config});
        $rmq->connect(no_retry=>1) ||
            $logger->error('Could not connect to rabbitmq');
        my $queue = $indata->{answer_key};
        $rmq->queue_name($queue);
        $rmq->publish(
          $queue,
          encode_json({action => 'decline_application'}),
        );
      }
    } else {
      $logger->trace("Got no answer within $wait_for_answer msec");
      if ($self->daemon->detect_shutdown) {
	croak('Job '.$job->id." aborted by dispatcher daemon shutdown\n");
      }
    }
  }
  return $result
}

__PACKAGE__->meta->make_immutable();

1;
