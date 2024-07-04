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
package Kanku::Cli::destroy; ## no critic (NamingConventions::Capitalization)

use MooseX::App::Command;
extends qw(Kanku::Cli);

use Try::Tiny;

use Kanku::Util::VM;
use Kanku::Util::IPTables;

command_short_description 'Remove domain completely';
command_long_description '
With this command you can remove the given domain entirely.
It will not only undefine a domain, it will also remove defined images for this
domain from disk unless they are excluded with `--keep-volumes`.
';

with 'Kanku::Cli::Roles::VM';
with 'Kanku::Roles::Logger';

option 'keep_volumes' => (
    isa           => 'ArrayRef',
    is            => 'rw',
    cmd_aliases   => [qw/k keep-volumes/],
    documentation => 'Volumes to keep when destroying VM to reuse next time.',
    builder       => '_build_keep_volumes',
);
sub _build_keep_volumes {[]}

sub run {
  my ($self)  = @_;
  my $ret     = 0;
  my $logger  = $self->logger;
  my $dn      = $self->domain_name;

  my $vm      = Kanku::Util::VM->new(
    domain_name  => $dn,
    keep_volumes => $self->keep_volumes,
  );

  try {
    $vm->dom;
  } catch {
    $logger->error($_);
    $logger->fatal("Domain $dn not found");
    $ret = 1;
  };

  return $ret if $ret;

  try {
    $vm->remove_domain();
  } catch {
    $logger->error($_);
    $logger->fatal("Error while removing domain: `$dn`");
    $ret = 1;
  };

  my $ipt = Kanku::Util::IPTables->new(domain_name=>$dn);
  $ipt->cleanup_rules_for_domain();

  $logger->info("Removed domain `$dn` successfully");

  return $ret;
}

__PACKAGE__->meta->make_immutable;

1;
