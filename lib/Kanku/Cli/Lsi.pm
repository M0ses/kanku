# Copyright (c) 2024 SUSE LLC
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
package Kanku::Cli::Lsi;

use MooseX::App::Command;
extends qw(Kanku::Cli);

use Net::OBS::Client::Project;

command_short_description  'list standard kanku images';

command_long_description   '
This command lists the standard kanku images which  are based on (open)SUSEs
JeOS images

';

option 'name' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'n',
  documentation => 'filter list by name ',
  default       => '',
);

option 'obsurl' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'a',
  documentation => 'OBS api url',
  builder       => '_build_obsurl',
);
sub _build_obsurl {
  return Kanku::Config::Defaults->get('Kanku::Config::GlobalVars', 'obsurl');
}

option 'project' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'p',
  documentation => 'Project name',
  builder       => '_build_project',
);
sub _build_project {
  return Kanku::Config::Defaults->get(__PACKAGE__, 'project');
}
option '+format' => (default => 'view');
has 'template' => (
  is            => 'rw',
  isa           => 'Str',
  default       => 'lsi.tt',
);

sub run {
  my ($self)  = @_;
  my $obsurl  = $self->obsurl;
  my $project = $self->project;
  my $cred_defaults = Kanku::Config::Defaults->get('Net::OBS::Client','credentials');
  my %credentials = (ref($cred_defaults->{$obsurl}) eq "HASH") ? %{$cred_defaults->{$obsurl}} :();

  my $prj = Net::OBS::Client::Project->new(
    name     => $project,
    apiurl   => $obsurl,
    %credentials,
  );

  my $arch    = Kanku::Config::Defaults->get('Kanku::Config::GlobalVars', 'arch');
  my $res     = $prj->fetch_resultlist(arch=>$arch);
  my $re_name = '.*'.$self->name.'.*';
  my $re_code = qr/^(disabled|excluded|unknown)$/;
  my $pkgs    = [];
  for my $repo (@{$res->{result}}) {
    my @active_pkgs;
    for my $pkg (@{$repo->{status}}) {
      next if $pkg->{code} =~ $re_code;
      push @active_pkgs, {%{$pkg}, repository => $repo->{repository}, arch => $repo->{arch}};
    }
    push(@{$pkgs}, grep { $_->{package} =~ $re_name } @active_pkgs);
  }

  my $vars    = {
    obsurl   => $obsurl,
    project  => $project,
    packages => [sort { $a->{package} cmp $b->{package} } @$pkgs],
  };

  $self->print_formatted($vars);

  return 0;
}

__PACKAGE__->meta->make_immutable;

1;
