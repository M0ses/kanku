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
package Kanku::Handler::RemoveDomain;

use Moose;
use Kanku::Util::VM;
use Kanku::Util::IPTables;
use Try::Tiny;
use Carp;
with 'Kanku::Roles::Handler';

has [qw/uri domain_name/] => (is => 'rw',isa=>'Str');

has [qw/disabled ignore_autostart/] => (is => 'rw',isa=>'Bool');
has [qw/keep_volumes/] => (is => 'rw', isa => 'ArrayRef', lazy => 1, default => sub {[]});

has gui_config => (
  is => 'ro',
  isa => 'ArrayRef',
  lazy => 1,
  default => sub {
      [
        {
          param => 'domain_name',
          type  => 'text',
          label => 'Domain Name',
        },
        {
          param => 'disabled',
          type  => 'checkbox',
          label => 'Disabled',
        },
        {
          param => 'ignore_autostart',
          type  => 'checkbox',
          label => 'Ignore Autostart',
        },
      ];
  }
);

# send to all hosts
sub distributable { 2 };

sub execute {
  my ($self) = @_;
  my $ctx    = $self->job->context;

  $self->logger->trace("Domain name in context: $ctx->{domain_name}");

  if ( ! $self->domain_name && $ctx->{domain_name} ) {
    $self->logger->debug("Using domain name from context: $ctx->{domain_name}");
    $self->domain_name($ctx->{domain_name});
  }

  confess "No domain_name given!\n" if (! $self->domain_name );

  $self->logger->info("Removing domain: ".$self->domain_name);

  if ($self->disabled) {
      return {
        code    => 0,
        message => "Skipped removing domain " . $self->domain_name ." because of disabled job"
      }
  }

  if ($ctx->{domain_autostart} && !$self->ignore_autostart) {
      return {
        code    => 0,
        message => "Skipped removing domain " . $self->domain_name ." because 'domain_autostart' is set in job context."
      }
  }

  my $vm    = Kanku::Util::VM->new(
    domain_name  => $self->domain_name,
    job_id       => $self->job->id,
    keep_volumes => $self->keep_volumes
  );

  try {
    $vm->remove_domain();
  } catch {
    $self->logger->warn("Error while removing domain: ".$self->domain_name."\n$_");
  };

  return {
    code    => 0,
    message => "Successfully removed domain " . $self->domain_name
  }

}

1;

__END__

=head1 NAME

Kanku::Handler::RemoveDomain

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::RemoveDomain
    options:
      domain_name: my-unneeded-domain
      keep_volumes:
        - ....

=head1 DESCRIPTION

This handler removes VM and removes configured port forwarding rules.

=head1 OPTIONS


    domain_name           : name of domain to remove

    keep_volumes          : list of volumes not to delete

=head1 CONTEXT

=head2 getters

 domain_name

 domain_autostart

=head2 setters

NONE

=head1 DEFAULTS

NONE


=cut

