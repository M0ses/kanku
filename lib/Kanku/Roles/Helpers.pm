package Kanku::Roles::Helpers;

use Moose::Role;

use Carp;
use User::pwent;
use Data::Dumper;

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

1;
