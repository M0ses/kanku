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

#    login                 login to your remote kanku instance
#    logout                logout from your remote kanku instance
#    api                   make (GET) requests to api with arbitrary (sub) uri
#    check_configs server  Check kanku config files
#    pfwd                  Create port forwards for VM
#    rabbit                test rabbitmq
#    rcomment create       list job history on your remote kanku instance
#    rcomment delete       list job history on your remote kanku instance
#    rcomment list         list job history on your remote kanku instance
#    rcomment modify       list job history on your remote kanku instance
#    retrigger             retrigger a remote job given by id
#    rguest console        open console to guest on kanku worker via ssh
#    rguest list           list guests on your remote kanku instance
#    rguest ssh            ssh to kanku guest on your remote kanku instance
#    rhistory details      list job history on your remote kanku instance
#    rhistory list         list job history on your remote kanku instance
#    rjob config           show result of tasks from a specified remote job
#    rjob details          show result of tasks from a specified remote job
#    rjob list             show result of tasks from a specified remote job
#    rr                    remove remote from your config
#    rtrigger              trigger a remote job or job group
#    rworker list          information about worker


exit 0
