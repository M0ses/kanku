package Kanku::Cli::Rcomment::List;

use strict;
use warnings;

use MooseX::App::Command;
extends qw(Kanku::Cli);


with 'Kanku::Cli::Roles::Remote';
with 'Kanku::Cli::Roles::RemoteCommand';
with 'Kanku::Cli::Roles::View';
with 'Kanku::Roles::Helpers';

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
  default => 'todo.tt',
);


sub run {
  my ($self)  = @_;
  Kanku::Config->initialize;
  my $res = $self->_list;

  $self->print_formatted($self->list);

  return 0;
}

sub _list {
  my ($self)  = @_;
  my $logger  =	$self->logger;
  my $res     = 0;

  if (! $self->job_id ) {
    $logger->warn('Please specify a job_id');
    return 1;
  }

  my $kr;
  try {
    $kr = $self->connect_restapi();

    my $path = 'job/comment/'.$self->job_id;
    $logger->debug("Using path: $path");

    $res =  $kr->get_json( path => $path );
  } catch {
    $logger->error($_);
    $res = 1;
  };

  return $res
};

__PACKAGE__->meta->make_immutable;

1;
