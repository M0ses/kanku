package Kanku::GPG;

use Moose;
use Carp;
use IPC::Run qw( start pump finish timeout );

has recipients => (
  is      => 'rw',
  isa     => 'ArrayRef',
  lazy    => 1,
  default => sub {[]},
);

has message => (
  is      => 'rw',
  isa     => 'Str',
);

sub encrypt {
  my ($self) = @_;

  croak "Recipient list empty" unless @{$self->recipients};
  my @recipients = map { ("-r", $_) } @{$self->recipients};
  my @cmd = (qw/gpg -e -a --batch --trust-model always/, @recipients);
  my ($in, $out, $err);

  my $h = start \@cmd, \$in, \$out, \$err, timeout( 10 );

  $in = $self->message;
  finish $h or croak "command '@cmd' returned $?";

  return $out;         ## All of cat's output
}

1;
