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
package Kanku::Cli::Rguest::Console;

use MooseX::App::Command;
extends qw(Kanku::Cli);

with 'Kanku::Cli::Roles::Remote';
with 'Kanku::Cli::Roles::View';

use Term::ReadKey;
use Try::Tiny;

command_short_description  "open console to guest on kanku worker via ssh";

command_long_description  "
This command opens a console to a specified/selected kanku guest
on a kanku worker via ssh.
You can specify the following filters:

* domain
* host

If only one domain matches the specified filter, the console will be opened
immediately.
If multiple domains match the specified filter, a select menu will be printed.
If no domain matches your filter, an error message will be printed.

DISCLAIMER:

This command relies on a working ssh connection to the kanku worker.

";

option 'host' => (
  isa           => 'Str',
  is            => 'rw',
  documentation => 'filter list by host (wildcard .)',
);

option 'domain' => (
  isa           => 'Str',
  is            => 'rw',
  documentation => 'filter list by domain (wildcard .)',
);

option '+format' => (default => 'view');

has 'template' => (
  is            => 'rw',
  isa           => 'Str',
  default       => 'rguest/select_menu.tt',
);

sub run {
  my $self  = shift;
  Kanku::Config->initialize;

  return $self->_console;
}

sub _console {
  my ($self) = @_;
  my $logger = $self->logger;
  my $data = $self->_get_filtered_guest_list();
  my $domain;

  if (keys %{$data->{guest_list}}) {
    $domain = $self->_print_select_menu($data->{guest_list});
  } else {
    $logger->fatal("No running domain is matching the specified filters!");
    return 1;
  }

  my $cmd = ['ssh', '-t', $domain->{host}, "virsh console $domain->{domain_name}"];

  system(@$cmd);

  return;
}

sub _print_select_menu {
  my ($self, $guest_list) = @_;
  my $data = {
    guest_list => [sort {$a->{domain_name} cmp $b->{domain_name}} (values %{$guest_list})],
  };
  return $data->{guest_list}->[0] if (@{$data->{guest_list}} < 2);
  while (1) {
    $self->print_formatted($data);
    $data->{answer} = <STDIN>;
    chomp $data->{answer};
    return 1 if ($data->{answer} eq '0');
    next if ($data->{answer} !~ /^\d+$/);
    my $f = $data->{answer} - 1;
    next unless (defined $data->{guest_list}->[$f]);
    return $data->{guest_list}->[$f];
  }
}

sub _get_filtered_guest_list {
  my ($self) = @_;
  my $kr     = $self->connect_restapi();
  my $params = {};
  my @filters;
  push @filters, "host:".$self->host.".*" if $self->host;
  push @filters, "domain:".$self->domain.".*" if $self->domain;
  push @filters, "state:1";
  $params->{filter} = \@filters if @filters;
  return $kr->get_json(path => "guest/list", params => $params);
}
__PACKAGE__->meta->make_immutable;

1;
