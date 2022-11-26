use utf8;
package Kanku::Schema::Result::JobHistorySub;

use JSON::XS;
use Encode;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Kanku::Schema::Result::JobHistorySub

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<job_history_sub>

=cut

__PACKAGE__->table("job_history_sub");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 job_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 name

  data_type: 'text'
  is_nullable: 1

=head2 state

  data_type: 'text'
  is_nullable: 1

=head2 result

  data_type: 'text'
  is_nullable: 1

=head2 start_time

  data_type: 'integer'
  is_nullable: 1

=head2 end_time

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "job_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "name",
  { data_type => "text", is_nullable => 1 },
  "state",
  { data_type => "text", is_nullable => 1 },
  "result",
  { data_type => "text", is_nullable => 1 },
  "start_time",
  { data_type => "integer", is_nullable => 1 },
  "end_time",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 job

Type: belongs_to

Related object: L<Kanku::Schema::Result::JobHistory>

=cut

__PACKAGE__->belongs_to(
  "job",
  "Kanku::Schema::Result::JobHistory",
  { id => "job_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07043 @ 2016-01-07 19:19:30
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:51R4/WxT5wwcm46ZeudQ+Q

sub TO_JSON {
  my $self = shift;
  my $rv = {};
  for my $col (qw/id job_id name state/) {
    $rv->{$col} = $self->$col();
  }

  if ( $self->result ) {
    eval {
      my $res = encode('UTF-8', $self->result);
      $rv->{result} = decode_json($res);
    };
    if ($@ and ! $rv->{result}) {
      $rv->{result}->{finalize} = {message => $@, code=>1 };
      $rv->{result}->{prepare} = $rv->{result}->{finalize};
      $rv->{result}->{execute} = $rv->{result}->{finalize};
    }
  }
  return $rv
}


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
