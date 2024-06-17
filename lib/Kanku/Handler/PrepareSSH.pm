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
use Path::Class qw/file/;

sub _build_gui_config {[]}
has 'distributable' => (is=>'ro', isa=>'Bool', default => 1);
with 'Kanku::Roles::Handler';

has 'timeout' => (is=>'rw', isa=>'Int', default=>180);
with 'Kanku::Roles::SSH';

has ['public_keys', 'public_key_files' ] => (is=>'rw',isa=>'ArrayRef',lazy=>1,default=>sub { [] });
has [qw/domain_name login_user login_pass/] => (is=>'rw',isa=>'Str');

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
    $self->logger->debug("No public_keys found, checking home dir");
    for my $kf (
      "$ENV{HOME}/.ssh/id_dsa.pub",
      "$ENV{HOME}/.ssh/id_ecdsa.pub",
      "$ENV{HOME}/.ssh/id_ecdsa_sk.pub",
      "$ENV{HOME}/.ssh/id_ed25519.pub",
      "$ENV{HOME}/.ssh/id_ed25519_sk.pub",
      "$ENV{HOME}/.ssh/id_rsa.pub",
      "/etc/kanku/ssh/id_dsa.pub",
      "/etc/kanku/ssh/id_ecdsa.pub",
      "/etc/kanku/ssh/id_ecdsa_sk.pub",
      "/etc/kanku/ssh/id_ed25519.pub",
      "/etc/kanku/ssh/id_ed25519_sk.pub",
      "/etc/kanku/ssh/id_rsa.pub",
    ) {
      $self->logger->debug("-- Checking $kf");
      if ( -f $kf) {
        $self->logger->debug("-- Using $kf");
        push @{$self->public_key_files}, $kf;
      }
    }
  }

  if ( $self->public_key_files ) {
    foreach my $file ( @{ $self->public_key_files } ) {
      $self->logger->debug("-- Reading public_key_files: $file");
      $file_counter++;
      my $fh = file($file);

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

  if ($ctx->{image_type} eq 'vagrant') {
    $self->username($self->login_user);
    $self->password($self->login_pass);
    $self->auth_type('password');
    $self->connect();
    $self->exec_command(
      "cat <<EOF > \$HOME/.ssh/authorized_keys\n" .
      "$str\n" .
      "EOF\n"
    );
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
    $con->cmd("[ -f $crypto_cfg ] && sed -i -E 's/(PubkeyAcceptedKeyTypes .*)/\\1,ssh-rsa/' $crypto_cfg");

    # TODO: make dynamically switchable between systemV and systemd
    $con->cmd("systemctl restart sshd.service");

    $con->cmd("systemctl enable --now sshd.service");

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

  public_keys       - An array of strings which include your public ssh key

  public_key_files  - An array of files to get the public ssh keys from

  domain_name       - name of the domain to prepare

  login_user        - username to use when connecting domain via console

  login_pass        - password to use when connecting domain via console

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
