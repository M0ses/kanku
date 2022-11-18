# Copyright (c) 2019 SUSE LLC
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
package Kanku::Handler::OBSServerFrontendTests;

use Moose;
use namespace::autoclean;

with 'Kanku::Roles::Handler';
with 'Kanku::Roles::SSH';

has timeout       => (is=>'rw',isa=>'Int',lazy=>1,default=>60*60*4);
has environment   => (is=>'rw', isa=>'HashRef', default => sub {{}});
has context2env   => (is=>'rw', isa=>'HashRef', default => sub {{}});
has jump_host     => (is=>'rw', isa=>'Str');
has git_url       => (is=>'rw', isa=>'Str', default => 'https://github.com/openSUSE/open-build-service.git');
has git_revision  => (is=>'rw', isa=>'Str', default => 'master');
has ruby_version  => (is=>'rw', isa=>'Str', default => '2.5');

has gui_config => (
  is => 'ro',
  isa => 'ArrayRef',
  lazy => 1,
  default => sub {
      [
        {
          param => 'git_url',
          type  => 'text',
          label => 'Git URL:'
        },
        {
          param => 'git_revision',
          type  => 'text',
          label => 'Git Revision:'
        },
        {
          param => 'ruby_version',
          type  => 'text',
          label => 'Ruby Version:'
        },
      ];
  }
);


sub distributable { 1 }

sub execute {
  my $self    = shift;
  my $results = [];
  my $ip      = $self->jump_host;
  $self->ipaddress($ip);
  my $ssh     = $self->connect();
  my $ctx     = $self->job->context;

  for my $env_var (keys(%{$self->context2env})) {
    # upper case environment variables are more shell
    # style
    my $n_env_var = uc($env_var);
    $self->ENV->{$n_env_var} = $ctx->{$env_var};
  }

  for my $env_var (keys(%{$self->environment})) {
    # upper case environment variables are more shell
    # style
    my $n_env_var = uc($env_var);
    $self->ENV->{$n_env_var} = $ctx->{$env_var};
  }

  my @commands = (
    'export TMPDIR=`mktemp -d` &&'.
    'cd $TMPDIR &&'.
    'git clone '.$self->git_url.' &&'.
    'cd open-build-service/dist/t &&'.
    'git checkout '.$self->git_revision.' &&'.
    'bundle.ruby'.$self->ruby_version.' install ;'.
    'bundle.ruby'.$self->ruby_version.' exec rspec > /tmp/obs-server-frontend-$$.log 2>&1 ||'.
    'cat /tmp/obs-server-frontend-$$.log ;'.
    'rm -rf $TMPDIR',
  );

  foreach my $cmd ( @commands ) {
      my $ret = $self->exec_command($cmd);
      my $out = $ret->{stdout};
      my @err = $ssh->error();
      if ($ret->{exit_code}) {
        $ssh->disconnect();
        croak("Error while executing command via ssh '$cmd': $ret->{stderr}\nSTDOUT: $ret->{stdout}");
      }
      push @$results, {
        command     => $cmd,
        exit_status => 0,
        message     => $out
      };
  }

  return {
    code        => 0,
    message     => "All commands on $ip executed successfully",
    subresults  => $results
  };
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

Kanku::Handler::OBSServerFrontendTests - a handler to execute OBS Server SmokeTests for the Frontend

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::OBSServerFrontendTests
    options:
      context2env:
        ipaddress:
      jump_host: 192.168.199.17
      git_url: https://github.com/M0ses/open-build-service
      git_revision: fix_foobar

=head1 DESCRIPTION

This handler will connect to the given ipaddress and execute the OBS server 
frontend test suite (smoketests)


=head1 OPTIONS

      commands          : array of commands to execute


SEE ALSO Kanku::Roles::SSH, Kanku::Handler::ExecuteCommandViaSSH


=head1 CONTEXT

=head2 getters

NONE

=head2 setters

NONE

=head1 DEFAULTS

NONE

=cut
