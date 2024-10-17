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
use Carp qw(croak);

use Kanku::Config::Defaults;

sub gui_config {[]}
sub distributable { 0 }

with 'Kanku::Roles::Handler';

has timeout         => (is=>'rw',isa=>'Int',lazy=>1,default=>60*60*4);
with 'Kanku::Roles::SSH';

has _results    => (is=>'rw', isa=>'ArrayRef', default => sub {[]});
has tasks       => ( is=>'rw',
                     isa=>'ArrayRef',
                     default => sub {
		       Kanku::Config::Defaults->get(__PACKAGE__, 'tasks');
		     },
		   );

has users       => ( is=>'rw',
                     isa=>'ArrayRef',
		     default => sub {
		       Kanku::Config::Defaults->get(__PACKAGE__, 'users');
		     },
		   );

has environment => (is=>'rw', isa=>'HashRef', default => sub {{}});
has context2env => (is=>'rw', isa=>'HashRef', default => sub {{}});

sub execute {
  my ($self)  = @_;
  my $ip      = $self->ipaddress;
  my $ctx     = $self->job->context;
  my $users   = $self->users;
  my $tasks   = $self->tasks;

  my $cmds    = {
    cp    => sub { $self->cp($_[0]) },
    chown => sub { $self->chown($_[0]) },
    chmod => sub { $self->chmod($_[0]) },
    mkdir => sub { $self->mkdir($_[0]) },
  };
  for my $user (@{$users}) {
    $self->username($user);
    if (!@{$tasks}) {
      return {
	code        => 0,
	message     => "No proper config found. Skipping!",
	subresults  => [{command => 'None', exit_status => 0, message => 'Skipped!'}],
      };
    }

    for my $task (@{$tasks}) {
      croak("Found unknown command '$task->{cmd}' in your config") unless (ref($cmds->{$task->{cmd}}) eq 'CODE');
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
  my $src = $task->{src} || croak("No src paramter given in your config");
  my $dst = $task->{dst} || $src;
  my $rec = ($task->{recursive}) ? '-r ' : q{};
  my $usr = $self->username || 'root';
  my $ctx = $self->job()->context();
  my @sfiles = glob($task->{src});
  # Cleanup scp file source and dest to behave
  # like legacy scp instead of sftp
  $src =~ s#~/#$::ENV{HOME}/#;
  $src =~ s#/$##;
  $dst =~ s#~/##;
  $dst =~ s#/$##;
  my $cmd = "scp $rec-oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -q $src $usr\@$ctx->{ipaddress}:$dst";
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
  my $ret          = $self->exec_command($cmd);
  my $out          = $ret->{stdout};

  my @err = $ssh2->error();
  if ($ret->{exit_code}) {
    $ssh2->disconnect();
    croak("Error while executing command via ssh '$cmd': $ret->{stderr}");
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

Kanku::Handler::CopyProfile

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::CopyProfile
    options:
      users:
        - root
	- kanku
      tasks:
	- cmd: cp
	  src: ~/.gitconfig
	- cmd: cp
	  src: ~/.vimrc
	- cmd: cp
	  src: ~/.vim/
	  recursive: 1
	- cmd: mkdir
	  path: ~/.config/
	- cmd: cp
	  src: ~/.config/osc/
	  dst: ~/.config/osc/
	  recursive: 1
	- cmd: chown
	  owner: kanku:users
	  recursive: 1
	  path: ~/.config/
	- cmd: chmod
	  mode: 700
	  path: ~/.config/

=head1 DESCRIPTION

This handler could help to configure your environment by copying files,
creating directories and change permissions.

Its recommended to create a config section named 'Kanku::Handler::CopyProfile'
in your kanku-config.yml and set the defaults there.

In a KankuFile it should be used without and options.


=head1 OPTIONS

      users             : array of users to deploy your Profile

      tasks             : array of tasks to execute for profle deployment. Each
                          task requires a 'cmd'. 'cmd' can be one of the following
			  * cp (uses scp)
			    * src
			    * dst
			    * recursive
                          * chmod
			    * mode
			    * path
			    * recursive
                          * chown
			    * owner
			    * path
			    * recursive
			  * mkdir
			    * path
      commands          : array of commands to execute



=head1 CONTEXT

=head2 getters

NONE

=head2 setters

NONE

=head1 DEFAULTS

SEE ALSO L<Kanku::Roles::SSH> AND L<kanku-config.yml>

=cut
