package Kanku::Cli::Roles::VM;

use strict;
use warnings;
use MooseX::App::Role;

use Cwd;
use Carp;
use File::Basename qw/dirname basename/;

use Kanku::YAML;
use Kanku::File;

###############################################################################
# BUILDER METHODS
###############################################################################
sub _build_domain_name {
  my ($self) = @_;
  return $self->kankufile_config->{domain_name} || q{};
}

sub _build_kankufile_config {
  my ($self) = @_;
  return Kanku::YAML::LoadFile(Kanku::File::lookup_file($self->file));
}

###############################################################################
# OPTIONS
###############################################################################

option 'domain_name' => (
  is            => 'rw',
  cmd_aliases   => [qw/d domain-name/],
  documentation => 'name of domain (guest VM)',
  lazy          => 1,
  builder       => '_build_domain_name',
);

option 'file' => (
  isa           => 'Str',
  is            => 'rw',
  documentation => 'KankuFile to use',
  lazy          => 1,
  default       => 'KankuFile',
);

option 'log_file' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => [qw/log-file/],
  documentation => 'path to logfile for Expect output',
  default       => q{},
);

option 'log_stdout' => (
  isa           => 'Bool',
  is            => 'rw',
  cmd_aliases   => [qw/log-stdout/],
  documentation => 'Log Expect output to stdout - (default: 1)',
  default       => 1,
);

###############################################################################
# ATTRIBUTES
###############################################################################

has kankufile_config => (
  is      => 'ro',
  isa     => 'HashRef',
  lazy    => 1,
  builder => '_build_kankufile_config',
);

1;
