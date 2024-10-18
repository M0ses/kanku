# Copyright (c) 2015 SUSE LLC
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
package Kanku::Util::VM::Console;

use Moose;
use Carp;
use Expect;
use Data::Dumper;
use Time::HiRes qw/usleep/;
use Path::Tiny;
use Kanku::Config;

with 'Kanku::Roles::Logger';

has ['domain_name','short_hostname','log_file','login_user','login_pass'] => (is=>'rw', isa=>'Str');
has 'prompt' => (is=>'rw', isa=>'Str',default=>'Kanku-prompt: ');
has 'prompt_regex' => (is=>'rw', isa=>'Object',default=>sub { qr/^Kanku-prompt: /m });
has _expect_object  => (is=>'rw', isa => 'Object');
has [qw/bootloader_seen grub_seen user_is_logged_in console_connected log_stdout no_wait_for_bootloader/] => (is=>'rw', isa => 'Bool');
has 'connect_uri' => (is=>'rw', isa=>'Str', default=>'qemu:///system');
has ['job_id'] => (is=>'rw', isa=>'Int|Undef');

has ['cmd_timeout'] => (is=>'rw', isa=>'Int', default => 600);
has ['login_timeout'] => (is=>'rw', isa=>'Int', default => 300);
has '+log_stdout' => (default=>1);
has '+no_wait_for_bootloader' => (default=>0);

sub init {
  my $self = shift;
  my $cfg_ = Kanku::Config->instance();
  my $cfg  = $cfg_->config();
  my $pkg  = __PACKAGE__;
  my $logger    = $self->logger();


  $ENV{"LANG"} = "C";
  my $command = "virsh";
  my @parameters = ("-c",$self->connect_uri,"console",$self->domain_name);

  my $exp = Expect->new;
  $exp->restart_timeout_upon_receive(1);
  $exp->debug($cfg->{$pkg}->{debug} || 0);

  if ($self->log_file) {
    $exp->log_file($self->log_file);
  } elsif ($cfg->{$pkg}->{log_to_file} && $self->job_id) {
    $logger->debug("Config -> $pkg (log_to_file): $cfg->{$pkg}->{log_to_file}");

    my $lf = path($cfg->{$pkg}->{log_dir},"job-".$self->job_id."-console.log");
    $lf->parent->mkdir;
    $logger->debug("Setting logfile '".$lf->stringify()."'");
    $exp->log_file($lf->stringify());
    $self->log_stdout(0);
  }

  $exp->log_stdout($self->log_stdout);

  $self->_expect_object($exp);
  $exp->spawn($command, @parameters)
    or die "Cannot spawn $command: $!\n";

  # wait 1 min to get virsh console
  my $timeout = 60;

  $exp->expect(
    $timeout,
      [
        'Escape character is \^\]' => sub {
          $_[0]->clear_accum();
          $self->console_connected(1);
          $logger->debug("Found Console");
        }
      ]
  );

  if (!$self->no_wait_for_bootloader) {
    $logger->info('Waiting for bootloader');
    $exp->expect(
      5,
      [
        qr/(Welcome to GRUB!|Press any key to continue.|ISOLINUX|Automatic boot in|The highlighted entry will be executed automatically in)/ => sub {
          $logger->debug("Seen bootloader");
          $self->bootloader_seen(1);
          if ($_[0]->match =~ /(Press any key to continue\.|The highlighted entry will be executed automatically in)/) {
            $self->grub_seen(1);
            $logger->debug("Seen bootloader grub");
          }
        }
      ]
    );

    if ( $self->grub_seen ) {
      $exp->send("\n\n");
      $exp->clear_accum();
    } else {
      $logger->warn("No bootloader seen - this might be a bug in your OS!");
      $logger->warn("Try using a template with graphical console configured!");
      $logger->warn("E.g. use 'template: with-spice' in your CreateDomain config section!");
    }
  }

  die "Could not open virsh console within $timeout seconds" if ( ! ( $self->console_connected or $self->grub_seen ));

  return 0;
}

sub login {
  my $self       = shift;
  my $exp        = $self->_expect_object();
  my $timeout    = $self->login_timeout;
  my $logger     = $self->logger();
  my $login_seen = 0;

  my $user      = $self->login_user;
  my $password  = $self->login_pass;

  die "No login_user found in config" if (! $user);
  die "No login_pass found in config" if (! $password);

  if (! $self->bootloader_seen) {
    $exp->send_slow(1,"\003","\004");
  }
  $logger->debug("Waiting $timeout for login: prompt");
  $exp->expect(
    $timeout,
      [ '^\S+ login: ' =>
        sub {
          my $exp = shift;
          if ( $exp->match =~ /^(\S+) login: / ) {
            $logger->debug("Found match '$1'");
            $self->short_hostname($1);
            $self->prompt_regex(qr/$1:.*\s+#/);
          }
          $login_seen=1;
          $logger->debug(" - Sending username '$user'");
          $exp->send("$user\n");
        }
      ],
  );
  die "No login prompt seen within $timeout sec!\n" unless $login_seen;
  $exp->expect(
      10,
      # Ugly fix for nasty Fedora (32) behavior
      [ '^\S+ login: ' =>
        sub {
          my $exp = shift;
          if ( $exp->match =~ /^(\S+) login: / ) {
            $logger->debug("Found match '$1' again");
          }
          $logger->debug(" - Re-Sending username '$user'");
          $exp->send("$user\n");
          exp_continue;
        }
      ],
      [ qr/Password: / =>
        sub {
          my $exp = shift;
          $logger->debug(" - Sending password '$password'");
          $exp->send("$password\n");
        }
      ],
  );

  $exp->expect(
    10,
      [ 'Login incorrect' =>
        sub {
          croak("Login failed");
        }
      ],
  );
  $exp->send("export TERM=dumb\n");

  my $hn = $self->short_hostname();
  my $prompt = $self->prompt_regex;
  $exp->expect(
      5,
      [
        $prompt=>sub {
          my $exp = shift;
          $logger->info(" - Logged in sucessfully: '".$exp->match."'");
        }
      ]
  );
  $self->user_is_logged_in(1);
  $exp->send("export PS1=\"".$self->prompt."\"\n");
  $self->prompt_regex(qr/\r\nKanku-prompt: /m);
  my $count;
  $exp->expect(
      5,
      [
        $self->prompt_regex() => sub {
          my $exp = shift;
          $logger->info(" - Prompt set sucessfully: '".$exp->match."'");
          $count++;
          exp_continue unless $count == 2;
        }
      ]
  );
  $exp->clear_accum();
}

sub wait_for_login_prompt {
  my $self      = shift;
  my $exp       = $self->_expect_object();
  my $timeout   = 300;
  my $logger    = $self->logger();


  my $login_counter = 0;

  if (! $self->bootloader_seen) {
    $exp->send_slow(1,"\003","\004");
  }
  $exp->expect(
    $timeout,
      [ '^\S+ login: ' =>
        sub {
          my $exp = shift;

          #die "login seems to be failed as login_counter greater than zero" if ($login_counter);
          if ( $exp->match =~ /^(\S+) login: / ) {
            $logger->debug("Found match '$1'");
            $self->short_hostname($1);
            $self->prompt_regex(qr/$1:.*\s+#/);
          }
        }
      ],
  );
  $exp->clear_accum();
}

sub logout {
  my $self = shift;
  my $exp = $self->_expect_object();

  $self->logger->debug("Sending exit");
  $exp->send("exit\n");
  my $timeout = 5;
  sleep 1;
  $exp->expect(
    $timeout,
      [ '^\S+ login: ' =>
        sub {
          my $exp = shift;
          $self->logger->debug("Found '".$exp->match."'");
          sleep(1);
        }
      ],
  );
  $self->user_is_logged_in(0);
}

=head1 cmd - execute one or more commands on cli

  $con->cmd("mkdir -p /tmp/kanku","mount /tmp/kanku");

=cut

sub cmd {
  my $self    = shift;
  my @cmds    = @_;
  my $exp     = $self->_expect_object();
  my $results = [];
  my $logger  = $self->logger;

  my $timeout = $self->cmd_timeout;

  foreach my $cmd (@cmds) {
      $exp->clear_accum();
      $logger->debug("EXPECT STARTING COMMAND: '$cmd' (timeout: $timeout)");
      $exp->send("$cmd\n");
      usleep(10000);
      if ($timeout < 0) {
        $logger->debug("Timeout less then 0 - fire and forget mode");
        next;
      }
      my @result = $exp->expect(
        $timeout,
          [ $self->prompt_regex() =>
            sub {
              my $exp = shift;
              push(@$results,$exp->before());
            }
          ],
      );

      die "Error while executing command '$cmd' (timemout: $timeout): $result[1]" if $result[1];

      $exp->clear_accum;
      $exp->send("echo \$?\n");
      usleep(10000);

      @result = $exp->expect(
        $timeout,
        [
          $self->prompt_regex() => sub {
            my $exp=shift;
            my $rc = $exp->before();
            my @l = split /\r\n/, $rc;
            $rc = int($l[1]||0);
            if ($rc) {
              $logger->warn("Execution of command '$cmd' failed with return code '$rc'");
            } else {
              $logger->debug("Execution of command '$cmd' succeed");
            }
          }
        ]
      );

      die "Error while getting return value of command '$cmd' (timeout $timeout): ".$result[1] if $result[1];
  }

  return $results;
}

=head1 get_ipaddress - get ip address for given interface

Both arguments "interface" and "timeout" are mandatory

  $con->get_ipaddress(interface=>'eth0', timeout=>60);

=cut

sub get_ipaddress {
  my ($self, %opts) = @_;
  my $logger    = $self->logger;
  my $do_logout = 0;

  my $save_timeout = $self->cmd_timeout;

  $self->cmd_timeout(600);

  croak 'Please specify an interface!' unless $opts{interface};
  croak 'Please specify a timeout!' unless $opts{timeout};

  if (! $self->user_is_logged_in ) {
    $logger->debug("User not logged in. Trying to login");
    $do_logout = 1;
    $self->login;
  } else {
    $logger->debug("User already logged in.");
  }

  my $wait         = $opts{timeout};
  my $ipaddress    = undef;
  my $type_output  = $self->cmd("type -P ip wicked nmcli");
  my @tmp          = split /\r\n/, $type_output->[0], 3;
  my $cmd          = $tmp[1];
  my @cmd_splitted = split '/', $cmd;
  my $cmd_short    = pop @cmd_splitted;

  my %cmd2func = (
    ip => sub {
      my ($self, $bin, $int) = @_;
      my $ipaddress;
      my $result = $self->cmd("LANG=C \\ip addr show $int 2>&1");

      $logger->trace("  -- Output:\n".Dumper($result));

      map { $ipaddress = $1 if m/^\s+inet\s+([0-9\.]+)\// } split /\n/, $result->[0];
      return $ipaddress
    },
    wicked => sub {
      my ($self, $bin, $int) = @_;
      my $ipaddress;
      my $result = $self->cmd("LANG=C $bin ifstatus $int 2>&1");

      $logger->debug("  -- Output:\n".Dumper($result));
      my @lines = split /\r\n/, $result->[0];
      my @addr = map { ($_ =~ /^\s+addr:\s+ipv4\s+([0-9.]+)\//) ? $1 : ()  } @lines;
      return $addr[0];
    },
    nmcli => sub {
      my ($self, $bin, $int) = @_;
      my $ipaddress;
      my $result = $self->cmd("LANG=C $bin device show $int 2>&1");

      $logger->debug("  -- Output:\n".Dumper($result));
      my @lines = split /\r\n/, $result->[0];
      my @addr = map { ($_ =~ /^IP4.ADDRESS[1]:\s+([0-9.]+)\//) ? $1 : ()  } @lines;
      return $addr[0];
    },
  );

  my $cmd_ref  = $cmd2func{$cmd_short};

  while ( $wait > 0) {
    # use cat for disable colors
    $ipaddress = $cmd_ref->($self, $cmd, $opts{interface});
    if ($ipaddress) {
      last
    } else {
      $logger->debug("Could not get ip address form interface $opts{interface}.");
      $logger->debug("Waiting another $wait seconds for network to come up");
      $wait--;
      sleep 1;
    }
  }

  $self->logout if $do_logout;

  if (! $ipaddress) {
    croak "Could not get ip address for interface $opts{interface} within "
      . "$opts{timeout} seconds.";
  }

  $self->cmd_timeout($save_timeout);

  return $ipaddress
}


__PACKAGE__->meta->make_immutable;

1;
