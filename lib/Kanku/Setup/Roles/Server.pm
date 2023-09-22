package Kanku::Setup::Roles::Server;

use Moose::Role;
use Net::Domain qw/hostfqdn/;
use Sys::Hostname qw/hostname/;
with 'Kanku::Setup::Roles::Common';

has _dbfile => (
        isa     => 'Str',
        is      => 'rw',
        lazy    => 1,
        default => sub { $_[0]->app_root."/var/db/kanku-schema.db" }
);

has _apache => (
        isa     => 'Bool',
        is      => 'rw',
);

has _ssl => (
        isa     => 'Bool',
        is      => 'rw',
);

sub _configure_apache {
  my $self    = shift;
  my $logger  = $self->logger;

  $logger->debug("Enabling apache modules proxy, rewrite, headers");

  my @mod_list = qw/proxy proxy_http proxy_wstunnel rewrite headers/;

  if ($self->_ssl) {
    push @mod_list, 'proxy_https';
    $self->_run_system_cmd("a2enflag", 'SSL');
  }

  for my $mod (@mod_list) {
    $self->_run_system_cmd("a2enmod", $mod);
  }

  $self->_create_config_from_template(
    "kanku.conf.mod_proxy.tt2",
    "/etc/apache2/conf.d/kanku.conf",
    {kanku_host => hostfqdn() || hostname()}
  );

  $self->_configure_apache_ssl();
  if (
    $self->_run_system_cmd("systemctl", "enable", "apache2")->{return_code}
  ) {
    die "Error while enabling apache2"
  }
  if (
    $self->_run_system_cmd("systemctl", "restart", "apache2")->{return_code}
  ) {
    die "Error while restart apache2"
  }
}

sub _configure_apache_ssl {
  my $self      = shift;
  my $logger    = $self->logger;
  my $data      = {};
  my $chainfile = (-f '/etc/apache2/ssl.crt/chain.crt') ? '/etc/apache2/ssl.crt/chain.crt' : q{};

  $data->{chainfile} = $chainfile;

  if (! $self->_ssl ) {
    $logger->debug("No SSL confguration requested");
    return 0;
  }

  $self->_create_config_from_template(
    "kanku-vhost.conf.tt2",
    "/etc/apache2/vhosts.d/kanku-vhost.conf",
    $data,
  );

}

1;
