use utf8;
package Kanku::Schema::Result::ObsCheckHistory;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Kanku::Schema::Result::ObsCheckHistory

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<obs_check_history>

=cut

__PACKAGE__->table("obs_check_history");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 obsurl

  data_type: 'text'
  is_nullable: 1

=head2 project

  data_type: 'text'
  is_nullable: 1

=head2 package

  data_type: 'text'
  is_nullable: 1

=head2 vm_image_url

  data_type: 'text'
  is_nullable: 1

=head2 check_time

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "obsurl",
  { data_type => "text", is_nullable => 1 },
  "project",
  { data_type => "text", is_nullable => 1 },
  "package",
  { data_type => "text", is_nullable => 1 },
  "vm_image_url",
  { data_type => "text", is_nullable => 1 },
  "check_time",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<obsurl_project_package_unique>

=over 4

=item * L</obsurl>

=item * L</project>

=item * L</package>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "obsurl_project_package_unique",
  ["obsurl", "project", "package"],
);


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2017-11-16 13:40:30
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:u5NQFtMJvzrZ2B0Kj1KufA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
