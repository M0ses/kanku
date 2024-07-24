use strict;
use warnings;

use Cwd;
use FindBin;
use File::Basename;
use Test::More;

my $path_to_kankufile = Cwd::realpath($FindBin::Bin.'/../KankuFile');
my %test_cases = (
  'KankuFile' => $path_to_kankufile,
  './t/fixtures/LinkAbsolutePath' => '/etc/passwd',
  './t/fixtures/LinkRelativePath' => $path_to_kankufile,
  './t/fixtures/LinkToLink' => $path_to_kankufile,
  '/etc/passwd' => '/etc/passwd',
);
my $tests = 1 + keys(%test_cases);

plan tests => $tests;

use_ok 'Kanku::File';

while ( my ($in, $expected) = each(%test_cases)) {
  my $bn = basename($in);
  my $got = Kanku::File::lookup_file($in);
  is($got, $expected, "lookup_file: $bn");
}

exit 0;
