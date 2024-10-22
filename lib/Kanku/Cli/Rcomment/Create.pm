package Kanku::Cli::Rcomment::Create;

use strict;
use warnings;

use MooseX::App::Command;
extends qw(Kanku::Cli);


with 'Kanku::Cli::Roles::Remote';
with 'Kanku::Cli::Roles::RemoteCommand';
with 'Kanku::Cli::Roles::View';

use Term::ReadKey;
use POSIX;
use Try::Tiny;
use Data::Dumper;

command_short_description 'list job history on your remote kanku instance';

command_long_description  "
With this command you can list/create/show/modify/delete comments in the job history
on your remote kanku instance.

";

option 'job_id' => (
  isa           => 'Int',
  is            => 'rw',
  cmd_aliases   => 'j',
  documentation => 'job id',
);

option 'comment_id' => (
  isa           => 'Int',
  is            => 'rw',
  cmd_aliases   => 'C',
  documentation => 'comment id',
);

option 'message' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'm',
  documentation => 'message',
);

option '+format' => (default => 'pjson');

has template => (
  is   => 'rw',
  isa  => 'Str',
  default => '',
);


sub run {
  my ($self)  = @_;
  Kanku::Config->initialize;
  my $res     = $self->_create();

  $self->print_formatted($res);

  return !$res;
}

sub _create {
  my ($self)  = @_;
  my $logger  =	$self->logger;
  my $res     = 0;

  if (! $self->job_id ) {
    $logger->warn('Please specify a job_id (-j <job_id>)');
    return $res;
  }

  if (! $self->message ) {
    $logger->warn('Please specify a comment message (-m "my message")');
    return $res;
  }

  try {
    my $kr = $self->connect_restapi();
    $res = $kr->post_json(
      path => 'job/comment/'.$self->job_id, 
      data => {message => $self->message},
    );
  } catch {
    $logger->fatal($_);
    $res = 0;
  };

  return $res;
};

__PACKAGE__->meta->make_immutable;

1;
