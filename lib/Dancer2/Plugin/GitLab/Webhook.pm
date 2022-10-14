package Dancer2::Plugin::GitLab::Webhook;


use strict;
use warnings;
use Dancer2::Plugin;
use Data::Dumper;

our $VERSION = '0.01';

has routes => (
    is          => 'ro',
    from_config => sub { return undef },
);


plugin_keywords 'require_webhook_secret';

sub require_webhook_secret {
    my $plugin  = shift;
    my $coderef = pop;
    my $routes  = $plugin->routes() || $plugin->dsl->log( error => 'No routes given!' );

    return sub {
        my $x_gitlab_token = $plugin->dsl->request_header('X-Gitlab-Token')
            or return $plugin->dsl->send_error( "No X-Gitlab-Token found", 403 );

	my $path = $plugin->app->request->path;
	for my $exp (keys %{$routes}) {
	  if ($path =~ /$exp/ ) {
	    my @tokens = (ref $routes->{$exp} eq 'ARRAY') ? @{$routes->{$exp}} : ($routes->{$exp});
	    for my $token (@tokens) {
	      return $coderef->($plugin) if $x_gitlab_token eq $token;
	    }
	  }
        }
        $plugin->dsl->log( info => 'Gitlab Webhook call could not be authenticated sucessful: '
                . 'Token: ' . $x_gitlab_token . 'Path: ' . $path);
        $plugin->dsl->send_error( "Not allowed", 403 );
    };
}

1;
