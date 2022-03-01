# Copyright (c) 2018 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program (see the file COPYING); if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#
package Kanku::Setup::Roles::Common;

use Moose::Role;
use Path::Class qw/file/;
use Sys::Virt;
use IPC::Run qw/run timeout/;
use Path::Class qw/dir file/;
use Carp;
use English qw/-no_match_vars/;
use Const::Fast;
use File::Which;
use File::Copy;
use Template;

const my $MAX_NETWORK_NUMBER => 255;

requires 'setup';

has _tt_config => (
  is => 'ro',
  isa => 'HashRef',
  lazy => 1,
  default => sub {
    {
      INCLUDE_PATH => '/etc/kanku/templates/cmd/setup',
      INTERPOLATE  => 1,               # expand "$var" in plain text
    };
  },
);

has logger => (
  isa   => 'Object',
  is    => 'rw',
  lazy  => 1,
  default => sub { Log::Log4perl->get_logger },
);

has user => (
  isa   => 'Str|Undef',
  is    => 'rw',
);

has dsn => (
  isa   => 'Str',
  is    => 'rw',
  lazy  => 1,
  default => sub { 'dbi:SQLite:dbname='.$_[0]->_dbfile },
);

has _devel => (
  isa   => 'Bool',
  is    => 'ro',
);

has _distributed => (
  isa     => 'Bool',
  is      => 'rw',
  lazy    => 1,
  default => 0,
);

has interactive => (
  isa     => 'Bool',
  is      => 'rw',
  lazy    => 1,
  default => 0,
);

has dns_domain_name => (
    isa           => 'Str',
    is            => 'rw',
    default       => 'kanku-devel',
);

has network_name => (
    isa           => 'Str',
    is            => 'rw',
    lazy          => 1,
    default       => sub { $_[0]->_distributed ? 'kanku-ovs' : 'kanku-devel'},
);

sub _configure_libvirtd_access { ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
  my ($self, %opts) = @_;
  my $logger        = $self->logger;

  $self->_configure_qemu_config if $self->_devel;

  my $choice = $self->_query_interactive(<<'EOF'

Should libvirt be reconfigured to run with unix sockets?
This might be required to control VM`s without entering a password.

Your choice (Y|n)?
EOF
,
    1,
    'Bool',
  );

  return unless $choice;

  my $dconf = file('/etc/libvirt/libvirtd.conf');

  $self->_backup_config_file($dconf);

  my @lines = $dconf->slurp;
  my $user  = $opts{user};
  my $group = 'libvirt';
  my $defaults = {
    unix_sock_group         => $group,
    unix_sock_ro_perms      => '0777',
    unix_sock_rw_perms      => '0770',
    unix_sock_admin_perms   => '0700',
    auth_unix_ro            => 'none',
    auth_unix_rw            => 'none',
  };
  my $seen={};
  my $regex = '^#?(('.join(q{|}, keys %{$defaults}).').*)';
  for my $line (splice @lines) {
    if ( $line =~ s/$regex/$2 = '$defaults->{$2}'/ ) {
      $seen->{$2} = 1;
    }
    push @lines, $line;
  }

  for my $key (keys %{$defaults}) {
    push @lines, "$key = \"$defaults->{$key}\"\n" unless $seen->{$key};
  }

  $dconf->spew(\@lines);

  # add user to group libvirt
  if ($user) {
    if (
      $self->_run_system_cmd('usermod', '-aG', $group, $user)->{return_code}
   ) {
      die "Error while adding user $user to group $group!\n";
   }
  }

  if (
    $self->_run_system_cmd('systemctl', 'enable', 'libvirtd')->{return_code}
  ) {
    die "Error while enabling libvirtd\n";
  }

  if (
    $self->_run_system_cmd('systemctl', 'restart', 'libvirtd')->{return_code}
  ) {
    die "Error while restarting libvirtd\n";
  }

  return;
}

sub _configure_qemu_config {
  my ($self) = @_;
  my $logger = $self->logger;
  my $user   = $self->user;

  my $choice = $self->_query_interactive(<<'EOF'
Should libvirt be reconfigured run qemu under your user ($user)?
This is required for shared folder to work smoothly between host and guest.

Your choice (Y|n)?
EOF
,
    1,
    'Bool',
  );

  return unless $choice;

  my $conf = file('/etc/libvirt/qemu.conf');

  $logger->debug("Setting user $user in ". $conf->stringify);
  $self->_backup_config_file($conf);
  my @lines = $conf->slurp;

  for my $line (splice @lines) {
    $line =~ s/^#?(user\s*=\s*).*/$1"$user"/;
    push @lines, $line;
  }

  $conf->spew(\@lines);

  return;
}

sub _create_default_pool {    ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
  my $self    = shift;
  my $logger  = $self->logger;
  my $vmm     = Sys::Virt->new(uri => 'qemu:///system');
  my @pools   = $vmm->list_storage_pools();
  my $choice;

  for my $pool (@pools) {
    if ($pool->get_name eq 'default') {
      $logger->info('Found pool default - enabling autostart');
      $choice = $self->_query_interactive(<<'EOF'
Should autostart for libvirt pool "default" be enabled?

Your choice (Y|n)?
EOF
,
        1,
        'Bool',
      );
      return 0 unless $choice;
      $pool->set_autostart(1);
      return 1;
    }
  }

  $logger->info('No pool named "default" found - creating');
  $choice = $self->_query_interactive(<<'EOF'
Should libvirt pool "default" be created?

Your choice (Y|n)?
EOF
,
    1,
    'Bool',
  );

  return 0 unless $choice;
  my $xml = file($self->_tt_config->{INCLUDE_PATH},'pool-default.xml')->slurp;
  my $pool = $vmm->define_storage_pool($xml);
  $pool->create();
  $pool->set_autostart(1);

  return 0;
}

sub _create_default_network {    ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
  my $self     = shift;
  my $logger   = $self->logger;
  my $vmm      = Sys::Virt->new(uri => 'qemu:///system');
  my @networks = $vmm->list_all_networks;
  my $nn       = $self->network_name();

  for my $net (@networks) {
    if ($net->get_name eq $nn) {
      $logger->info("Found network '$nn' - enabling autostart");
      my $choice = $self->_query_interactive(<<"EOF"
Should autostart for libvirt net '$nn' be enabled and started?

Your choice (Y|n)?
EOF
,
        1,
        'Bool',
      );
      return unless $choice;
      $net->set_autostart(1) unless $net->get_autostart;
      $net->create() unless $net->is_active;
      return;
    }
  }

  my $ttf = "net-$nn.xml.tt2";
  $logger->info("No network named '$nn' found - creating using '$ttf'");

  my $choice = $self->_query_interactive(<<'EOF'
    "Should libvirt net '$nn' be created?

Your choice (Y|n)?
EOF
,
    1,
    'Bool',
  );

  return unless $choice;

  my $dns_domain_name = $self->_query_interactive(<<'EOF'
    "Should libvirt net '$nn' be created?

Your choice ?
EOF
,
    $self->dns_domain_name,
    'Str',
  );

  my $rnd = rand $MAX_NETWORK_NUMBER;
  my $sn  = int $rnd;
  my $xml = $self->_create_config_from_template($ttf, undef, {subnet=>$sn, dns_domain_name=>($dns_domain_name)});
  my $net = $vmm->define_network($xml);
  $net->set_autostart(1);
  $net->create();

  return;
}

sub _create_config_from_template {
  my ($self, $tt_file, $cfg_file, $vars) = @_;
  my $template  = Template->new($self->_tt_config);
  my $output = q{};

  # process input template, substituting variables
  if ($cfg_file) {
    $template->process($tt_file, $vars, $cfg_file)
               || croak($template->error()->as_string());
    $self->logger->info("Created config file $cfg_file");
  } else {
    $template->process($tt_file, $vars, \$output)
               || croak($template->error()->as_string());
  }
  return $output;
}

sub _run_system_cmd {    ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
  my ($self, $cmd, @opts) = @_;
  my $logger = $self->logger;

  $logger->debug("Running command '$cmd @opts'");
  my ($in,$out,$err);
  run [$cmd, @opts], \$in, \$out, \$err;

  if ($CHILD_ERROR) {
    $logger->error('Execution of command failed: "'.($err || q{}).q{"});
  }

  return {
    return_code => $CHILD_ERROR,
    stderr      => $err,
    stdout	=> $out,
  };
}

sub _chown {
  my  ($self, @opts) = @_;
  my ($login,$pass,$uid,$gid) = getpwnam $self->user;
  $login || croak($self->user." not in passwd file\n");

  while (my $fn = shift @opts) {
    $self->logger->debug("_chown '$fn' ($uid/$gid)");
    chown $uid, $gid, $fn || croak($OS_ERROR);
  }

  return;
}

sub _set_sudoers {     ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
  my $self          = shift;
  my $user          = $self->user;
  my $logger        = $self->logger;

  my $choice = $self->_query_interactive(<<'EOF'
Should we add user $user to the sudoers to be able to execute iptables/netstat/ss as root?
This is required if you want to use portforwarding from host to guests!
(Y|n)
EOF
,
    1,
    'Bool',
  );

  if ($choice) {
    my $sudoers_file  = file('/etc/sudoers.d/kanku');
    $logger->info("Adding commands for user $user in " . $sudoers_file->stringify);
    my @tcmd;
    for my $cmd (qw/iptables ss netstat/) {
      my $cmdpath = which($cmd);
      push @tcmd, $cmdpath if $cmdpath;
    }
    $sudoers_file->spew("$user ALL=NOPASSWD: ".join(',', @tcmd)."\n");
  }

  return;
}

sub _setup_database {    ## no critic (Subroutines::ProhibitUnusedPrivateSubroutines)
  my ($self) = @_;

  # create Template object
  my $template  = Template->new($self->_tt_config);

  # define template variables for replacement
  my $vars = {
    dsn           => $self->dsn,
    start_tag     => '[%',
    end_tag       => '%]',
  };

  my $output = q{};
  my $cfg_file = '/etc/kanku/dancer/config.yml';

  # process input template, substituting variables
  $template->process('dancer-config.yml.tt2', $vars, $cfg_file)
               || croak($template->error()->as_string());

  $self->logger->info("Created config file $cfg_file");

  $self->logger->debug('Using dsn: '.$self->dsn);
  # prepare database setup
  my $migration = DBIx::Class::Migration->new(
    schema_class   => 'Kanku::Schema',
    schema_args    => [$self->dsn],
    target_dir     => '/usr/share/kanku',
  );

  # setup database if needed
  $migration->install_if_needed(default_fixture_sets => ['install']);

  $self->_chown($self->_dbfile);

  return;
}

sub _setup_nested_kvm {
  my ($self) = @_;
  my $pfile;
  my $kmod;
  if ( -f "/sys/module/kvm_intel/parameters/nested" ) {
    $pfile = "/sys/module/kvm_intel/parameters/nested";
    $kmod  = "kvm_intel";
  } elsif ( -f "/sys/module/kvm_amd/parameters/nested" ) {
    $pfile = "/sys/module/kvm_amd/parameters/nested";
    $kmod  = "kvm-amd";
  } elsif ( -d "/sys/module/kvm/" ) {
    $self->logger->info("Could not determine cpu type (intel/amd), but found kvm!");
    return;
  } else {
    die "No proper cpu type found!\n";
  }

  open(P, '<', $pfile) || die "Could not open $pfile: $!\n";
  my @p = <P>;
  close P;

  chomp $p[0];

  return if ( $p[0] eq 'Y');

  $self->_backup_config_file("/etc/modprobe.d/kvm-nested.conf");

  open(M, '>', '/etc/modprobe.d/kvm-nested.conf')
    || die "Could not open /etc/modprobe.d/kvm-nested.conf: $!";

  if ($kmod eq 'kvm_intel') {
    print M <<EOF;
options kvm-intel nested=1
options kvm-intel enable_shadow_vmcs=1
options kvm-intel enable_apicv=1
options kvm-intel ept=1
EOF
  } else {
    print M <<EOF;
options kvm-amd nested=1
EOF
  }
  close M;
  `modprobe -r $kmod`;
  `modprobe -a $kmod`;

  return;
}

sub _query_interactive {
  my ($self, $query, $default, $type) = @_;

  return $default unless $self->interactive;

  print $query;

  my $choice = <STDIN>;
  chomp $choice;

  return $default unless $choice;

  if ($type && ($type eq 'Bool')) {
    $choice = ($choice =~ m{^no?$}smxi) ? 0 : 1;
  }

  return $choice;
}

sub _backup_config_file {
  my ($self, $rc) = @_;
  my $src = $rc;
  my $dst = "$rc.kanku-bak".time().q{.}.$PID;
  if (-e $src) {
    File::Copy::cp($src, $dst);
    $self->logger->debug("Create backup of config $src -> $dst");
  } else {
    $self->logger->debug("No backup of config $src - File does not exist");
  }
  return;
}

1;
