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
package Kanku::Task::RemoteAll;

=head1 NAME

Kanku::Task::RemoteAll - TODO: comment

=head1 SYNOPSIS

 TODO: comment

=head1 DESCRIPTION

TODO: add a useful description

=head1 AUTHORS

Frank Schreiner, <fschreiner@suse.de>

=cut

use Moose;

our $VERSION = "0.0.1";

with 'Kanku::Roles::Logger';

use Data::Dumper;
use JSON::XS;
use Try::Tiny;
use MIME::Base64;


has kmq               => (is=>'rw',isa=>'Object');

has local_key_name    => (is=>'rw',isa=>'Str');

has job               => (is=>'rw',isa=>'Object');

has module            => (is=>'rw',isa=>'Str');

has final_args        => (is=>'rw',isa=>'HashRef');

has wait_for_workers  => (is=>'ro',isa=>'Int',default=>1);

has confirmations     => (is=>'rw',isa=>'HashRef',default=>sub {{}});

has results           => (is=>'rw',isa=>'HashRef',default=>sub {{}});


sub run {
  my ($self) = @_;
  my $kmq = $self->kmq;
  my $logger      = $self->logger;
  my $job         = $self->job;

  $logger->debug("Starting new remote-all task");

  my $data = encode_json(
    {
      action => 'send_task_to_all_workers',
      answer_key => $self->local_key_name,
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

  $logger->debug(Dumper($data));

  $kmq->publish('kanku.to_all_hosts', $data);

  sleep($self->wait_for_workers);

  # Getting response from workers, wait 10 sec to answer
  while ( my $msg = $self->kmq->recv(10000) ) {
    if ($msg ) {
      $logger->debug("Incomming message while waiting for confirmations");
      $self->_inspect_msg($msg);
    }
  }

  # Wait for task results from workers
  my $timeout = 60*60*2; # wait maximum 2 hours
  my $seconds_running=0;
  my $confirms = keys(%{$self->confirmations});
  my $results = keys(%{$self->results});

  $logger->debug("Number of confirms/results: $confirms/$results");

  while ( $confirms  > $results  ) {
    my $msg = $self->kmq->recv(10000);
    if ($msg) {
        $logger->debug("Got msg while waiting for task result:");
        $self->_inspect_msg($msg);
    }
    if( $seconds_running > $timeout) {
      $logger->warn("Reached timeout of $timeout seconds waiting for all workers to finish");
      last;
    }
    $confirms = keys(%{$self->confirmations});
    $results = keys(%{$self->results});
    $seconds_running++;
  }

  $self->logger->trace("all_workers task_results\n".Dumper($self->results));

  return $self->_calculate_results;

}

sub _calculate_results {
  my ($self) = @_;

  my $state     = 'succeed';
  my %aggregate = ();
  my @phases    = (qw/prepare execute finalize/);

  foreach my $host (keys(%{$self->results})){
    if ($self->results->{$host}->{result}->{state} eq 'failed') {
      $state='failed';
      $aggregate{error_message} .= "*** $host:\n" . $self->results->{$host}->{result}->{error_message};
    } else {
      for my $phase (@phases) {
        my $t_result = decode_json($self->results->{$host}->{result}->{result});
        $aggregate{$phase} .= "*** Host: $host: ***\n" . $t_result->{$phase}->{message};
      }
    }
  }

  if ($state eq 'failed') {
    return {
      state => $state,
      error_message => $aggregate{error_message}
    }
  } else {
    my $final_result = {};
    for my $phase (@phases) {
      $final_result->{$phase} = {
        message => "Aggregated results:\n$aggregate{$phase}",
        code    => 0
      };
    }

    return  {
      result => encode_json($final_result),
      state  => 'succeed'
    };
  }
}

sub _inspect_msg {
  my ($self,$msg) = @_;
  my $logger = $self->logger;
  my $data;
  $logger->trace(Dumper($msg));

  my $body = $msg->{body};
  try {
    $data = decode_json($body);
    try {
      $data->{result}->{result} = decode_base64($data->{result}->{result}) if ($data->{result}->{result});
      $logger->debug("Got action '".($data->{action}||q{})."', answer_key: '".($data->{answer_key}||q{})."'" );
    } catch {
      $logger->fatal("Error while decoding base64: $_");
      $logger->debug(Dumper($data));
      $data->{result} = "Error while decoding base64: $_";
    };
    if ( $data->{action} eq 'task_confirmation' ) {
      $self->confirmations()->{$data->{answer_key}} = $data;
    } elsif ( $data->{action} eq 'finished_task' ) {
      $self->results()->{$data->{answer_key}} = $data;
    }
  } catch {
    $logger->debug("Error in JSON:\n$_\n$body\n");
  };

}

__PACKAGE__->meta->make_immutable;
1;
