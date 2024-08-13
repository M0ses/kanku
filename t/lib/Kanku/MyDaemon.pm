package Kanku::MyDaemon;

use Moose;

with 'Kanku::Roles::Daemon';

sub run { 
  my ($self) = @_;
  my $logger = $self->logger;
  $logger->info(sprintf("Starting with pid %d at %d", $$, time()));
  my $c   = 0;
  while (1) {
    last if $self->detect_shutdown;
    $logger->trace("Counter: $c\n");
    sleep 1;
    $c++;
  } 
  $self->logger->info(sprintf("Ending with pid %d at %d", $$, time()));
  return 0;
}

1;
