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
package Kanku::Cli::Ip;

use MooseX::App::Command;
extends qw(Kanku::Cli);

with 'Kanku::Cli::Roles::VM';
with 'Kanku::Cli::Roles::View';

use Kanku::Util::VM;

command_short_description  'Show ip address of a kanku vm';

command_long_description '
This command shows the ip address of a kanku vm
';

option 'login_user' => (
    isa           => 'Str',
    is            => 'rw',
    cmd_aliases   => [qw/u login-user/],
    documentation => 'user to login',
    lazy          => 1,
    builder       => '_build_login_user'
);
sub _build_login_user {
  my ($self) = @_;
  return $self->kankufile_config->{login_user} || q{};
}

option 'login_pass' => (
    isa           => 'Str',
    is            => 'rw',
    cmd_aliases   => [qw/p login-password/],
    documentation => 'password to login',
    lazy          => 1,
    builder       => '_build_login_pass',
);
sub _build_login_pass {
  my ($self) = @_;
  return $self->kankufile_config->{login_pass} || q{};
}

option '+format' => (default=>'none');

sub run {
  my ($self)  = @_;
  Kanku::Config->initialize(class=>'KankuFile', file=>$self->file);
  my $logger  = $self->logger;
  my $config  = $self->kankufile_config;


  my $vm = Kanku::Util::VM->new(
    domain_name => $self->domain_name,
    login_user  => $self->login_user,
    login_pass  => $self->login_pass,
  );

  my $ip = $vm->get_ipaddress();

  if ($ip) {
    $logger->info("IP Address: $ip");
    $self->print_formatted($self->format, $ip);
  } else {
    $logger->error('Could not find IP Address');
  }

  return 0;
}

__PACKAGE__->meta->make_immutable;

1;
