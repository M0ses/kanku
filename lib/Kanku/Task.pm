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
package Kanku::Task;

=head1 NAME

Kanku::Task - single task which executes a Handler

=cut

use Moose;
with 'Kanku::Roles::Logger';
with 'Kanku::Roles::ModLoader';

use Kanku::Config;
use Kanku::Job;
use Kanku::JobList;
use Kanku::Task::Local;
use Kanku::Helpers;
use JSON::XS;
use Try::Tiny;

=head1 ATTRIBUTES

=head2 schema    - a DBIx::Class::Schema object

=cut

has 'schema'     => (is=>'rw',isa=>'Object');

=head2 job       - a Kanku::Job object of parent job

=cut

has 'job'        => (is=>'rw',isa=>'Object');

=head2 scheduler - a Kanku::Daemon::Scheduler object

=cut

has 'scheduler'  => (is=>'rw',isa=>'Object');

=head2 module    - name of the Kanku::Handler::* module to be executed

=cut

has 'module'     => (is=>'rw',isa=>'Str');

=head2 description    - name of the Kanku::Handler::* module to be executed

=cut

has 'description'     => (is=>'rw', isa=>'Str', default => q{});

=head2 result      - Result of task in text form json encoded

=cut

has 'result'       => (is=>'rw',isa=>'Str',default=> '' );

=head2 state - TODO: add documentation

=cut

has 'state'       => (is=>'rw',isa=>'Str',default=> '' );

=head2 notify_queue - Kanku::NotifyQueue Object

=cut

has 'notify_queue'  => (is=>'rw',isa=>'Object' );

=head1 METHODS

=head2 run - TODO: add documentation

=cut

sub run {
  my ($self,$tr)  = @_;
  my $logger                        = $self->logger;
  my $schema                        = $self->schema();
  my $job                           = $self->job;
  my $handler                       = $self->module;
  my $scheduler                     = $self->scheduler;

  $logger->debug("Starting task with handler: $handler");

  my %out = ();
  my $jl          = Kanku::JobList->new(schema=>$schema);
  my $last_result = $jl->get_last_run_result(
                      $job->name,
                      $handler
                    );
  my $task_name = $handler.($self->description ? '('.$self->description.')' : q{});
  my $task = $schema->resultset('JobHistorySub')->create({
    job_id     => $job->id,
    name       => $task_name,
    state      => 'running',
    start_time => time(),
  });


  my $state  = undef;
  my $result = undef;

  # use only if rabbitmq is configured
  # not the case in devel mode
  if ( $self->notify_queue ) {
    $self->notify_queue->send({
      type          => 'task_change',
      event         => 'starting',
      message       => "Starting task (".$task->id.") from job (".$job->name."/".$job->id.")",
      id            => $task->id,
      job_id        => $job->id,
    });
  }

  # execute subtask
  try {

    my $mod = $handler;
    die "Now use_module definition in config (job: $job)" if ( ! $mod );

    $self->load_module($mod);

    my $last_run_result={};

    if ( $last_result && $last_result->result() ) {
      my $str = $last_result->result();
      $last_run_result = decode_json($str);
      $tr->last_run_result($last_run_result);
    }

    my $res = $tr->run();
    $logger->trace("Got result from task:\n".Kanku::Helpers->dump_it($res));
    $state  = $res->{state};
    if ($state eq 'failed') {
      $result = encode_json({error_message=>$res->{error_message}});
    } else {
      $result = $res->{result} ;
    }
  }
  catch {
    my $e = $_;
    $e = $e->stringify if (ref($e) eq 'Sys::Virt::Error');
    if (ref $e) {
      $logger->error(Kanku::Helpers->dump_it($e));
    } else {
      $logger->error($e);
    }
    if ($e) {
      $result = encode_json({error_message=>$e});
    } else {
      $result = "Unknown Result";
    }
    $state  = 'failed';
    $job->state($state);
  };

  $task->update({
    state    => $state,
    result   => $result,
    end_time => time(),
  });

  $job->update_db();

  $self->result($result);
  $self->state($state);

  # use only if rabbitmq is configured
  # not the case in devel mode
  if ( $self->notify_queue ) {
    $self->notify_queue->send({
      type          => 'task_change',
      event         => 'finished',
      result        => $state,
      id            => $task->id,
      job_id        => $job->id,
      message       => "Finished task (".$task->id.") with state '$state'",
    });
  }
  return $self;

}

__PACKAGE__->meta->make_immutable();
1;
