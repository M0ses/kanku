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
package Kanku::Cli::init; ## no critic (NamingConventions::Capitalization)

use strict;
use warnings;

use MooseX::App::Command;
extends qw(Kanku::Cli);

with 'Kanku::Cli::Roles::Schema';

use Template;
use Carp;
use Kanku::Config;
use Kanku::Config::Defaults;

command_short_description  'create KankuFile in your current working directory';

command_long_description 'create KankuFile in your current working directory';

option 'default_job' => (
    isa           => 'Str',
    is            => 'rw',
    documentation => 'default job name in KankuFile',
    cmd_aliases   => ['j'],
    lazy          => 1,
    default       => 'kanku-job',
);

option 'domain_name' => (
    isa           => 'Str',
    is            => 'rw',
    documentation => 'name of default domain in KankuFile',
    cmd_aliases   => ['d'],
    lazy          => 1,
    default       => 'kanku-vm',
);

option 'memory' => (
    isa           => 'Str',
    is            => 'rw',
    documentation => 'RAM size of virtual machines',
    cmd_aliases   => ['m'],
    lazy          => 1,
    default       => '2G',
);

option 'vcpu' => (
    isa           => 'Int',
    is            => 'rw',
    documentation => 'Number of virtual CPU\'s in VM',
    cmd_aliases   => ['c'],
    lazy          => 1,
    default       => 2,
);

option 'project' => (
    isa           => 'Str',
    is            => 'rw',
    documentation => 'Project name to search for images in OBSCheck',
    cmd_aliases   => ['prj'],
    lazy          => 1,
    default       => sub { Kanku::Config::Defaults->get(__PACKAGE__, 'project') },
);

option 'package' => (
    isa           => 'Str',
    is            => 'rw',
    documentation => 'Package name to search for images in OBSCheck',
    cmd_aliases   => ['pkg'],
    lazy          => 1,
    default       => sub { Kanku::Config::Defaults->get(__PACKAGE__, 'package') },
);

option 'repository' => (
    isa           => 'Str',
    is            => 'rw',
    documentation => 'Repository name to search for images in OBSCheck',
    cmd_aliases   => ['repo'],
    lazy          => 1,
    default       => sub { Kanku::Config::Defaults->get(__PACKAGE__, 'repository') },
);

option 'force' => (
    isa           => 'Bool',
    is            => 'rw',
    documentation => 'Overwrite exiting KankuFile',
    cmd_aliases   => ['f'],
    lazy          => 1,
    default       => 0,
);

option 'output' => (
    isa           => 'Str',
    is            => 'rw',
    documentation => 'Name of output file',
    cmd_aliases   => ['o', 'F'],
    lazy          => 1,
    default       => 'KankuFile',
);

option 'pool' => (
    isa           => 'Str',
    is            => 'rw',
    documentation => 'libvirt storage pool',
    lazy          => 1,
    default       => sub { Kanku::Config::Defaults->get('Kanku::Handler::CreateDomain', 'pool_name') },
);

option 'apiurl' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'a',
  documentation => 'OBS api url',
  default       =>  sub { Kanku::Config::Defaults->get(__PACKAGE__, 'apiurl') },
);

option 'template' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'T',
  documentation => 'Template (e.g. vagrant)',
  default       =>  sub { Kanku::Config::Defaults->get(__PACKAGE__, 'template') },
);

option 'box' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'b',
  documentation => 'Box name for vagrant images',
  default       =>  sub { Kanku::Config::Defaults->get(__PACKAGE__, 'box') },
);


BEGIN {
  Kanku::Config->initialize();
};

sub run {
  my ($self)  = @_;
  my $logger  = Log::Log4perl->get_logger;
  my $out     = $self->output;

  if ( -f $out ) {
    if ($self->force) {
      unlink $out || croak("Could not remove '$out': $!");
    } else {
      $logger->warn("$out already exists.");
      $logger->warn('  Please remove first if you really want to initalize again.');
      exit 1;
    }
  }

  if ($self->memory !~ /^\d+[kmgtp]$/i ) {
    $logger->error('Please specify a valid memory value including a Unit!');
    exit 1;
  }

  my $template_path = Kanku::Config::Defaults->get(__PACKAGE__, 'template_path');
  $logger->info("Using template_path: $template_path");

  my $config = {
    INCLUDE_PATH => $template_path,
    INTERPOLATE  => 1,               # expand "$var" in plain text
  };

  # create Template object
  my $template  = Template->new($config);

  # define template variables for replacement
  my $vars = {
	domain_name   => $self->domain_name,
        domain_memory => $self->memory,
	domain_cpus   => $self->vcpu,
	default_job   => $self->default_job,
        project       => $self->project,
        package       => $self->package,
        repository    => $self->repository,
        pool          => $self->pool,
	apiurl        => $self->apiurl,
        arch          => Kanku::Config->instance->cf->{'arch'},
        box           => $self->box,
  };

  my $output = q{};
  # process input template, substituting variables
  $template->process($self->template.'.tt2', $vars, $out)
               || croak($template->error()->as_string());

  $logger->info("$out written");

  for my $i (qw{domain_name domain_memory domain_cpus default_job
                project package repository pool}) {
    $logger->debug($i.': '.$vars->{$i});
  }
  $logger->info('Now you can make your modifications');
  $logger->info('Or start you new VM:');
  $logger->info(q{});
  $logger->info('kanku up');

  return;
}

__PACKAGE__->meta->make_immutable;

1;

__DATA__
