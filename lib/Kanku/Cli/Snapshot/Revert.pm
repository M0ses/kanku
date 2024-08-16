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
package Kanku::Cli::Snapshot;

use MooseX::App::Command;
extends qw(Kanku::Cli);

with 'Kanku::Cli::Roles::VM';

use Net::IP;

use Kanku::Job;
use Kanku::Util::VM;


command_short_description  'revert snapshots of kanku vms';

command_long_description  '
With this command you can revert snapshots of local kanku domains.

';

option 'name' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'n',
  documentation => 'name of snapshot',
  default       => 'current',
);

sub run {
  my ($self) = @_;
  my $ret    = 0;
  my $cfg    = $self->cfg;
  my $dn     = $self->domain_name;
  my $vm     = Kanku::Util::VM->new(
    domain_name   => $dn,
    snapshot_name => $self->name,
    login_user    => $cfg->{login_user} || 'root',
    login_pass    => $cfg->{login_pass} || 'kankudai',
  );

  $vm->revert_snapshot;

  return $ret;
}

__PACKAGE__->meta->make_immutable;

1;

