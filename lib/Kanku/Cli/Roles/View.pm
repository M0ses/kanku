package Kanku::Cli::Roles::View;

use Moose::Role;
use Carp;
use Template;
use Data::Dumper;
use JSON::XS;
use YAML::PP;
use Kanku::Config;

sub view {
  my ($self, $template, $data) = @_;

  my $tt = Template->new({
    INCLUDE_PATH  => Kanku::Config->instance->views_dir . '/cli/',
    INTERPOLATE   => 1,
    POST_CHOMP    => 1,
    PLUGIN_BASE   => 'Template::Plugin::Filter',
  });

  # process input template, substituting variables
  $tt->process($template, $data) || croak($tt->error()->as_string());

  return;
}

sub render_template {
  my ($self, $template, $data) = @_;

  my $tt = Template->new({
    INCLUDE_PATH  => Kanku::Config->instance->views_dir . '/cli/',
    INTERPOLATE   => 1,
    POST_CHOMP    => 0,
    PLUGIN_BASE   => 'Template::Plugin::Filter',
  });
  my $result;
  # process input template, substituting variables
  $tt->process($template, $data, \$result) || croak($tt->error()->as_string());

  return $result;
}

sub print_formatted {
  my ($self, $format, $data) = @_;
  my $func = {
    dumper => \&Data::Dumper::Dumper,
    json   => \&JSON::XS::encode_json,
    pjson   => sub { return JSON::XS->new->pretty(1)->encode(@_) },
    yaml   => \&YAML::PP::Dump,
    none   => sub { return "$_[0]\n" },
  };

  croak "Illegal format: $format" unless (ref($func->{$format}) eq 'CODE');

  print $func->{$format}->($data);
}

1;
