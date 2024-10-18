package Kanku::File;

use strict;
use warnings;

use Carp;
use Path::Tiny qw/path cwd/;
use English qw/-no_match_vars/;

sub lookup_file {
  shift @_ if ref($_[0]);
  my ($file) = @_;
  croak("No file given.") unless $file;
  my $bn = path($file)->basename;
  my $dn = path($file)->dirname || cwd;
  $dn = path(cwd, $dn) unless substr($dn, 0, 1) eq q{/};
  return path($dn, $bn)->realpath;
}

sub chown {
  my  ($user, @files) = @_;
  my ($login, $pass, $uid, $gid) = getpwnam $user;
  $login || croak("User '$user' not known\n");

  for my $fn (@files) {
    chown $uid, $gid, $fn || croak($OS_ERROR);
  }

  return;
}

1;
