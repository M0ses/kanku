package Kanku::Test::RabbitMQ;

use Moose;
use Net::AMQP::RabbitMQ;
use JSON::MaybeXS;
use Term::ANSIColor;

with 'Kanku::Roles::Helpers';

has config => (
   is     => 'rw',
   isa    => 'HashRef',
);

has channel => (
  is      => 'ro',
  isa     => 'Int',
  default => 1,
);

has connect_timeout => (
  is      => 'ro',
  isa     => 'Int',
  default => 60000,
);

has _mq => (
  is      => 'rw',
  isa     => 'Object',
);

has _queuename => (
  is      => 'rw',
  isa     => 'Str',
);

has logger => (
  is      => 'rw',
  isa     => 'Object',
);

has notification => (
  is      => 'rw',
  isa     => 'Str',
);

has notifications => (
  is      => 'rw',
  isa     => 'HashRef',
);

has output_plugin=> (
  is      => 'rw',
  isa     => 'Str',
);


sub connect {
  my ($self) = @_;
  my $logger = $self->logger;
  $self->_mq(Net::AMQP::RabbitMQ->new());

  $SIG{INT} = sub {
    $logger->warn("GOT SIG{INT}! Exiting ...");
    $self->_mq->disconnect if $self->_mq;
    exit 0;
  };
  my $cfg = $self->config;

  $logger->info("Connecting to $cfg->{host}");
  $self->_mq->connect(
    $cfg->{host},
    {
       timeout => $self->connect_timeout,
       %{$cfg->{settings} || {}}
    }
  );

  my $channel     = $self->channel;
  my $exchange    = $self->config->{exchange};
  my $routing_key = $self->config->{routing_key};

  $logger->info("Opening channel ".$self->channel);
  $self->_mq->channel_open($self->channel);

  return $self->_mq
};

sub listen {
  my ($self) = @_;
  my $logger = $self->logger;
  my $mq     = $self->_mq;
  my $cfg    = $self->config;
  my $wtime  = 1000;
  my $cnt    = 0;
  my $stime;
  my $etime;

  my $_output_plugins = {
    plain => sub {
      print " $_[0] KEY: $_[1]\n";
      print " $_[0] MSG: $_[2]\n";
    },
    notify => sub {
      my $msg = decode_json($_[2]);
      my $color_map = {
        succeed => 'green',
        failed  => 'red',
        warning => 'yellow',
      };
      my $c = $color_map->{$msg->{result}} || 'white';
      print Term::ANSIColor::color($c);
      printf("\n%s\n%s\n\n", $msg->{title} || q{}, $msg->{body} || q{});
      print Term::ANSIColor::color('reset');
    },
  };

  # Declare queue, letting the server auto-generate one and collect the name
  $logger->info("Declaring queue");
  $self->_queuename($self->_mq->queue_declare($self->channel, ""));

  # Bind the new queue to the exchange using the routing key
  $logger->info("Binding queue");
  $self->_mq->queue_bind(
    $self->channel,
    $self->_queuename,
    $cfg->{exchange},
    $cfg->{routing_key} || '',
  );

  $logger->info("Start consuming queue");
  # Request that messages be sent and receive them until interrupted
  $mq->consume($self->channel, $self->_queuename);

  my $output_plugin = $_output_plugins->{$self->output_plugin};
  die "No output_plugin ".$self->output_plugin."found!\n" if ! $output_plugin;

  $logger->debug("Using output plugin: ".$self->output_plugin);
  $logger->debug("Waiting for new messages ...");

  while (1) {
   $stime = time();
   while (my $msg = $mq->recv($wtime)) {
     $etime = time() - $stime; $stime=time();
     $output_plugin->(
       $etime,
       $msg->{routing_key},
       $msg->{body},
       $logger,
     );
   }
   $cnt++;
   $logger->trace("nothing found in last $wtime ms ($cnt sec elapsed)");
  }
}

sub send {
  my ($self) = @_;
  my $logger = $self->logger;
  my $mq     = $self->_mq;

   $logger->info("Sending notification: ".$self->notification);
  my $notification = $self->notifications->{$self->notification};
  if (! $notification ) {
    $logger->error(
      "Please choose a notification: <"
      . join('|', keys %{$self->notifications})
      . ">\n");
    return 1;
  }
  my $routing_key = $self->config->{routing_key} || '#';

  $logger->info($self->dump_it($notification));

  my $msg = encode_json($notification);

  $logger->info("Sending with routing key($routing_key): $msg");

  $mq->publish(
    $self->channel,
    $routing_key,
    $msg,
    {exchange => $self->config->{exchange}}
  );

  return 0;
}

=head1 KANKU NOTIFY FORMAT

{
  title  => "Kanku Status Notification",
  link   => 'notify',
  body   => "",
  result => "<failed|succeed|warning>",
};

=cut

sub props {
  my ($self) = @_;
  my $mq     = $self->_mq;

  $self->logger->error("Not implemented yet");
}

sub disconnect {
  my ($self) = @_;
  my $logger = $self->logger;
  $logger->info("Disconnecting from message queue");
  $self->_mq->disconnect;
}

1;
