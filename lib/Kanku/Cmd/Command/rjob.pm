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
package Kanku::Cmd::Command::rjob;

use Moose;
use Data::Dumper;
use Term::ReadKey;
use Kanku::Remote;
use YAML qw/LoadFile DumpFile Dump/;
use POSIX;
use Try::Tiny;


extends qw(MooseX::App::Cmd::Command);

with 'Kanku::Cmd::Roles::Remote';
with 'Kanku::Cmd::Roles::RemoteCommand';

has config => (
  traits        => [qw(Getopt)],
  isa           => 'Bool',
  is            => 'rw',
  cmd_aliases	=> 'c',
  documentation => 'show config of remote job',
);

has name => (
  traits        => [qw(Getopt)],
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases	=> 'n',
  documentation => 'name of remote job',
);

sub abstract { "show result of tasks from a specified remote job" }

sub description { 
  "show result of tasks from a specified job on your remote instance" . $_[0]->description_footer;
}

sub execute {
  my $self  = shift;
  my $logger  = Log::Log4perl->get_logger;

  if ( $self->config ) {

      if ( ! $self->name ) {
        $logger->error("No parameter --name given");
        exit 1;
      }

	  my $kr;
	  try {
		$kr = $self->_connect_restapi();
	  } catch {
		exit 1;
	  };

      my $data = $kr->get_json( path => "job/config/".$self->name);

      print $data->{config};      

  } elsif ($self->list) {

	  my $kr;
	  try {
		$kr = $self->_connect_restapi();
	  } catch {
		exit 1;
	  };

      my $data = $kr->get_json( path => "gui_config/job");

      my @job_names = sort ( map { $_->{job_name} } @{$data->{config}} );

      # some useful options (see below for full list)
	  my $template_path = Kanku::Config->instance->app_base_path->stringify . '/views/cli/';
	  my $config = {
		INCLUDE_PATH  => $template_path,
		INTERPOLATE   => 1,               # expand "$var" in plain text
		POST_CHOMP    => 1,
		PLUGIN_BASE   => 'Template::Plugin',
	  };

	  # create Template object
	  my $template  = Template->new($config);
	  my $input     = 'rjob/list.tt';
	  my $output    = '';
	  # process input template, substituting variables
	  $template->process($input, { job_names => \@job_names })
				   || die $template->error()->as_string();
 
  } elsif ($self->details) {

	my $kr;
	try {
	  $kr = $self->_connect_restapi();
	} catch {
	  exit 1;
	};

    my $data = $kr->get_json( path => "gui_config/job");
	my $job_config;
	while ( my $j = shift( @{$data->{config}} )) {
		if ( $j->{job_name} eq $self->details ) {
			$job_config = $j;
			last;
		}
	}
	print Dumper($job_config);
  } else {
	$logger->warn("Please specify a command. Run 'kanku help rjob' for further information.");
  }
}

__PACKAGE__->meta->make_immutable;

1;
