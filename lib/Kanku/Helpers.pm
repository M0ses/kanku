package Kanku::Helpers;

use Carp;
use User::pwent;
use Data::Dumper;
use IPC::Run qw/run/;


sub dump_it {
    my ($self, @data) = @_;
    my $d = Data::Dumper->new(\@data);
    $d
      ->Indent(0)
      ->Terse(1)
      ->Sortkeys(1)
      ->Quotekeys(0)
      ->Deparse(1);

    return $d->Dump();
}

sub my_home {
  return $::ENV{HOME}
        || getpwuid($<)->dir
        || croak("Could not determine home for current user id: $<\n");
}

sub users_home {
  my ($self, $u) = @_;
  croak('Can`t continue without user name') unless $u;
  my $pw   = getpwnam($u) || croak("User $u not found");
  return $pw->dir;
}

sub run_cmd {
  my ($self, $cmd, $logger) = @_;
  my @io=('', '', '');
  $logger->debug("CMD: @$cmd") if ($logger);
  run $cmd , \$io[0], \$io[1], \$io[2] || die "git $?\n";
  $logger->debug("CMD OUTPUT: $io[1]") if ($logger);
  $logger->debug("CMD ERROR: $io[1]") if ($logger);
  return @io;
}

1;
