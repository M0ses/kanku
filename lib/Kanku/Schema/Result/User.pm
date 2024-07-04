use utf8;
package Kanku::Schema::Result::User;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Kanku::Schema::Result::User

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<user>

=cut

__PACKAGE__->table("user");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 username

  data_type: 'varchar'
  is_nullable: 0
  size: 32

=head2 password

  data_type: 'varchar'
  is_nullable: 1
  size: 40

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 email

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 deleted

  data_type: 'boolean'
  default_value: 0
  is_nullable: 0

=head2 lastlogin

  data_type: 'datetime'
  is_nullable: 1

=head2 pw_changed

  data_type: 'datetime'
  is_nullable: 1

=head2 pw_reset_code

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "username",
  { data_type => "varchar", is_nullable => 0, size => 32 },
  "password",
  { data_type => "varchar", is_nullable => 1, size => 40 },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "email",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "deleted",
  { data_type => "boolean", default_value => 0, is_nullable => 0 },
  "lastlogin",
  { data_type => "datetime", is_nullable => 1 },
  "pw_changed",
  { data_type => "datetime", is_nullable => 1 },
  "pw_reset_code",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

__PACKAGE__->add_unique_constraint([qw(username)]);

=head1 RELATIONS

=head2 user_roles

Type: has_many

Related object: L<Kanku::Schema::Result::UserRole>

=cut

__PACKAGE__->has_many(
  "user_roles",
  "Kanku::Schema::Result::UserRole",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 roles

Type: many_to_many

Composing rels: L</user_roles> -> role

=cut

__PACKAGE__->many_to_many("roles", "user_roles", "role");

__PACKAGE__->has_many(
  "role_requests",
  "Kanku::Schema::Result::RoleRequest",
  { "foreign.user_id" => "self.id" },

);


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2017-11-16 13:40:30
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zEiq2HT5KP4WrhsL7TzAow


sub TO_JSON {
  my ($self) = @_;
  my $rv = {};
  for my $col (qw/id username name email deleted/){
    $rv->{$col} = $self->$col;
  }
  return $rv;
}

1;
