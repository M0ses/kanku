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
package Kanku::Handler::K8NodePortForward;

use Moose;
use Kanku::Util::IPTables;

sub _build_gui_config {[]}
has 'distributable' => (is=>'ro', isa=>'Int', default => 1);
with 'Kanku::Roles::Handler';

has timeout => (is=>'rw',isa=>'Int',lazy=>1,default=>60*60*4);
with 'Kanku::Roles::SSH';

has nodeports=> (is=>'rw', isa=>'ArrayRef', default => sub {[]});

has environment => (is=>'rw', isa=>'HashRef', default => sub {{}});
has context2env => (is=>'rw', isa=>'HashRef', default => sub {{}});

has domain_name => (
  is=>'rw',
  isa=>'Str',
  lazy => 1,
  default => sub {
    return $_[0]->job->context->{domain_name};
  },
);

has host_interface => (
  is      => 'ro',
  isa     => 'Str',
  lazy => 1,
  default => sub {
    return $_[0]->job->context->{host_interface} || '';
  },
);

sub execute {
  my $self    = shift;
  my $results = [];
  my $ssh2    = $self->connect();
  my $ip      = $self->ipaddress;
  my $ctx     = $self->job->context;

  $ssh2->timeout(1000*$self->timeout) if ($self->timeout);

  for my $env_var (keys(%{$self->context2env})) {
    # upper case environment variables are more shell
    # style
    my $n_env_var = uc($env_var);
    $self->ENV->{$n_env_var} = $ctx->{$env_var};
  }

  for my $env_var (keys(%{$self->environment})) {
    # upper case environment variables are more shell
    # style
    my $n_env_var = uc($env_var);
    $self->ENV->{$n_env_var} = $ctx->{$env_var};
  }

  foreach my $np ( @{$self->nodeports} ) {
      my $cmd = "kubectl get -o jsonpath='{.spec.ports[0].nodePort}' services -n $np->{namespace} $np->{service}";
      $self->logger->debug("COMMAND: $cmd");
      my $ret = $self->exec_command($cmd);
      my $out = $ret->{stdout};
      $self->logger->debug("OUTPUT: $out");

      my @err = $ssh2->error();
      if ($err[0]) {
        $ssh2->disconnect();
        die "Error while executing command via ssh '$cmd': $err[2]";
      }
      die "Invalid port: '$out'\n" unless ($out =~ /^\d+$/);
      my $ipt = Kanku::Util::IPTables->new(
	domain_name     => $self->domain_name,
	host_interface  => $self->host_interface || '',
	guest_ipaddress => $self->ipaddress
      );

      $ipt->add_forward_rules_for_domain(
	start_port => $self->cfg->{'Kanku::Util::IPTables'}->{start_port} || '49000',
	forward_rules => ["$np->{transport}:$out:$np->{application}"],
      );

      push @$results, {
        command     => $cmd,
        exit_status => 0,
        message     => $out
      };

  }

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

Kanku::Handler::K8NodePortForward

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::ExecuteCommandViaSSH
    options:
      context2env:
        ipaddress:
      environment:
        test: value
      publickey_path: /home/m0ses/.ssh/id_rsa.pub
      privatekey_path: /home/m0ses/.ssh/id_rsa
      passphrase: MySecret1234
      username: kanku
      nodeports:
        -
          service: rook-ceph-mgr-dashboard-external-https
          namespace: rook-ceph
          transport: tcp
          application: https

=head1 DESCRIPTION

This handler will connect to a kubernetes cluster with the ipaddress stored in the job context, evaluate the given nodeport and create a port forwarding on the kanku master.


=head1 OPTIONS

      nodeports: array of Kubernetes NodePort Service


SEE ALSO Kanku::Roles::SSH


=head1 CONTEXT

=head2 getters

SEE Kanku::Roles::SSH

=head2 setters

NONE

=head1 DEFAULTS

SEE Kanku::Roles::SSH

=cut
