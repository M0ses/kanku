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
package Kanku::Cli::Init;

use MooseX::App::Command;
extends qw(Kanku::Cli);

use Template;
use Carp;
use Try::Tiny;
use Kanku::Config;
use Kanku::Config::Defaults;
use Kanku::Util::VM::Image;

command_short_description  'create KankuFile in your current working directory';

command_long_description '
This command creates KankuFile in your current working directory
';

option 'default_job' => (
  isa           => 'Str',
  is            => 'rw',
  documentation => 'default job name in KankuFile',
  cmd_aliases   => [qw/j default-job/],
  lazy          => 1,
  default       => 'tasks',
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
  builder       => '_build_project',
);
sub _build_project {
  return Kanku::Config::Defaults->get(__PACKAGE__, 'project');
}

option 'package' => (
  isa           => 'Str',
  is            => 'rw',
  documentation => 'Package name to search for images in OBSCheck',
  cmd_aliases   => ['pkg'],
  lazy          => 1,
  builder       => '_build_package',
);
sub _build_package {
  return Kanku::Config::Defaults->get(__PACKAGE__, 'package');
}

option 'repository' => (
  isa           => 'Str',
  is            => 'rw',
  documentation => 'Repository name to search for images in OBSCheck',
  cmd_aliases   => ['repo'],
  lazy          => 1,
  builder       => '_build_repository',
);
sub _build_repository {
  return Kanku::Config::Defaults->get(__PACKAGE__, 'repository');
}

option 'force' => (
  isa           => 'Bool',
  is            => 'rw',
  documentation => 'Overwrite exiting KankuFile',
  cmd_aliases   => ['f'],
  lazy          => 1,
  default       => 0,
);

option 'kankufile' => (
  isa           => 'Str',
  is            => 'rw',
  documentation => 'Name of output file',
  cmd_aliases   => [qw/o F output/],
  lazy          => 1,
  default       => 'KankuFile',
);

option 'pool' => (
  isa           => 'Str',
  is            => 'rw',
  documentation => 'libvirt storage pool',
  lazy          => 1,
  builder       => '_build_pool',
);
sub _build_pool {
  return Kanku::Config::Defaults->get('Kanku::Handler::CreateDomain', 'pool_name');
}

option 'obsurl' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'a',
  documentation => 'OBS api url',
  lazy          => 1,
  builder       => '_build_obsurl',
);
sub _build_obsurl {
  return Kanku::Config::Defaults->get('Kanku::Config::GlobalVars', 'obsurl');
}

option 'template' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => [qw/T type/],
  documentation => 'Template (e.g. vagrant)',
  builder       => '_build_template',
);
sub _build_template {
  return Kanku::Config::Defaults->get(__PACKAGE__, 'template');
}

option 'box' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'b',
  documentation => 'Box name for vagrant images',
  builder       => '_build_box',
);
sub _build_box {
  return Kanku::Config::Defaults->get(__PACKAGE__, 'box');
}

option 'domain_name' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => [qw/d domain-name/],
  documentation => 'Name for Kanku VM',
  builder       => '_build_domain_name',
);
sub _build_domain_name {
  return Kanku::Config::Defaults->get(__PACKAGE__, 'domain_name');
}

sub run {
  my ($self)  = @_;
  Kanku::Config->initialize();
  my $ret     = 0;
  my $logger  = $self->logger;
  my $kf      = $self->kankufile;

  if ( -f $kf ) {
    if ($self->force) {
      if (! unlink $kf) {
        $logger->error("Could not remove `$kf`: $!");
        return 1;
      } else {
        $logger->info("Removed `$kf` successfully");
      }
    } else {
      $logger->fatal("File `$kf` already exists.");
      $logger->error("Please remove the file `$kf` manually or use the `--force` option to overwrite it");
      return 1;
    }
  }

  my $memory;
  try {
    $memory = Kanku::Util::VM::Image->string_to_bytes($self->memory);
  } catch {
    $logger->fatal($_);
    $ret = 1;
  };

  return $ret if $ret;

  my $template_path = Kanku::Config::Defaults->get(__PACKAGE__, 'template_path');
  $logger->info("Using template_path: `$template_path`");

  my $config = {
    INCLUDE_PATH => $template_path,
    INTERPOLATE  => 1,               # expand "$var" in plain text
  };

  # create Template object
  my $template  = Template->new($config);

  # define template variables for replacement
  my $vars = {
	domain_name   => $self->domain_name,
        domain_memory => $memory,
	domain_cpus   => $self->vcpu,
	default_job   => $self->default_job,
        project       => $self->project,
        package       => $self->package,
        repository    => $self->repository,
        pool          => $self->pool,
	obsurl        => $self->obsurl,
        box           => $self->box,
        arch          => Kanku::Config::Defaults->get(
	  'Kanku::Config::GlobalVars',
	  'arch',
	),
  };

  # process input template, substituting variables
  if (!
    $template->process(
      $self->template.'.tt2',
      $vars,
      $kf,
    )
  ) {
    $logger->error($template->error()->as_string());
    return 1;
  }

  $logger->info("KankuFile `$kf` written");

  $logger->trace("\$vars->{$_} = '$vars->{$_}'") for (keys %$vars);
  $logger->info("Now you can make your modifications in `$kf`");
  $logger->warn('To start you new VM execute:');
  $logger->warn(q{});
  $logger->warn('kanku up');

  return 0;
}

__PACKAGE__->meta->make_immutable;

1;
