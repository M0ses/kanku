package Kanku::Cli::Rcomment::Delete;

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
  my $logger  =	$self->logger;

  my $res = $self->_delete();

  $self->print_formatted($res) if $res;

  return !$res;
}

sub _delete {
  my ($self)  = @_;
  my $logger  =	$self->logger;
  my $res     = 0;

  if (! $self->comment_id ) {
    $logger->warn('Please specify a comment_id (-C <comment_id>)');
    return 0;
  }

  try {
    my $kr = $self->connect_restapi();
    $res = $kr->delete_json( path => 'job/comment/'.$self->comment_id);
  } catch {
    $logger->fatal($_);
    $res = 0;
  };

  return $res;
};

__PACKAGE__->meta->make_immutable;

1;
