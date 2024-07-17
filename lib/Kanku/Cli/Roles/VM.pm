package Kanku::Cli::Roles::VM;

use strict;
use warnings;
use MooseX::App::Role;
use Kanku::Config;

option 'domain_name' => (
  is            => 'rw',
  cmd_aliases   => [qw/d domain-name/],
  documentation => 'name of domain to open console',
  lazy          => 1,
  builder       => '_build_domain_name',
);
sub _build_domain_name {
  my ($self) = @_;
  return $self->cfg->config->{domain_name} || q{};
}

has cfg => (
  isa           => 'Object',
  is            => 'rw',
  lazy          => 1,
  builder       => '_build_cfg',
);
sub _build_cfg {
  my ($self) = @_;
  Kanku::Config->initialize(class => 'KankuFile');
  my $cfg = Kanku::Config->instance();
  $cfg->file($self->file);
  return $cfg;
}

option 'file' => (
  isa           => 'Str',
  is            => 'rw',
  documentation => 'KankuFile to use',
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

1;
