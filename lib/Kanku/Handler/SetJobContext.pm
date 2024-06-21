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

sub _build_gui_config {
  [
    {
      param => 'images_dir',
      type  => 'text',
      label => 'Image Directory',
    },
    {
      param => 'domain_name',
      type  => 'text',
      label => 'Domain Name',
    },
    {
      param => 'vm_template_file',
      type  => 'text',
      label => 'VM Template File',
    },
    {
      param => 'offline',
      type  => 'checkbox',
      label => 'Offline Mode',
    },
    {
      param => 'domain_autostart',
      type  => 'checkbox',
      label => 'Autostart domain',
    },
    {
      param  => 'gitlab_merge_request_id',
      type   => 'text',
      label  => 'Gitlab Merge Request ID (requires manual fetch)',
    },
  ];
}
sub distributable { 0 }
with 'Kanku::Roles::Handler';

has [qw/
        api_url         project         package
        vm_image_file   vm_image_url    vm_template_file
        domain_name     host_interface  management_interface
        cache_dir       images_dir
	login_user	login_pass
	privatekey_path publickey_path
        ipaddress
        host_dir_9p	accessmode_9p   snapshot_name
	gituser         gitpass         giturl
	git_revision    gitlab_merge_request_id
    /
] => (is=>'rw',isa=>'Str');

has [qw/
  skip_all_checks
  skip_check_project
  skip_check_package
  skip_download
  offline
  domain_autostart
/] => (is => 'ro', isa => 'Bool',default => 0 );

has [qw/
  tmp_image_file
/] => (is => 'rw', isa => 'Object|Undef');

sub execute {
  my $self = shift;
  my $ctx  = $self->job()->context();
  for my $var (qw/
    domain_name vm_template_file host_interface images_dir cache_dir ipaddress
    login_user login_pass 
    privatekey_path publickey_path
    host_dir_9p accessmode_9p
    vm_image_file management_interface snapshot_name domain_autostart
    gituser gitpass giturl git_revision gitlab_merge_request_id
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

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Kanku::Handler::SetJobContext

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::SetJobContext
    options:
      api_url: https://api.opensuse.org/public
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

      domain_autostart


=head1 CONTEXT

=head2 getters

NONE

=head2 setters

Please see the OPTIONS section. All given options will be set in the job context.

=head1 DEFAULTS

NONE


=cut

