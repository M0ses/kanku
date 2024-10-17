package Kanku::Setup::Server::Standalone;

use Moose;

with 'Kanku::Setup::Roles::Common';
with 'Kanku::Setup::Roles::Server';
with 'Kanku::Roles::Logger';

sub setup {
  my $self    = shift;
  my $logger  = $self->logger;

  $logger->debug("Running server setup");


  $self->_dbfile(
    path('/var/lib/kanku/db/kanku-schema.db')
  );

  $self->user("kankurun");

  $self->_setup_database();

  $self->_configure_apache if $self->_apache;

  $self->_configure_libvirtd_access();

  $self->_create_config_from_template(
    "kanku-config.yml.tt2",
    "/etc/kanku/kanku-config.yml",
    {
       db_file => $self->_dbfile->stringify,
       use_publickey => 1
    }
  );

  $self->_create_default_pool;

  $self->_create_default_network;

  $self->_set_sudoers();

  $self->_create_ssh_keys;

  $self->_setup_nested_kvm;


  $logger->info("Server mode setup successfully finished!");
  $logger->info("To make sure libvirtd is coming up properly we recommend a reboot");

  return;
}

1;
