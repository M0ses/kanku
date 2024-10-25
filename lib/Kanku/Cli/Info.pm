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
package Kanku::Cli::Info;

use MooseX::App::Command;
extends qw(Kanku::Cli);

with 'Kanku::Cli::Roles::VM';
with 'Kanku::Cli::Roles::View';

use Kanku::Util::VM;

command_short_description  'Show info from KankuFile';

command_long_description '
This command shows information in KankuFile like

- summary
- description
- default_job
- login_user
- jobs (List)
';

option '+format' => (default=>'view');

has template => (
  is   => 'rw',
  isa  => 'Str',
  default => 'info.tt',
);

sub run {
  my ($self)  = @_;
  Kanku::Config->initialize(class=>'KankuFile', file=>$self->file);
  my $logger  = $self->logger;
  my $config  = $self->kankufile_config;

  if ($config->{description}) {
    $self->print_formatted($config);
  } else {
    $logger->error('Could not find description in KankuFile');
  }

  return 0;
}

__PACKAGE__->meta->make_immutable;

1;
