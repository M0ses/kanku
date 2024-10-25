#!/usr/bin/perl
#


use strict;
use warnings;
use FindBin;
use Test::More;
use Path::Tiny qw/path tempdir/;

my $basename = path($0)->basename;
my $basedir  = $FindBin::Bin;
my $logdir   = path("$basedir/log");
my $logfile  = path("$logdir/$basename.log");
my $tempbase = path("$basedir/tmp");
my $cwd      = Path::Tiny->cwd;

$logdir->mkdir unless $logdir->exists;
$tempbase->mkdir unless $tempbase->mkdir;

$logfile->spew(q{});

my @kanku_opts=qw/--loglevel TRACE/;

my @tcs = (
  # noopts, sudo, @cmd
  [qw{0 0 db status}],
  [qw{1 0 bash_completion}],
  [qw{0 0 init}],
  [qw{0 0 init -t vagrant --box debian/bullseye64 --kankufile KankuFile.bullseye64}],
  [qw{0 1 ca create -p ./ca}],
  [qw{0 0 check_configs devel}],
  [qw{0 0 db install -d --dsn dbi:SQLite:dbname=./test.db}],
);

plan tests => scalar(@tcs);

my $tmpdir = tempdir(DIR=>$tempbase);
chdir $tmpdir;

for my $tc (@tcs) {
  test_kanku_cli(@{$tc});
}

chdir $cwd;

exit 0;

sub test_kanku_cli {
  my ($noopts, $sudo, @opts) = @_;
  my @cmd = ('kanku', @opts);
  push @cmd, @kanku_opts unless $noopts;
  unshift @cmd,'sudo' if $sudo;
  my @results = `@cmd 2>&1`;
  $logfile->append(@results);
  ok($?==0, "Checking '@cmd'");
}

__END__
# ????? How to implement? ?????
#    console               Open a serial console to vm
#
#
# !!!!! TODO !!!!
#    db install -s            Initialize database
#    db status -s             Status of database
#    db upgrade -s           Upgrade database
#    list                  Not implemented yet
#    lsi                   list standard kanku images
#    snapshot create       Create snapshot of kanku vm
#    snapshot list         list snapshots of kanku vms
#    snapshot remove       manage snapshots for kanku vms
#    snapshot revert       revert snapshots of kanku vms
#    startui               start an simple webserver to access web ui under
#                          http://localhost:5000
#    startvm               Start kanku VM
#    stopui                stop local webserver
#    stopvm                Stop kanku VM
#    urlwrapper            open kanku url (kanku:// or kankus://)
