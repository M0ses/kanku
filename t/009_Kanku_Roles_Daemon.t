use strict;
use warnings;

use Test::More;
use FindBin;
use Path::Class::Dir;

use Kanku::Config;

my $skip_reason;

eval "use Test::Exception";

if ($@) {
  plan skip_all => "Could not use Test::Exception";
}

use Log::Log4perl;
BEGIN  {
  my $logging_conf = "$FindBin::Bin/etc/debugging.conf";
  Log::Log4perl->init($logging_conf);
};

plan tests => 6;

# avoid 'only used once'
my $xy = $FindBin::Bin;
use_ok('Kanku::MyDaemon');

{
  local @ARGV=("--non-existant-option");
  my $out;
  local *STDERR;
  open STDERR, '>', \$out or die "Can't open STDOUT: $!";

  throws_ok(
    sub  { Kanku::MyDaemon->new()->daemon_options() },
    qr/Usage:/,
    'Checking die if option unknown'
  );
}

for my $opt (qw/stop foreground/){
  local @ARGV=("--$opt");
  is_deeply(
    Kanku::MyDaemon->new()->daemon_options(),
    {$opt => 1},
    "Checking '--$opt' option"
  );
}

my $aliases =  {
  '-f' => 'foreground'
};

for my $alias (keys(%{$aliases})) {
  local @ARGV=($alias);
  my $opt = $aliases->{$alias};
  is_deeply(
    Kanku::MyDaemon->new()->daemon_options(),
    {$opt => 1},
    "Checking alias '$alias' for option '--$opt'"
  );
}

{
  Kanku::Config->initialize;
  my $tmpdir = File::Temp::tempdir(CLEANUP=>1);
  my $rundir = "$tmpdir/run/";
  my $dir    = Path::Class::Dir->new($rundir);
  $dir->mkpath;
  my $daemon = Kanku::MyDaemon->new(
    run_dir => $dir,
    logger  => Log::Log4perl->get_logger(""),
  );
  $daemon->prepare_and_run;
  $daemon->initialize_shutdown();
  my $shf = $rundir."009_Kanku_Roles_Daemon.t.shutdown";
  ok(
    ( -f $shf ),
    "Checking shutdown file"
  );
  unlink $shf;
}

exit 0;

