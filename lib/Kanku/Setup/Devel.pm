package Kanku::Setup::Devel;

use Moose;
use Carp;
use Path::Tiny;
use English qw/-no_match_vars/;

use Kanku::Util;
use Kanku::File;
use Kanku::Roles::Helpers;

with 'Kanku::Setup::Roles::Common';
with 'Kanku::Roles::Logger';

has homedir => (
    isa           => 'Str',
    is            => 'rw',
    lazy          => 1,
    builder       => '_build_homedir',
);
sub _build_homedir {
  return $_[0]->users_home($_[0]->user);
}

has _dbfile => (
        isa     => 'Str',
        is      => 'rw',
        lazy    => 1,
	builder => '_build__dbfile',
);
sub _build__dbfile {
  return $_[0]->homedir.'/.kanku/kanku-schema.db'
}

has apiurl => (
  isa    => 'Str',
  is     => 'rw',
);

has osc_user => (
  isa     => 'Str',
  is      => 'rw',
  lazy    => 1,
  default => q{},
);

has osc_pass => (
  isa     => 'Str',
  is      => 'rw',
  lazy    => 1,
  default => q{},
);

sub setup {
  my $self    = shift;
  my $logger  = $self->logger;

  $logger->debug('Running developer setup');

  # ask for user
  $self->_ask_for_user if ( ! $self->user );

  $self->_create_local_settings_dir();

  $self->_set_sudoers();

  $self->_backup_config_file("/etc/group");

  $self->_configure_libvirtd_access(user=>$self->user);

  $self->_setup_database();

  $self->_create_osc_rc();

  $self->_create_default_pool;

  $self->_create_default_network;

  $self->_setup_nested_kvm;
  my $home  = Kanku::Helpers->users_home($self->user);
  my $gconf = "$home/.kanku/kanku-config.yml";

  $self->_backup_config_file($gconf);

  my $arch = Kanku::Util::get_arch();
  my $arch2repo = {
    x86_64  => 'devel:kanku:images',
    aarch64 => 'devel:kanku:images:aarch64',
  };

  $self->_create_config_from_template(
    "kanku-config.yml.tt2",
    $gconf,
    {
       use_publickey  => 0,
       distributed    => 0,
       cache_dir      => "$home/.cache/kanku",
       arch           => $arch,
       official_image_repo => $arch2repo->{$arch},
       host_interface => $self->host_interface,
    }
  );

  my ($user, $passwd, $uid, $gid ) = getpwnam($self->user);
  chown($uid, $gid, $gconf) || die "Could not chown ($uid, $gid, $gconf): $!\n";

  $logger->info('Developer mode setup successfully finished!');
  $logger->info('Please reboot to make sure, libvirtd is coming up properly');
  return;
}

sub _create_osc_rc {
  my $self  = shift;

  my $rc        = path($self->homedir,'.config/osc/oscrc');
  my $rc_old    = path($self->homedir,'.oscrc');

  return 0 if ($rc_old->exists);
  return 0 if ($rc->exists);

  my $choice = $self->_query_interactive(<<'EOF'
No oscrc found in your home!
Should it be created (y|N)
EOF
,
    0,
    'Bool',
  );

  return 0 unless $choice;

  $rc->parent->mkdir;

  if ( ! $self->apiurl ) {
     my $default = 'https://api.opensuse.org';
     print "Please enter the apiurl of your obs server [$default]\n";
     my $read = <>;
     chomp $read;
     $self->apiurl($read || $default);
  }

  while ( ! $self->osc_user ) {

     print "Please enter your login user for obs server:\n";
     my $read = <>;
     chomp $read;
     $self->osc_user($read || q{});
  }

  while ( ! $self->osc_pass ) {

     print "Please enter your password for obs server:\n";
     ReadMode('noecho');
     my $read = <>;
     chomp $read;

     ReadMode(0);
     print "Please repeat your password\n";
     ReadMode('noecho');
     my $read2 = <>;
     chomp $read2;
     ReadMode(0);

     $self->osc_pass($read || q{}) if ( $read eq $read2 );
  }

  my $rc_txt = <<'EOF'
[general]
apiurl = ".$self->apiurl."

[".$self->apiurl."]
user = ".$self->osc_user."
pass = ".$self->osc_pass."
EOF
;

  $rc->spew($rc_txt);
  Kanku::File::chown($self->user, $rc);
  return 0;
}

sub _create_local_settings_dir {
  my ($self) = @_;

  my $dir  = path($self->homedir,'.kanku');

  $dir->mkdir();

  return Kanku::File::chown($self->user, $dir);
}

sub _ask_for_user {
  my $self = shift;
  my $default_user = ($ENV{SUDO_USER} || $ENV{USER});

  while ( ! $self->user ) {
    print "Please enter the username of the user who will run kanku [$default_user]\n";

    my $answer = <STDIN>;
    chomp $answer;
    $self->user( $answer || $default_user );
  }

  return 0;
}

1;
