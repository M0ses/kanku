use utf8;
package Kanku::Schema::Result::JobHistory;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Kanku::Schema::Result::JobHistory

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<job_history>

=cut

__PACKAGE__->table("job_history");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 1

=head2 state

  data_type: 'text'
  is_nullable: 1

=head2 args

  data_type: 'text'
  is_nullable: 1

=head2 result

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

=head2 last_modified

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 workerinfo

  data_type: 'text'
  is_nullable: 1

=head2 masterinfo

  data_type: 'text'
  is_nullable: 1

=cut

=head2 job_group_id

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 1 },
  "state",
  { data_type => "text", is_nullable => 1 },
  "args",
  { data_type => "text", is_nullable => 1 },
  "result",
  { data_type => "text", is_nullable => 1 },
  "creation_time",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "start_time",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "end_time",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "last_modified",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "workerinfo",
  { data_type => "text", is_nullable => 1 },
  "masterinfo",
  { data_type => "text", is_nullable => 1 },
  "trigger_user",
  { data_type => "text", is_nullable => 1 },
  "pwrand",
  { data_type => "text", is_nullable => 1 },
  "job_group_id",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 job_history_subs

Type: has_many

Related object: L<Kanku::Schema::Result::JobHistorySub>

=cut

__PACKAGE__->has_many(
  "job_history_subs",
  "Kanku::Schema::Result::JobHistorySub",
  { "foreign.job_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2017-11-16 13:40:30
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:dOiKpTLA7PciDbF7AtbIHw

__PACKAGE__->has_many(
  "comments",
  "Kanku::Schema::Result::JobHistoryComment",
  { "foreign.job_id" => "self.id" },
);

__PACKAGE__->has_many(
  "wait_for",
  "Kanku::Schema::Result::JobWaitFor",
  { "foreign.job_id" => "self.id" },
);

__PACKAGE__->belongs_to(
  "job_group",
  "Kanku::Schema::Result::JobGroup",
  { "foreign.id" => "self.job_group_id" },
);


sub TO_JSON {
  my $self = shift;
  my $rv = {};
  for my $col (qw/id name state args result creation_time start_time end_time last_modified workerinfo masterinfo job_group_id/) {
    $rv->{$col} = $self->$col();
  }

  return $rv
}
1;
