package Kanku::Notifier::Console;

use Moose;
use Template;
use Log::Log4perl::Level;

use Kanku::Config;

with 'Kanku::Roles::Notifier';
with 'Kanku::Roles::Logger';

sub notify {
  my ($self) = @_;

  my $config = {
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

  my $fh = (uc($self->options->{template}) eq 'STDERR') ? \*STDERR : \*STDOUT;
  print $fh $output;
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
