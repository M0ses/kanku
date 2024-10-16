package Kanku::Notifier::Console;

use Moose;
use Template;
use Log::Log4perl::Level;

use Kanku::Config;

with 'Kanku::Roles::Notifier';
with 'Kanku::Roles::Logger';

sub notify {
  my ($self, $text) = @_;

  #my $template_path = Kanku::Config->instance->views_dir . '/notifier/';

  #$self->logger->debug("Using template_path: $template_path");

  my $config = {
    #INCLUDE_PATH  => $template_path,
    INTERPOLATE   => 1,
    POST_CHOMP    => 1,
    PLUGIN_BASE   => 'Template::Plugin',
  };

  # create Template object
  my $template  = Template->new($config);
  my $input     = $self->options->{template};
  my $output    = '';

  # process input template, substituting variables
  $template->process(\$input, $self->get_template_data(), \$output)
               || die $template->error()->as_string();

  # Take 'fatal' as fallback because it's the lowest loglevel
  my $ll = $self->options->{loglevel} || 'fatal';
  my $ll2int = {
    trace => $TRACE,
    debug => $DEBUG,
    info  => $INFO,
    warn  => $WARN,
    error => $ERROR,
    fatal => $FATAL,
  };
  my $loglevel = $ll2int->{$ll};
  if ($loglevel) {
    $self->logger->log($loglevel, $output);
  } else {
    $self->logger->error("Unknown loglevel configured: '$ll'");
  }
  return;
}

1;

__END__

=head1 NAME

Kanku::Notifier::Console

=head1 SYNOPSIS

  notifiers:
    -
      use_module: Kanku::Notifier::Console
      options:
	template: |+
	  Hello M0ses,
	  Please visit our new website http://[% context.ipaddress %]
	loglevel: info
      states: succeed

=head1 DESCRIPTION

This notifier module allows you to print a message on the consoel

=head1 SEE ALSO

L<Template::Toolkit>

=cut
