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
package Kanku::Handler::GIT;

use Moose;

use Data::Dumper;
use Path::Class qw/file dir/;
use namespace::autoclean;
use IPC::Run qw/run/;
use URI;
use Try::Tiny;

with 'Kanku::Roles::Handler';
with 'Kanku::Roles::SSH';

has [qw/  giturl          revision    destination
          remote_url      cache_dir
	  gituser         gitpass     _giturl
    /] => (is=>'rw',isa=>'Str');

has [ 'submodules' , 'mirror' ] => (is=>'rw',isa=>'Bool');

has gui_config => (
  is => 'ro',
  isa => 'ArrayRef',
  lazy => 1,
  default => sub {
      [
        {
          param  => 'giturl',
          type   => 'text',
          label  => 'Git URL (required)',
        },
        {
          param  => 'gituser',
          type   => 'text',
          label  => 'Git User',
        },
        {
          param  => 'gitpass',
          type   => 'password',
          label  => 'Git Password',
          secure => 1,
        },
        {
          param  => 'destination',
          type   => 'text',
          label  => 'Destination',
        },
        {
          param  => 'revision',
          type   => 'text',
          label  => 'Revision',
        },
        {
          param  => 'mirror',
          type   => 'checkbox',
          label  => 'Mirror mode',
        },
        {
          param  => 'remote_url',
          type   => 'text',
          label  => 'Remote Url (only for mirror mode)',
        },
      ];
  }
);

has 'timeout' => (is=>'rw', isa=>'Int', default=>600);
sub prepare {
  my ($self) = @_;
  my $ctx    = $self->job->context;

  if (!$self->giturl && $ctx->{giturl}) {
    $self->giturl($ctx->{giturl});
  }

  die "No giturl given"  if (! $self->giturl );

  if ( $self->mirror ) {
    $self->_prepare_mirror;
    $self->_giturl($self->giturl);
  } else {
    $self->_giturl($self->_calc_giturl($self->giturl));
  }


  $self->logger->info("revision: ".($self->revision||q{}));
  $self->logger->info("git_revision: ".($ctx->{git_revision}||q{}));

  if (!$self->revision) {
    $self->revision($ctx->{git_revision}) if ($ctx->{git_revision});
  }

  # inherited by Kanku::Roles::SSH
  $self->get_defaults();

  return {
    code => 0,
    message => "Preparation successful"
  };
}

sub _calc_giturl {
  my ($self, $giturl) = @_;

  if ($giturl =~ m#^(https?)\://(.*)#) {
    my $proto   = "$1://";
    my $gitpass = '';
    my $gituser = $self->gituser || q{};
    my $url     = $2;
    $gituser .= ':'.$self->gitpass if ($gituser && $self->gitpass);
    $gituser .= '@' if ($gituser);
    return "$proto$gituser$url";
  }

  return $giturl;
}

sub _prepare_mirror {
  my $self = shift;
  my $ctx  = $self->job->context;
  my $pkg  = __PACKAGE__;
  my $cdir = Kanku::Config->instance->config()->{$pkg}->{cache_dir};


  $self->cache_dir( ( $self->cache_dir || $ctx->{cache_dir} || $cdir || '' ) );
  die "No cache_dir specified!\n" if ( ! $self->cache_dir );
  die "remote_url needed when using mirror mode\n" if ( ! $self->remote_url );

  my $remote_uri = URI->new($self->remote_url);
  my $mirror_dir = dir($self->cache_dir(),'git',$remote_uri->host,$remote_uri->path);

  my @io;
  my @cmd;

  if ( -d $mirror_dir ) {
    @cmd = ('git', '-C', $mirror_dir->stringify, 'remote', 'update');
  } else {
    if ( ! -d $mirror_dir->parent ) {
      $self->logger->info(sprintf("Creating parent for mirror dir '%s'",$mirror_dir->parent));
      $mirror_dir->parent->mkpath;
    }
    @cmd = ( 'git', 'clone', '--mirror', $self->_calc_giturl($remote_uri->as_string), $mirror_dir->stringify );
  }

  $self->logger->info("Running command '@cmd'");
  run \@cmd , \$io[0], \$io[1], \$io[2] || die "git $?\n";
}

sub execute {
  my $self    = shift;
  my $results = [];
  my $ssh2    = $self->connect();
  my $ip      = $self->ipaddress;
  my $ctx     = $self->job->context;
  my $pass    = $ctx->{gitpass} || $self->gitpass;
  my $user    = $ctx->{gituser} || $self->gituser;
  
  # clone git repository
  try {
    my $cmd_clone = "git clone ".$self->_giturl.(( $self->destination ) ? " " . $self->destination : '');
    my $ret = $self->exec_command($cmd_clone);
    croak($ret->{stderr}) if $ret->{exit_code};
  } catch {
    my $err = $_;
    $err =~ s/$pass/<gitpass>/;
    $err =~ s/$user/<gituser>/;
    die "$err";
  };
  my $git_dest  = ( $self->destination ) ? "-C " . $self->destination : '';

  # checkout specific revision if revision given
  if ( $self->revision ) {
    my $cmd_checkout  = "git ".$git_dest." checkout " .  $self->revision;
    my $ret           = $self->exec_command($cmd_checkout);
    croak($ret->{stderr}) if $ret->{exit_code};
  }

  if ( $self->submodules ) {
    my $cmd = "git ".$git_dest." submodule init";
    my $ret = $self->exec_command($cmd);
    croak($ret->{stderr}) if $ret->{exit_code};

    $cmd = "git ".$git_dest." submodule update";
    $ret = $self->exec_command($cmd);
    croak($ret->{stderr}) if $ret->{exit_code};
  }

  return {
    code        => 0,
    message     => "git clone from url ".$self->giturl." and checkout of revision ". ( $self->revision || '' ) ." was successful",
  };
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

Kanku::Handler::GIT - handle git repositories

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::GIT
    options:
      mirror:     1
      giturl:     http://192.168.199.1/git/github.com/openSUSE/open-build-service.git
      remote_url: https://github.com/openSUSE/open-build-service.git
      destination: /root/kanku
      revision: master
      submodules : 1

=head1 DESCRIPTION

This handler logs into the guest os via ssh and clones/checks out a git repository.

=over 1

=item update cached git repository on master server (only in mirror mode)

=item login into guest vm and clone (from master cache or directly)

=item checkout specific revision

=item update submodules

=back

=head1 OPTIONS

SEE ALSO L<Kanku::Roles::SSH>

  mirror      : boolean, if set to 1, use mirror mode

  giturl      : url to clone git repository from (in mirror mode use local cache)

  gituser     : user for authentication

  gitpass     : password for authentication

  revision    : revision to checkout in git working copy

  destination : path where working copy is checked out in VM's filesystem

  submodules  : boolean, if set to 1, submodules will be initialized and updated

  remote_url  : origin of cached git repository (only used in mirror mode)

=head1 CONTEXT

=head2 getters

SEE L<Kanku::Roles::SSH>

  gituser

  gitpass

  giturl

  git_revision

=head2 setters

NONE

=head1 DEFAULTS

NONE

=head1 SEE ALSO

L<Kanku::Roles::SSH>

=cut
