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
  [qw{0 0 db status --server}],
  [qw{0 1 ca create -p ./ca}],
  [qw{0 0 check_configs server}],
  [qw{0 0 login -a http://localhost:5000/kanku -u admin -p opensuse}],
  [qw{0 0 rworker list}],
  [qw{0 0 api gui_config/job.json}],
  [qw{0 0 rjob list}],
  [qw{0 0 rjob details --filter remove-domain}],
  [qw{0 0 rjob config remove-domain}],
  [qw{0 0 rguest list}],
  [qw{0 0 rhistory list}],
  [qw{0 0 rhistory details 1}],
  [qw{0 0 rcomment create 1 -m}, 'Comment 1'],
  [qw{0 0 rcomment create 1 -m}, 'Comment 2'],
  [qw{0 0 rcomment create 1 -m}, 'Comment 3'],
  [qw{0 0 rcomment list 1}],
  [qw{0 0 rcomment modify 2 -m}, "New comment 2"],
  [qw{0 0 rcomment delete 1}],
  [qw{0 0 logout}],
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
#    rr                    remove remote from your config
#    rtrigger              trigger a remote job or job group
