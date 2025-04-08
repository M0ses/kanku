package Kanku::Cli::Roles::VM;

use strict;
use warnings;
use MooseX::App::Role;

use Cwd;
use Carp;

use Kanku::YAML;
use Kanku::File;
use Kanku::Config::Defaults;

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

sub _build_log_stdout {
  my ($self) = @_;
  return Kanku::Config::Defaults->get(ref($self), 'log_stdout');
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
  builder       => '_build_file',
);

sub _build_file {
  return $::ENV{KANKU_CONFIG} || 'KankuFile';
}

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
  builder       => '_build_log_stdout',
  lazy          => 1,
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
