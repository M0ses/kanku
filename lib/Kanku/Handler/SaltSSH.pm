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
package Kanku::Handler::SaltSSH;

use Moose;

use Data::Dumper;

use namespace::autoclean;

with 'Kanku::Roles::Handler';
with 'Kanku::Roles::Logger';

has [qw/ipaddress publickey_path privatekey_path passphrase username/] => (is=>'rw',isa=>'Str');
has states   => (is=>'rw',isa=>'ArrayRef',default=>sub { [] });
has loglevel => (is=>'rw',isa=>'Str', default=> 'debug');

sub execute {
  my $self    = shift;
  my $results = [];
  my $ctx     = $self->job->context;
  my $ip      = $ctx->{ipaddress};
  my @cmd = (
    "salt-ssh",
      "-l",$self->loglevel,
      "--roster","scan",$ip,
      '-i',
      'state.apply',join(',',@{$self->states})
  );

  $self->logger->debug("COMMAND: '@cmd'");
  system(@cmd);
  return {
    code        => 0,
    message     => "All commands on $ip executed successfully",
    subresults  => $results
  };
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Kanku::Handler::SaltSSH

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::SaltSSH
    options:
      publickey_path: /home/m0ses/.ssh/id_rsa.pub
      privatekey_path: /home/m0ses/.ssh/id_rsa
      passphrase: MySecret1234
      username: kanku
      commands:
        - rm /etc/shadow

=head1 DESCRIPTION

This handler will connect to the ipaddress stored in job context and excute the configured commands


=head1 OPTIONS

      publickey_path    : path to public key file (optional)

      privatekey_path   : path to private key file

      passphrase        : password to use for private key

      username          : username used to login via ssh

      states            : array of salt states to apply


=head1 CONTEXT

=head2 getters

 ipaddress

=head1 DEFAULTS


=cut

