package Kanku::Cli::rcomment; ## no critic (NamingConventions::Capitalization)

use strict;
use warnings;

use MooseX::App::Command;
extends qw(Kanku::Cli);

with 'Kanku::Roles::Logger';

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

option 'create' => (
  isa           => 'Bool',
  is            => 'rw',
  cmd_aliases   => 'c',
  documentation => '(*) create comment with "message"',
);

option 'show' => (
  isa           => 'Bool',
  is            => 'rw',
  cmd_aliases   => 's',
  documentation => '(*) show comment',
);

option 'modify' => (
  isa           => 'Bool',
  is            => 'rw',
  cmd_aliases   => 'M',
  documentation => '(*) Modify comment',
);

option 'delete' => (
  isa           => 'Bool',
  is            => 'rw',
  cmd_aliases   => 'D',
  documentation => '(*) Delete comment',
);

BEGIN {
  Kanku::Config->initialize;
}

sub run {
  my ($self)  = @_;
  my $logger  =	$self->logger;
  my $res;

  if ($self->list) {
    $res = $self->_list;
  } elsif ($self->create) {
    $res = $self->_create();
  } elsif ($self->modify) {
    $res = $self->_modify();
  } elsif ($self->delete) {
    $res = $self->_delete();
  }

  if ($res) {
    $self->print_formatted($self->format, $self->list);
    return 0;
  }

  $logger->warn('Please specify a command. Run "kanku rcomment --help" for further information.');
  return 1;
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

sub _create {
  my ($self)  = @_;
  my $logger  =	$self->logger;
  my $res     = 0;

  if (! $self->job_id ) {
    $logger->warn('Please specify a job_id (-j <job_id>)');
    return 1;
  }

  if (! $self->message ) {
    $logger->warn('Please specify a comment message (-m "my message")');
    return 1;
  }

  try {
    my $kr = $self->connect_restapi();
    my %params = (message => $self->message);
    $kr->post_json( path => 'job/comment/'.$self->job_id, data => \%params );
  } catch {
    $logger->fatal($_);
    $res = 1;
  };

  return $res;
};

sub _modify {
  my ($self)  = @_;
  my $logger  =	$self->logger;
  my $res     = 0;

  if (! $self->comment_id ) {
    $logger->warn('Please specify a comment_id (-C <comment_id>)');
    return 1;
  }

  if (! $self->message ) {
    $logger->warn('Please specify a comment message (-m "my message")');
    return 1;
  }

  try {
    my $kr = $self->connect_restapi();
    my %params = (message => $self->message);
    $kr->put_json( path => 'job/comment/'.$self->comment_id, data => \%params );
  } catch {
    $logger->fatal($_);
    $res = 1;
  };


  return $res;
};

sub _delete {
  my ($self)  = @_;
  my $logger  =	$self->logger;
  my $res     = 0;

  if (! $self->comment_id ) {
    $logger->warn('Please specify a comment_id (-C <comment_id>)');
    return 1;
  }

  try {
    my $kr = $self->connect_restapi();
    $kr->delete_json( path => 'job/comment/'.$self->comment_id);
  } catch {
    $logger->fatal($_);
    $res = 1;
  };

  return $res;
};

__PACKAGE__->meta->make_immutable;

1;
