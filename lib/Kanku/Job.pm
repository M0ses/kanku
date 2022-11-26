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
package Kanku::Job;

use Moose;
use JSON::XS;
use Kanku::GPG;
use Try::Tiny;

with 'Kanku::Roles::Serialize';
with 'Kanku::Roles::Logger';

has "context" => (
    is  => 'rw',
    isa => 'HashRef',
    default => sub { {} }
);

has id => ( is  => 'rw', isa => 'Int' );
has [qw/name state result workerinfo masterinfo trigger_user/] => ( is => 'rw', isa => 'Str' );
has 'trigger_user' => ( is => 'rw', isa => 'Str|Undef', default=>'' );
has [qw/skipped scheduled triggered/] => ( is => 'rw', isa => 'Bool' );
has [qw/creation_time start_time end_time last_modified/] => ( is  => 'rw', isa => 'Int' );
has db_object => ( is => 'rw', isa => 'Object' );
has '+workerinfo' => (default =>"localhost:$$:none");
has 'pwrand' => (is=>'rw', isa=>'Str');
has job_group_id => ( is => 'rw', isa => 'Int|Undef' );

sub json_keys; # prototype to not break the requires in Kanku::Roles::Serialize
has 'json_keys' => (
  is      => 'rw',
  isa     => 'ArrayRef',
  default => sub {[qw/
    name state result workerinfo skipped scheduled triggered creation_time
    start_time end_time last_modified id context masterinfo trigger_user pwrand
    job_group_id
  /
  ]});


sub update_db {
  my $self = shift;
  my $ds = { last_modified => time() };

  my $pwrand =(ref $self->context->{pwrand})
    ? encode_json($self->context->{pwrand})
    : $self->context->{pwrand};

  if ($self->context->{encrypt_pwrand}) {
    # Avoid double encryption
    if ($self->context->{pwrand} !~ /-BEGIN PGP MESSAGE-/) {
      try {
        my $gpg = Kanku::GPG->new(
          message    => $pwrand,
          recipients => $self->context->{encrypt_pwrand},
        );
        $pwrand = $gpg->encrypt;
      } catch {
        $self->logger->error("Failed to encrypt: $_");
        $self->result(encode_json({error_message=>$_}));
        $self->state('failed');
        $self->end_time(time());
      };
    }
  }

  $self->pwrand($pwrand) if $pwrand;

  foreach my $key ( qw/id name state start_time end_time result workerinfo masterinfo trigger_user pwrand job_group_id/ ) {
    my $value = $self->$key();
    $ds->{$key} = $value if ( $value );
  }

  return $self->db_object->update($ds);

}

sub exit_with_error {
  my ($self,$error) = @_;
  $self->logger->error($error);
  $self->result(encode_json({error_message=>$error}));
  $self->state('failed');
  $self->end_time(time());
  $self->update_db();
  die $error;
}

__PACKAGE__->meta->make_immutable;

1;
