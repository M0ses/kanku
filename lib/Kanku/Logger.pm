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
package Kanku::Logger;

use MooseX::Singleton;

use Log::Log4perl;
use Log::Log4perl::Level;
use FindBin;

BEGIN {
  $Data::Dumper::Sortkeys = sub { return [ grep { !/^(db_object|schema|logger)$/ } ( keys(%{$_[0]}) )  ] };
}

has loglevel => (
  is      => 'rw',
  isa     => 'Str',
  default => q{},
);

has logger => (
  is      => 'rw',
  isa     => 'Object',
  lazy    => 1,
  builder => '_build_logger',
);
sub _build_logger {
  my ($self) = @_;
  Log::Log4perl->init($self->logconf);
  my $l = Log::Log4perl->get_logger();
  my $can = $self->can('loglevel');
  if ($can && $self->loglevel) {
    my $numval = ($self->loglevel =~ /^\d+$/) ? $self->loglevel : Log::Log4perl::Level::to_priority($self->loglevel);
    $l->level($numval);
  }
  return $l;
}

has 'logconf'  => (
  is            => 'rw',
  isa           => 'Str',
  lazy          => 1,
  builder       => '_build_logconf',
);
sub _build_logconf {
  my ($self) = @_;
  for my $c (
    "$ENV{HOME}/.kanku/logging.conf",
    "/etc/kanku/logging/console.conf",
    "$FindBin::Bin/../etc/logging/console.conf",
  ) {
    return $c if (-e $c);
  }
}

__PACKAGE__->meta->make_immutable;

1;
