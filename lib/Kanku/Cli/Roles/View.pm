package Kanku::Cli::Roles::View;

use Moose::Role;

use Carp;
use Template;
use File::Spec;

use Data::Dumper;
use JSON::XS;
use YAML::PP;

use Kanku::Config::Defaults;

has include_path => (
  is      => 'rw',
  isa     => 'ArrayRef',
  lazy    => 1,
  builder => '_build_include_path',
);
sub _build_include_path {
  return [
    File::Spec->catdir($::ENV{HOME}, '.config', 'kanku', 'views', 'cli'),
    File::Spec->catdir($::ENV{HOME}, '.kanku', 'views', 'cli'),
    File::Spec->catdir(
      Kanku::Config::Defaults->get('Kanku::Config::GlobalVars', 'views_dir'),
      'cli',
    ),
  ],
}

sub view {
  my ($self, $template, $data) = @_;

  my $tt = Template->new({
    INCLUDE_PATH  => $self->include_path,
    INTERPOLATE   => 1,
    POST_CHOMP    => 1,
    PLUGIN_BASE   => 'Template::Plugin::Filter',
  });

  # process input template, substituting variables
  $tt->process($template, $data) || croak($tt->error()->as_string());

  return;
}

sub render_template {
  my ($self, $data) = @_;

  my $tt = Template->new({
    INCLUDE_PATH  => $self->include_path,
    INTERPOLATE   => 1,
    POST_CHOMP    => 0,
    PLUGIN_BASE   => 'Template::Plugin::Filter',
  });
  my $result;
  if (ref($data) eq 'HASH') {
    $data->{fillup_with_dots} = sub {
	my $r = $_[1] - length($_[0]) - 1;
	return (($_[0]) ? "$_[0] " : '.' ) . '.' x $r;
    };
  }
  # process input template, substituting variables
  $tt->process($self->template, $data, \$result) || croak($tt->error()->as_string());

  return $result;
}

sub print_formatted {
  my ($self, $data) = @_;
  my $format = $self->format;
  my $func = {
    dumper => \&Data::Dumper::Dumper,
    json   => \&JSON::XS::encode_json,
    pjson   => sub { return JSON::XS->new->pretty(1)->encode(@_) },
    yaml   => \&YAML::PP::Dump,
    none   => sub { return "$_[0]\n" },
    view   => sub { $self->render_template($_[0]); },
  };

  croak "Illegal format: $format" unless (ref($func->{$format}) eq 'CODE');

  print $func->{$format}->($data);
}

1;
