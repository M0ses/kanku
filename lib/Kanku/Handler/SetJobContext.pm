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
package Kanku::Handler::SetJobContext;

use Moose;
use feature 'say';
use Data::Dumper;
with 'Kanku::Roles::Handler';
with 'Kanku::Roles::Logger';

has [qw/
        api_url         project         package
        vm_image_file   vm_image_url    vm_template_file
        domain_name     host_interface  management_interface
        cache_dir       images_dir
	os_instance_name os_image_id
	login_user	login_pass
	privatekey_path publickey_path
        ipaddress
        host_dir_9p	accessmode_9p
    /
] => (is=>'rw',isa=>'Str');

has [qw/
  skip_all_checks
  skip_check_project
  skip_check_package
  skip_download
  offline
/] => (is => 'ro', isa => 'Bool',default => 0 );

has [qw/
  tmp_image_file
/] => (is => 'rw', isa => 'Object|Undef');

has gui_config => (
  is => 'ro',
  isa => 'ArrayRef',
  lazy => 1,
  default => sub {
      [
#        {
#          param => 'api_url',
#          type  => 'text',
#          label => 'API URL'
#        },
#        {
#          param => 'skip_all_checks',
#          type  => 'checkbox',
#          label => 'Skip all checks'
#        },
#        {
#          param => 'project',
#          type  => 'text',
#          label => 'Project'
#        },
#        {
#          param => 'package',
#          type  => 'text',
#          label => 'Package'
#        },
        {
          param => 'images_dir',
          type  => 'text',
          label => 'Image Directory'
        },
        {
          param => 'domain_name',
          type  => 'text',
          label => 'Domain Name'
        },
        {
          param => 'vm_template_file',
          type  => 'text',
          label => 'VM Template File'
        },
        {
          param => 'os_instance_name',
          type  => 'text',
          label => 'Name for OpenStack instance'
        },
        {
          param => 'offline',
          type  => 'checkbox',
          label => 'Offline Mode'
        },
      ];
  }
);

sub execute {
  my $self = shift;
  my $ctx  = $self->job()->context();
  for my $var (qw/
    domain_name vm_template_file host_interface images_dir cache_dir ipaddress
    os_instance_name os_image_id login_user login_pass 
    privatekey_path publickey_path
    host_dir_9p accessmode_9p
    vm_image_file management_interface
  /) {
    if ($self->$var()){
      $self->logger->debug("Setting variable $var in context to ".$self->$var());
      $ctx->{$var} = $self->$var();
    }
  }

  return {
    code    => 0,
    state   => 'succeed',
    message => "Sucessfully prepared job context"
  };
}


1;

__END__

=head1 NAME

Kanku::Handler::SetJobContext

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::SetJobContext
    options:
      api_url: https://api.opensuse.org
      ....

=head1 DESCRIPTION

This handler will set the given variables in the job context


=head1 OPTIONS

For further explaination of these options please have a look at the corresponding modules.

      api_url

      project

      package

      vm_image_file

      vm_image_url

      vm_template_file

      domain_name

      host_interface

      skip_all_checks

      skip_check_project

      skip_check_package

      skip_download

      cache_dir

      images_dir



=head1 CONTEXT

=head2 getters

NONE

=head2 setters

Please see the OPTIONS section. All given options will be set in the job context.

=head1 DEFAULTS

NONE


=cut

