package Kanku::Notifier::NSCAng;

use Moose;
use Net::NSCAng::Client;
#use Template;
use Data::Dumper;
use Kanku::Config;

with 'Kanku::Roles::Notifier';
with 'Kanku::Roles::Logger';

=head1 NAME

Kanku::Notifier::NSCAng - A kanku notification module for Nagios NSCAng

=head1 DESCRIPTION

Send a notification to a nagios NSCAng daemon.

=head1 CONFIGURATION

=head2 GLOBAL

in /etc/kanku/kanku-config.yml:

 Kanku::Notifier::NSCAng:
   init:
     remote_host: ...
     remote_port: ...
     remote_identity: ...
     remote_password: ...
   send_report:
     hostname: <hostname_in_icinga>


=head2 JOB CONFIG FILE

  notifiers:
    -
      use_module: Kanku::Notifier::NSCAng
      options:
	send_report:
	  hostname: <hostname_in_icinga>
	  service:  <servicename_in_icinga>
        state_map:         # optional
          succeed: 0       # works with Int
          failed: WARNING  # works with Strings (OK, WARNING, CRITICAL, UNKNOWN)
          skipped: unknown # is case insensitive
      states: failed,succeed


=head1 SEE ALSO

L<Net::NSCA::Client>

=cut

sub notify {
  my $self = shift;

  my $template_path = Kanku::Config->instance->views_dir . '/notifier/';
  my $cfg              = Kanku::Config->instance->config;
  my $pkg              = __PACKAGE__;

  $self->logger->debug("Using template_path: $template_path");

  my $config = {
    INCLUDE_PATH  => $template_path,
    INTERPOLATE   => 1,               # expand "$var" in plain text
    POST_CHOMP    => 1,
    PLUGIN_BASE   => 'Template::Plugin',
  };

  # create Template object
  my $template  = Template->new($config);
  my $input     = 'nsca.tt';
  my $output    = '';
  # process input template, substituting variables
  $template->process($input, $self->get_template_data(), \$output)
               || die $template->error()->as_string();
  $output =~ s/\n/\\n/g;

  my $nstat = $self->_state2status;

  $self->logger->debug("Sending report (status: $nstat  with message: ".$self->short_message);

  my $global_init_opts = $cfg->{$pkg}->{init}   || {};
  my $init_opts        = $self->options->{init} || {};
  my %iopts            = (%{$global_init_opts}, %{$init_opts});

  if (! %iopts) {
      $self->logger->error("No configuration found for init. Please check the docs!");
  }
  my $opts = {};
  $opts->{port} = $cfg->{$pkg}->{init}->{remote_port} if $cfg->{$pkg}->{init}->{remote_port};

  my $c = Net::NSCAng::Client->new(
    $cfg->{$pkg}->{init}->{remote_host},
    $cfg->{$pkg}->{init}->{remote_identity},
    $cfg->{$pkg}->{init}->{remote_password},
    node_name => $cfg->{$pkg}->{send_report}->{hostname},
    %{$opts},
  );

  $c->svc_result($nstat, $output, {
    node_name => $self->options->{send_report}->{hostname} || $cfg->{$pkg}->{send_report}->{hostname} ,
    svc_description => $self->options->{send_report}->{service}
  });

  return;
}

sub _state2status {
  my ($self) = @_;
  my $status_map = {
    0 		=> 0,
    1 		=> 1,
    2 		=> 2,
    3 		=> 3,
    'OK'	=> 0,
    'WARNING' 	=> 1,
    'CRITICAL' 	=> 2,
    'UNKNOWN' 	=> 3,
  };

  my $state_map = {
    'succeed' 		=> 'OK',
    'failed'		=> 'CRITICAL',
    'skipped'		=> 'UNKNOWN',
    %{$self->options->{state_map} || {}},
  };
  my $s2s = uc($state_map->{$self->state});
  return $status_map->{$s2s};
}

1;
