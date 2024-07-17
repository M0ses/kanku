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
package Kanku::Cli::Lsi;

use MooseX::App::Command;
extends qw(Kanku::Cli);

use Net::OBS::Client::Project;

command_short_description  'list standard kanku images';
command_long_description   'This command lists the standard kanku images which'.
  ' are based on (open)SUSEs JeOS images';

option 'name' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'n',
  documentation => 'filter list by name ',
  default       => '',
);

option 'apiurl' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'a',
  documentation => 'OBS api url',
  builder       => '_build_apiurl',
);
sub _build_apiurl {
  Kanku::Config::Defaults->get(__PACKAGE__, 'apiurl')
}

option 'project' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'p',
  documentation => 'Project name',
  builder       => '_build_project',
);
sub _build_project { Kanku::Config::Defaults->get(__PACKAGE__, 'project') }

sub run {
  my ($self)  = @_;
  my $apiurl  = $self->apiurl;
  my $project = $self->project;
  my $cred_defaults = Kanku::Config::Defaults->get('Net::OBS::Client','credentials');
  my %credentials = (ref($cred_defaults->{$apiurl}) eq "HASH") ? %{$cred_defaults->{$apiurl}} :();

  my $prj = Net::OBS::Client::Project->new(
    name     => $project,
    apiurl   => $apiurl,
    %credentials,
  );

  my $arch    = Kanku::Config::Defaults->get('Kanku::Config::GlobalVars', 'arch');
  my $res     = $prj->fetch_resultlist(arch=>$arch);
  my $re_name = '.*'.$self->name.'.*';
  my $re_code = qr/^(disabled|excluded|unknown)$/;
  my $pkgs    = [];

  for my $repo (@{$res->{result}}) {
    my @active_pkgs = grep { $_->{code} !~ $re_code } @{$repo->{status}};
    push(@{$pkgs}, grep { $_->{package} =~ $re_name } @active_pkgs);
  }

  my $vars    = {
    apiurl   => $apiurl,
    project  => $project,
    packages => [sort { $a->{package} cmp $b->{package} } @$pkgs],
    arch     => $arch,
  };

  print $self->render_template('lsi.tt', $vars);

  return 0;
}

__PACKAGE__->meta->make_immutable;

1;
