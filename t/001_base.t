use strict;
use warnings;
use FindBin;
use File::Find;
use Test::More;
use Data::Dumper;

#my @exclude = qw/Kanku Kanku::Daemon::Worker Kanku::REST/;
my %preflight = (
  'Dancer2::Plugin::WebSocket' => [qw/Kanku Kanku::REST/],
  'Sys::CPU'                   => [qw/Kanku::Daemon::Worker/],
  'Net::NSCA::Client'          => [qw/Kanku::Notifier::NSCA/],
  'Net::NSCAng::Client'        => [qw/Kanku::Notifier::NSCAng/],
);
my @not_ready_to_test = qw/Kanku::Config::KankuFile/;
my @exclude = @not_ready_to_test;
while (my ($pm, $ex) = each(%preflight)) {
  eval "use $pm;";
  push @exclude, @$ex if $@;
}

my $search_path = "$FindBin::Bin/../lib/";
my @pm_files;

sub filter_pm_files {
  if ($File::Find::name =~ /$search_path(.*)\.pm$/smx) {
    my $pm = ($1 =~ s{/}{::}rg);
    my @found = grep { $_ eq $pm } @exclude;
    push @pm_files, $pm unless @found;
  }
}

find(\&filter_pm_files, $search_path);
plan tests => scalar(@pm_files);

for my $pm (sort @pm_files) {
  use_ok $pm;
}

exit 0;
