package Kanku::Cli::Rcomment::List;

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

option '+format' => (default => 'view');

has template => (
  is   => 'rw',
  isa  => 'Str',
  default => 'rcomment/list.tt',
);

parameter 'job_id' => (
    is            => 'rw',
    isa           => 'Int',
    required      => 1,
    documentation => q[Job id to create a comment for],
);

sub run {
  my ($self)  = @_;
  my $res = $self->_list;
  $self->print_formatted($res);
  return 0;
}

sub _list {
  my ($self)  = @_;
  my $logger  =	$self->logger;
  my $res     = 0;

  my $kr;
  try {
    $kr = $self->connect_restapi();

    my $path = 'job/comment/'.$self->job_id;
    $res =  $kr->get_json(path => $path);
  } catch {
    $logger->error($_);
    $res = 1;
  };

  return $res
};

__PACKAGE__->meta->make_immutable;

1;
