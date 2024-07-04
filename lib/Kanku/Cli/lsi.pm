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
package Kanku::Cli::lsi;  ## no critic (NamingConventions::Capitalization)

use MooseX::App::Command;
extends qw(Kanku::Cli);

with 'Kanku::Roles::Logger';

use Net::OBS::Client::Project;
use Kanku::Config;
use Kanku::Config::Defaults;


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
  default       => sub { Kanku::Config::Defaults->get(__PACKAGE__, 'apiurl') },
);

option 'project' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'p',
  documentation => 'Project name',
  default       => sub { Kanku::Config::Defaults->get(__PACKAGE__, 'project') },
);

BEGIN {
  Kanku::Config->initialize();
}

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

  my $res  = $prj->fetch_resultlist;
  my $reg  = '.*'.$self->name.'.*';
  my $arch = Kanku::Config->instance->cf->{arch} || 'x86_64';
  foreach my $tmp (@{$res->{result}}) {
    foreach my $pkg (@{$tmp->{status}}) {
      if ($pkg->{code} !~ /disabled|excluded/) {
        if ($pkg->{package} =~ $reg) {
	print <<EOF

    # --- $pkg->{package}
      ## kanku init --apiurl $apiurl --project $project --package $pkg->{package} --repository $tmp->{repository}
      ## state: $pkg->{code}
      project: $project
      package: $pkg->{package}
      repository: $tmp->{repository}
      arch: $arch
EOF
  ;
      }
    }
  }
}

  return 0;
}

__PACKAGE__->meta->make_immutable;

1;
