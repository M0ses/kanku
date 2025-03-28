package Kanku::Cli::Rcomment::Create;

use strict;
use warnings;

use MooseX::App::Command;
extends qw(Kanku::Cli);


with 'Kanku::Cli::Roles::Remote';
with 'Kanku::Cli::Roles::View';

use Try::Tiny;

command_short_description 'list job history on your remote kanku instance';

command_long_description  "
With this command you can list/create/show/modify/delete comments in the job history
on your remote kanku instance.

";

parameter 'job_id' => (
    is            => 'rw',
    isa           => 'Int',
    required      => 1,
    documentation => q[Job id to create a comment for],
);

option 'message' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'm',
  documentation => 'message',
);

option '+format' => (default => 'view');

has template => (
  is   => 'rw',
  isa  => 'Str',
  default => 'rcomment/create.tt',
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
