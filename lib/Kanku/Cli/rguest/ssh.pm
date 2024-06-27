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
package Kanku::Cli::rguest::ssh;

use MooseX::App::Command;
use Moose::Util::TypeConstraints;
extends qw(Kanku::Cli);

with 'Kanku::Cli::Roles::Remote';
with 'Kanku::Cli::Roles::RemoteCommand';
with 'Kanku::Cli::Roles::View';

use Term::ReadKey;
use Try::Tiny;

use Kanku::YAML;

command_short_description  "ssh to kanku guest on your remote kanku instance";

command_long_description "
This command opens a ssh connection to a specified/selected domain on your
remote kanku instance using the forwarded ssh port on the kanku master.

You can specify the following filters:

* domain
* host

If only one domain matches the specified filter, the console will be opened
immediately, otherwise  a select menu will be printed.

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

option 'ssh_user' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   =>  ['U', 'ssh-user'],
  documentation => 'username to use for ssh to kanku guest.',
  default       => 'root',
);

option 'execute' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   =>  'e',
  documentation => 'command to execute on kanku guest VM.',
);

sub run {
  my $self  = shift;
  Kanku::Config->initialize;
  return $self->_ssh;
}

sub _ssh {
  my ($self) = @_;
  my $logger = $self->logger;
  $self->state(1);
  my $data = $self->_get_filtered_guest_list();
  my $domain;

  while (my ($dk, $dv) = each(%{$data->{guest_list}})) {
    $dv->{conn_opts} = $self->_find_ssh_forwarded_port($dv);
    if (!$dv->{conn_opts}) {
      $logger->debug("No ssh port forwarded to $dv->{domain_name}.");
      delete $data->{guest_list}->{$dk};
    }
  }

  if (keys %{$data->{guest_list}}) {
    $domain = $self->_print_select_menu($data->{guest_list});
  } else {
    $logger->warn("No running domain is matching the specified filters!");
    return 1;
  }

  my $cmd = $self->render_template('rguest/ssh.tt', $domain->{conn_opts});
  system($cmd);

  return;
}

sub _find_ssh_forwarded_port {
  my ($self, $guest) = @_;
  my $logger = $self->logger;

  if (!$guest->{forwarded_ports}) {
    $logger->fatal("No running domain is matching the specified filters!");
    return;
  }

  my $fp = $guest->{forwarded_ports};
  for my $ip (keys %{$fp}) {
    for my $port (keys %{$fp->{$ip}}) {
      if (($fp->{$ip}->{$port}->[1]||'') eq 'ssh') {
        return {
	  ip    => $ip,
	  port  => $port,
	  user  => $self->ssh_user,
	  execute  => $self->execute,
	};
      }
    }
  }

  return;
}

sub _print_select_menu {
  my ($self, $guest_list) = @_;
  my @domains = sort(keys %{$guest_list});
  return $guest_list->{$domains[0]} if (@domains < 2);
  my $answer;
  while (1) {
      print "\nINVALID ANSWER ($answer)!\nPlease try again.\n" if defined $answer;
      print "\nFound the following running domains matching your filters:\n\n";
      my $i=0;
      for my $d (@domains) {
        print "[$i] - $d\n";
	$i++;
      }
      print "\nPlease select a domain: [Enter number]\n";
      $answer=<STDIN>;
      chomp $answer;
      next if ($answer !~ /^\d+$/);
      next unless (defined $domains[$answer]);
      return $guest_list->{$domains[$answer]};
    }
}

sub _get_filtered_guest_list {
  my ($self) = @_;
  my $kr     = $self->connect_restapi();
  my $params = {};
  my @filters;
  push @filters, "host:".$self->host.".*" if $self->host;
  push @filters, "domain:".$self->domain.".*" if $self->domain;
  push @filters, "state:".$self->state if $self->state;
  $params->{filter} = \@filters if @filters;
  return $kr->get_json(path => "guest/list", params => $params);
}

__PACKAGE__->meta->make_immutable;

1;
