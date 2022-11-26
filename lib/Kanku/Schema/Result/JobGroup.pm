use utf8;
package Kanku::Schema::Result::JobGroup;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Kanku::Schema::Result::JobGroup

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<job_group>

=cut

__PACKAGE__->table("job_group");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 1

=head2 creation_time

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 start_time

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 end_time

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 1 },
  "creation_time",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "start_time",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "end_time",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

sub TO_JSON {
  my $self = shift;
  my $rv = {};
  for my $col (qw/id name creation_time start_time end_time)/) {
    $rv->{$col} = $self->$col();
  }

  return $rv
}
1;
