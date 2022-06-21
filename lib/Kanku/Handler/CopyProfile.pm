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
package Kanku::Handler::CopyProfile;

use Moose;
use namespace::autoclean;
use Carp qw(croak);
use File::Glob qw(:globally);
use File::Find;

use Kanku::Config;

with 'Kanku::Roles::Handler';
with 'Kanku::Roles::SSH';

has commands    => (is=>'rw', isa=>'ArrayRef', default => sub {[]});
has _results    => (is=>'rw', isa=>'ArrayRef', default => sub {[]});
has users       => (is=>'rw', isa=>'ArrayRef', default => sub {[]});
has timeout     => (is=>'rw',isa=>'Int',lazy=>1,default=>60*60*4);

has environment => (is=>'rw', isa=>'HashRef', default => sub {{}});
has context2env => (is=>'rw', isa=>'HashRef', default => sub {{}});


sub distributable { 0 }

sub execute {
  my ($self)  = @_;
  my $ip      = $self->ipaddress;
  my $ctx     = $self->job->context;
  my $cfg     = Kanku::Config->instance(); 
  my $pkg     = __PACKAGE__;
  my $profile = $cfg->cf->{$pkg};
  my $cmds    = {
    cp    => sub { $self->cp($_[0]) },
    chown => sub { $self->chown($_[0]) },
    chmod => sub { $self->chmod($_[0]) },
    mkdir => sub { $self->mkdir($_[0]) },
  };

  for my $user (@{$self->users}) {
    $self->username($user);
    if (ref($profile->{tasks}) ne 'ARRAY') {
      return {
	code        => 0,
	message     => "No proper config found. Skipping!",
	subresults  => [{command => 'None', exit_status => 0, message => 'Skipped!'}],
      };
    }

    my $tasks   = $profile->{tasks};
    for my $task (@{$tasks}) {
      croak("Found unknown command '$task->{cmd}' in your '$pkg' config") unless (ref($cmds->{$task->{cmd}}) eq 'CODE');
      $cmds->{$task->{cmd}}->($task);
    };
  }
  return {
    code        => 0,
    message     => "All commands on $ip executed successfully",
    subresults  => $self->_results
  };
}

sub cp {
  my ($self, $task) = @_;
  my $pkg = __PACKAGE__;
  my $src = $task->{src} || croak("No src paramter given in your config");
  my $dst = $task->{dst} || $src;
  my $rec = ($task->{recursive})?'-r':q{};
  my $usr = $self->username || 'root';
  my $ctx = $self->job()->context();
  my $cmd = "scp $rec -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null $src $usr\@$ctx->{ipaddress}:$dst";
  $self->logger->info("Executing command: $cmd");
  my @out = `$cmd`;

  push @{$self->_results}, {
    command     => $cmd,
    exit_status => 0,
    message     => "@out",
  };
}

sub chown {
  my ($self, $task) = @_;
  my $rec = ($task->{recursive}) ? '-R' : q{};
  my $cmd = "chown $rec $task->{owner} $task->{path}";
  $self->_cmd($cmd);
}

sub chmod {
  my ($self, $task) = @_;
  my $rec = ($task->{recursive}) ? '-R' : q{};
  my $cmd = "chmod $rec $task->{mode} $task->{path}";
  $self->_cmd($cmd);
}

sub mkdir {
  my ($self, $task) = @_;
  my $cmd          = "mkdir -p $task->{path}";
  $self->_cmd($cmd);
}

sub _cmd {
  my ($self, $cmd) = @_;
  my $ssh2         = $self->connect;
  my $out          = $self->exec_command($cmd);

  my @err = $ssh2->error();
  if ($err[0]) {
    $ssh2->disconnect();
    die "Error while executing command via ssh '$cmd': $err[2]";
  }

  push @{$self->_results}, {
    command     => $cmd,
    exit_status => 0,
    message     => $out
  };
}


__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Kanku::Handler::ExecuteCommandViaSSH

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::ExecuteCommandViaSSH
    options:
      context2env:
        ipaddress:
      environment:
        test: value
      publickey_path: /home/m0ses/.ssh/id_rsa.pub
      privatekey_path: /home/m0ses/.ssh/id_rsa
      passphrase: MySecret1234
      username: kanku
      ipaddress: 192.168.199.17
      commands:
        - rm /etc/shadow

=head1 DESCRIPTION

This handler will connect to the ipaddress stored in job context and excute the configured commands


=head1 OPTIONS

      commands          : array of commands to execute


SEE ALSO L<Kanku::Roles::SSH>


=head1 CONTEXT

=head2 getters

SEE ALSO L<Kanku::Roles::SSH>

=head2 setters

NONE

=head1 DEFAULTS

SEE ALSO L<Kanku::Roles::SSH>

=cut
