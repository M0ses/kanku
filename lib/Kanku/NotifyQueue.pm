package Kanku::NotifyQueue;

use Moose;
use Kanku::Config;
use Kanku::NotifyQueue::RabbitMQ;
use Kanku::NotifyQueue::Dummy;

sub new {
  my ($self, @args) = @_;
  my $config = Kanku::Config->instance()->config;

  if (ref($config->{'Kanku::RabbitMQ'})) {
    return Kanku::NotifyQueue::RabbitMQ->new(@args);
  }
  return Kanku::NotifyQueue::Dummy->new(@args);
}

1;
