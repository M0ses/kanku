#!/usr/bin/perl

use Test::More tests => 2;
use File::Temp;
use FindBin;

my $fixtures_dir = "$FindBin::Bin/fixtures";
my $gpgkeys_pub  = "$fixtures_dir/gpgkeys.pub";

$::ENV{GNUPGHOME} = File::Temp::tempdir;
system("gpg -q --import $gpgkeys_pub");

use_ok('Kanku::GPG');

my $gpg = Kanku::GPG->new(
  message    => "Hallo Frank",
  recipients => ['frank@samaxi.de', 'adrian@suse.de'],
);
my $got = $gpg->encrypt;
ok($got =~ /^-----BEGIN\ PGP\ MESSAGE-----\n.*\n-----END\ PGP\ MESSAGE-----\n$/smx, "valid gpg message") || print $got;

exit 0;
