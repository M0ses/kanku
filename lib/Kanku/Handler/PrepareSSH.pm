# Copyright (c) 2016 SUSE LLC
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
package Kanku::Handler::PrepareSSH;

use Moose;
use Kanku::Util::VM::Console;
use Kanku::Config;
use Path::Tiny qw/path tempfile/;

sub gui_config {
  [
    {
      param => 'enable_daemon_debug',
      type  => 'checkbox',
      label => 'Enable debug logging for sshd'
    },
  ]
}
sub distributable { 1 }
with 'Kanku::Roles::Handler';

has 'timeout' => (is=>'rw', isa=>'Int', default=>180);
with 'Kanku::Roles::SSH';

has ['public_keys', 'public_key_files' ] => (
  is      =>'rw',
  isa     =>'ArrayRef',
  lazy    =>1,
  default =>sub { [] }
);
has 'enable_daemon_debug' => (
  is      =>'rw',
  isa     =>'Bool',
  lazy    => 1,
  default => 0,
);
has [qw/domain_name login_user login_pass/] => (
  is     => 'rw',
  isa    => 'Str',
);

sub prepare {
  my $self = shift;
  my $cf   = Kanku::Config->instance();
  my $cfg  = $cf->config();
  my $pkg  = __PACKAGE__;

  if ($cfg->{$pkg}->{public_key_files}) {
    push @{$self->public_key_files}, @{$cfg->{$pkg}->{public_key_files}};
  }

  if ($cf->{cf}->{$pkg}->{public_key_files}) {
    push @{$self->public_key_files}, @{$cf->{cf}->{$pkg}->{public_key_files}};
  }

  $self->evaluate_console_credentials;

  my $file_counter = 0;

  if ( ! @{$self->public_keys} and ! @{$self->public_key_files} ) {
    $self->logger->debug("No public_keys found, checking default places");
    my @found_pubkey_files;
    foreach (@{
        Kanku::Config::Defaults->get(__PACKAGE__, 'default_public_key_files')
      }
    ) {
      push @{$self->public_key_files}, glob($_);
    }
  }

  if ($self->public_key_files) {
    foreach my $file ( @{ $self->public_key_files } ) {
      $self->logger->debug("-- Reading public_key_files: $file");
      $file_counter++;
      my $fh = path($file);

      my $key = $fh->slurp();
      push(@{ $self->public_keys },$key);
    }
  }

  return {
    code    => 0,
    message => "Successfully finished prepare and loaded keys from $file_counter files"
  };
}

sub execute {
  my ($self) = @_;
  my $cfg    = Kanku::Config->instance()->config();
  my $ctx    = $self->job()->context();

  $self->logger->debug("username/password: ".$self->login_user.'/'.$self->login_pass);

  my $str="";
  map { $str .= "$_\n" } @{$self->public_keys()};

  if (($ctx->{image_type}||q{}) eq 'vagrant') {
    $self->username($self->login_user);
    my $key = Kanku::Config::Defaults->get('Kanku::Handler::Vagrant', 'vagrant_privkey');
    my $tmpdir = path($::ENV{HOME}, '.ssh');
    $tmpdir->mkdir unless $tmpdir->exists;
    my $um = umask 0077;
    my $tpriv = tempfile(DIR => $tmpdir);
    my $tpub  = path("$tpriv.pub");
    $self->privatekey_path($tpriv->absolute->stringify);
    $self->publickey_path($tpub->absolute->stringify);
    $self->auth_type('publickey');
    $tpriv->spew($key);
    `ssh-keygen -f $tpriv -y > $tpub`;
    umask $um;
    $self->connect();
    $self->exec_command(
      "cat <<EOF > \$HOME/.ssh/authorized_keys\n" .
      "$str\n" .
      "EOF\n"
    );
    $tpub->remove;
  } else {
    my $default_user = 'kanku';
    my $con = Kanku::Util::VM::Console->new(
      domain_name => $self->domain_name,
      login_user  => $self->login_user(),
      login_pass  => $self->login_pass(),
      debug       => $cfg->{'Kanku::Util::VM::Console'}->{debug} || 0,
      job_id      => $self->job->id,
      log_file    => $ctx->{log_file} || q{},
      log_stdout  => defined ($ctx->{log_stdout}) ? $ctx->{log_stdout} : 1,
      no_wait_for_bootloader => 1,
    );
    $con->init();
    $con->login();

    $con->cmd('[ -d $HOME/.ssh ] || mkdir $HOME/.ssh');

    $con->cmd(
      "cat <<EOF >> \$HOME/.ssh/authorized_keys\n" .
      "$str\n" .
      "EOF\n"
    );

    $con->cmd("id $default_user || useradd -m $default_user");
    $con->cmd("[ -d /home/$default_user/.ssh ] || mkdir /home/$default_user/.ssh");
    $con->cmd(
      "cat <<EOF >> /home/$default_user/.ssh/authorized_keys\n" .
      "$str\n" .
      "EOF\n"
    );
    $con->cmd("chown $default_user:users -R /home/$default_user/.ssh/");

    # Hack for Fedora 33
    my $crypto_cfg = '/etc/crypto-policies/back-ends/opensshserver.config';
    $con->cmd("[ ! -f $crypto_cfg ] || sed -i -E 's/(PubkeyAcceptedKeyTypes .*)/\\1,ssh-rsa/' $crypto_cfg");

    # Set loglevel of vm's sshd to debug3
    if ($self->enable_daemon_debug) {
      $con->cmd('[ ! -d /etc/ssh/sshd_config.d ] || echo "LogLevel DEBUG3" > /etc/ssh/sshd_config.d/loglevel.conf');
    }

    # This is required because openssh-server service unit name depends on the distribution
    # and calling by an alias/link may cause problems in ubuntu base distros
    # opensuse/suse/fedora: sshd.service
    # ubuntu/debian: ssh.service
    $con->cmd(
      'IFS=" " read -ra ADDR <<< '.
      '`systemctl list-unit-files --all *ssh*.service|grep --color=none ssh.*\.service|grep -Pv "(alias|static|@)"` '.
      '&& SSHD_SERVICE="${ADDR[0]}" '.
      '&& export SSHD_SERVICE'
    );
    $con->cmd('test -n "$SSHD_SERVICE" && systemctl restart $SSHD_SERVICE || echo "SSHD_SERVICE empty"');

    ## Do not run "systemctl enable --now", because '--now' may not be implemented by systemctl avaliable on the guest
    ## and on the other hand the "systemctl restart ..." the line above should have covered the start of the service
    ## already
    $con->cmd('test -n "$SSHD_SERVICE" && systemctl enable $SSHD_SERVICE || echo "SSHD_SERVICE empty"');

    $con->logout();
  }


  return {
    code    => 0,
    message => "Successfully prepared " . $self->domain_name . " for ssh connections\n"
  }
}

__PACKAGE__->meta->make_immutable();
1;

__END__

=head1 NAME

Kanku::Handler::PrepareSSH

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::PrepareSSH
    options:
      public_keys:
        - ssh-rsa A....
        - ssh-dsa B....
      public_key_files:
        - /home/myuser/.ssh/id_rsa.pub
        - /home/myotheruser/.ssh/id_rsa.pub
      domain_name: my-fancy-vm
      login_user: root
      login_pass: kankudai

=head1 DESCRIPTION

This handler deploys the given public keys for ssh for user root and kanku.

The user kanku will be created if not already exists.

The ssh daemon will be enabled and started.

=head1 OPTIONS

  public_keys         - An array of strings which include your public ssh key

  public_key_files    - An array of files to get the public ssh keys from

  domain_name         - name of the domain to prepare

  login_user          - username to use when connecting domain via console

  login_pass          - password to use when connecting domain via console

  enable_daemon_debug - Enable debug logging for sshd

=head1 CONTEXT

=head2 getters

The following variables will be taken from the job context if not set explicitly

=over 1

=item domain_name

=item login_user

=item login_pass

=back

=head1 DEFAULTS

If neither public_keys nor public_key_files are given,
than the handler will check $HOME/.ssh and /etc/kanku/ssh
for the following files:
id_dsa.pub, id_ecdsa.pub, id_ecdsa_sk.pub,
id_ed25519.pub, id_ed25519_sk.pub, and id_rsa.pub.

The keys from the found files will be deployed on the system.


=cut
