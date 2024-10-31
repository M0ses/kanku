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
package Kanku::Cli::Browser;

use MooseX::App::Command;
extends qw(Kanku::Cli);

with 'Kanku::Cli::Roles::VM';
with 'Kanku::Cli::Roles::View';

use Kanku::Util::VM;

command_short_description  'open url for guest vm with xdg-open';

command_long_description '
This command opens the URL for the kanku guest in a browser using `xdg-open`.

Either a URL template can be configured in the KankuFile, e.g.:

guest:
  url: https://[% ctx.ipaddress %]:8001/path/to/

or the URL is generated using the ipaddress.
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

option '+format' => (default=>'view');

has template => (
  is   => 'rw',
  isa  => 'Str',
  default => 'ip.tt',
);


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
    my $template = $config->{guest}->{url} || "[% ctx.ipaddress %]";
    my $data     = {ctx=>{ipaddress=>$ip}};
    my $tt = Template->new({
      INCLUDE_PATH  => $self->include_path,
      INTERPOLATE   => 1,
      POST_CHOMP    => 1,
    });
    my $url;
    # process input template, substituting variables
    if ($tt->process(\$template, $data, \$url)) {
      $logger->info("Opening $url in browser");
      exec 'xdg-open', $url || return 1;
    } else {
      $logger->error($tt->error()->as_string());
    }
  } else {
    $logger->error('Could not find URL');
  }

  return 1;
}

__PACKAGE__->meta->make_immutable;

1;
