package Kanku::Setup::Server::Distributed;

use Moose;
use Path::Tiny;
use Net::Domain qw/hostfqdn/;

with 'Kanku::Setup::Roles::Common';
with 'Kanku::Setup::Roles::Server';
with 'Kanku::Roles::Logger';

has [qw/mq_host mq_vhost mq_user mq_pass/] => (is=>'ro','isa'=>'Str');
has 'ca_path' => (
  is      =>'rw',
  isa     =>'Object',
  lazy    => 1,
  default => sub {
    path('/etc/kanku/ca');
  }
);

has 'host' => (
  is      =>'rw',
  isa     =>'Str',
  lazy    => 1,
  default => sub {
     hostfqdn() || $ENV{HOSTNAME};
  }
);

has 'ca_pass' => (
  is      =>'rw',
  isa     =>'Str',
  lazy    => 1,
  default => ''
);

# TODO: Check if lazy and default are still required
has 'cacertfile' => (
  is      =>'rw',
  isa     =>'Object',
);

# TODO: Check if lazy and default are still required
has 'certfile' => (
  is      =>'rw',
  isa     =>'Object',
);

# TODO: Check if lazy and default are still required
has 'keyfile' => (
  is      =>'rw',
  isa     =>'Object',
);

has 'ovs_ip_prefix' => (
  is      =>'rw',
  isa     =>'Str',
  lazy    => 1,
  default => '192.168.199',
);

sub setup {
  my $self    = shift;
  my $logger  = $self->logger;

  $logger->info("Server mode setup starting!");
  $self->_distributed(1);

  $logger->debug("Running server setup");


  $self->_dbfile('/var/lib/kanku/db/kanku-schema.db');

  $self->user("kankurun");

  $self->_setup_database();

  $self->_create_ca;

  $self->_create_server_cert;

  $self->_configure_apache if $self->_apache;

  $self->_configure_libvirtd_access();

  $self->_set_sudoers();

  $self->_create_ssh_keys;

  $self->_setup_rabbitmq;

  $self->_setup_nested_kvm;

  my $gconf = "/etc/kanku/kanku-config.yml";

  $self->_backup_config_file($gconf);

  my $arch = Kanku::Util::get_arch();
  my $arch2repo = {
    x86_64  => 'devel:kanku:images',
    aarch64 => 'devel:kanku:images:aarch64',
  };

  $self->_create_config_from_template(
    "kanku-config.yml.tt2",
    $gconf,
    {
       db_file        => $self->_dbfile,
       use_publickey  => 1,
       distributed    => 1,
       rabbitmq_user  => $self->mq_user,
       rabbitmq_pass  => $self->mq_pass,
       rabbitmq_vhost => $self->mq_vhost,
       rabbitmq_host  => $self->mq_host || 'localhost',
       cacertfile     => $self->cacertfile,
       ovs_ip_prefix  => $self->ovs_ip_prefix,
       cache_dir      => '/var/cache/kanku',
       network_name   => $self->network_name,
       arch           => $arch,
       official_image_repo => $arch2repo->{$arch},
       host_interface => $self->host_interface,
    }
  );

  $logger->info("Created $gconf!");

  $self->_create_default_pool;

  $self->_create_default_network;

  $self->_setup_ovs_hooks;

  $logger->info("Server mode setup successfully finished!");
  $logger->info("To make sure libvirtd is coming up properly we recommend a reboot");

  $self->logger->fatal("PLEASE REMEMBER YOUR CA PASSWORD: ".$self->ca_pass) if $self->ca_pass;

  return;
}

sub _create_ca {
  my ($self) = @_;
  my @cmd;
  return if ( -d $self->ca_path);


  my @alphanumeric = ('a'..'z', 'A'..'Z', 0..9);
  my $pass = join '', map $alphanumeric[rand @alphanumeric], 0..12;
  $self->ca_pass($pass);

  # create all directories
  $self->ca_path->mkdir;
  for my $path (qw/certs crl csr newcerts private/) {
    path($self->ca_path, $path)->mkdir;
  }
  path($self->ca_path, "private")->chmod(0700);

  # create index.txt file
  my $index_txt = path($self->ca_path, 'index.txt');
  $index_txt->touch;

  # create index.txt file
  my $index_txt_attr = path($self->ca_path, 'index.txt.attr');
  $index_txt_attr->spew("unique_subject = yes");

  # create serial file
  my $serial    = path($self->ca_path, 'serial');
  $serial->spew("1000");

  # create openssl.cnf
  my $openssl_cnf = path($self->ca_path, "openssl.cnf");
  $self->_create_config_from_template(
    "openssl.cnf.tt2",
    $openssl_cnf->stringify,
    {
       ca_path        => $self->ca_path,
    }
  );

  # create key file
  my $ca_pass = $self->ca_pass;

  my $ca_key_file = path($self->ca_path, '/private/ca.key.pem');
  @cmd = ('openssl', 'genrsa', '-passout', 'stdin',
    '-aes256', '-out', $ca_key_file->stringify, '4096');

  $self->logger->debug("Command: '@cmd'");
  open(PIPE, "| @cmd");
  print PIPE $ca_pass;
  close PIPE;
  $ca_key_file->chmod(0600);

  # create cert file
  $self->cacertfile(path($self->ca_path, qw/certs ca.cert.pem/));
  @cmd= (
    'openssl', 'req', '-passin', 'stdin',
    '-config', $openssl_cnf->stringify,
    '-key', $ca_key_file->stringify,
    '-new', '-x509', '-days', 7300, '-sha256', '-extensions', 'v3_ca',
    '-out', $self->cacertfile->stringify
  );
  $self->logger->debug("Command: '@cmd'");
  open(PIPE2, "| @cmd");
  print PIPE2 "$ca_pass\n\n\n\n\n\nAUTO CA\n\n";
  close PIPE2;

}

sub _create_server_cert {
  my ($self, %opts)   = @_;
  my $hostname        = $self->host;
  my $ca_pass         = $self->ca_pass;
  my $openssl_cnf     = path($self->ca_path, "openssl.cnf");
  my @cmd;

  # create key file
  my $key_file = $self->keyfile(path($self->ca_path, "private/$hostname.key.pem"));

  return if $key_file->exists;

  @cmd = ('openssl', 'genrsa', '-out', $self->keyfile, '4096');
  $self->logger->debug("Command: '@cmd'");
  $self->_run_system_cmd(@cmd);
  $self->keyfile->chmod(0600);

  # create dns hostnames for signing request:
  my $DNS_NAMES;
  my $counter=0;
  for my $dns ("localhost", "127.0.0.1", $self->host) {
    next if (! $dns);
    $DNS_NAMES .= "DNS.$counter = $dns\n";
    $counter++;
  }

  # create signing request
  my $cfg = 'prompt = no
distinguished_name  = req_distinguished_name

[req_distinguished_name]
countryName = CC
stateOrProvinceName     = Kanku Autogen State or Province
localityName            = Kanku Autogen Locality
organizationName        = Kanku Autogen Organisation
organizationalUnitName  = Kanku Autogen Organizational Unit
commonName              = '.$self->host.'
emailAddress            = test@email.address

[req]
req_extensions = v3_req
distinguished_name  = req_distinguished_name
attributes    = req_attributes
x509_extensions = v3_ca

[req_attributes]

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[ v3_ca ]
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer
basicConstraints = CA:false
basicConstraints = critical,CA:FALSE
keyUsage = digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
'.$DNS_NAMES.'
';
  $self->logger->debug("SSL CSR CONFIG: $cfg");

  my $csr_file = path($self->ca_path, "csr/$hostname.csr.pem");

  @cmd= (
    'openssl', 'req',
    '-config', '/dev/stdin', '-batch',
    '-key', $self->keyfile->stringify,
    '-new', '-sha256',
    '-out', $csr_file->stringify
  );

  $self->logger->debug("Command: '@cmd'");
  open(PIPE2, "| @cmd");
  print PIPE2 $cfg;
  close PIPE2;

  $cfg = 'prompt = no
[ server_cert ]
# Extensions for server certificates (`man x509v3_config`).
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName                  = @alt_names

[alt_names]
'.$DNS_NAMES.'
';


  # sign cert
  $ENV{CA_PASS} = $ca_pass;
  $self->certfile(path($self->ca_path, "certs/$hostname.cert.pem"));
  @cmd = (
    'openssl', 'ca',
    '-config', $openssl_cnf->stringify,
    '-extensions', 'server_cert', '-extfile', '/dev/stdin',
    '-days', '375', '-notext', '-md', 'sha256', '-batch',
    '-in', $csr_file, '-out', $self->certfile->stringify,
    '-passin', 'env:CA_PASS'
  );
  $self->logger->debug("Command: '@cmd'");
  open(PIPE2, "| @cmd");
  print PIPE2 $cfg;
  close PIPE2;
  $self->certfile->chmod(0444);

  if ($self->_apache) {
    my $apachecrt = path("/etc/apache2/ssl.crt/server.crt");
    $self->certfile->copy($apachecrt) unless $apachecrt->exists;
    $apachecrt->chmod(0444);

    my $apachekey = path("/etc/apache2/ssl.key/server.key");
    $self->keyfile->copy($apachekey) unless $apachekey->exists;
    $apachekey->chmod(0440);
  }

  my $dir = path("/etc/rabbitmq/server");
  $dir->mkdir;

  my $ncert = path($dir, $self->certfile->basename);
  $self->certfile->copy($ncert) unless $ncert->exists;
  $self->certfile($ncert);

  my $nkey = path($dir, $self->keyfile->basename);
  $self->keyfile->copy($nkey) unless $nkey->exists;
  $self->keyfile($nkey);
  $self->keyfile->chmod(0660);
  my $gid = getgrnam('rabbitmq');
  chown(0, $gid, $self->keyfile);

  return;
}

sub _setup_rabbitmq {
  my ($self) = @_;
  # install package rabbitmq-server
  # zypper -n in rabbitmq-server
  my @lines = path("/usr/lib/systemd/system/epmd.socket")->lines;
  my @out;

  for my $line (@lines) {
    $line =~ s/127\.0\.0\.1/0.0.0.0/;
    push @out, $line;
  }

  $self->logger->debug("epmd.socket:\n@out");
  path("/etc/systemd/system/epmd.socket")->spew(@out);

  $self->_create_config_from_template(
    "rabbitmq.config.tt2",
    "/etc/rabbitmq/rabbitmq.config",
    {
       cacertfile => $self->cacertfile,
       certfile   => $self->certfile,
       keyfile    => $self->keyfile,
    }
  );

  # reload systemd
  $self->_run_system_cmd("systemctl", "daemon-reload");
  $self->_run_system_cmd("systemctl", "start", "rabbitmq-server");
  $self->_run_system_cmd("systemctl", "enable", "rabbitmq-server");
  # Wait for rabbitmq to get ready
  my $rcode = 1;
  while ($rcode) {
    my $result = $self->_run_system_cmd("rabbitmqctl","status");
    $rcode = $result->{return_code};
    sleep 1;
  }
  # Add vhost if needed
  my $result = $self->_run_system_cmd("rabbitmqctl","list_vhosts");
  $self->_run_system_cmd("rabbitmqctl","add_vhost", $self->mq_vhost) if $result->{stdout} !~ m#/kanku#;

  # Add user if needed
  $result = $self->_run_system_cmd("rabbitmqctl","list_users");
  $self->_run_system_cmd("rabbitmqctl","add_user", $self->mq_user, $self->mq_pass) if $result->{stdout} !~ m#kanku#;

  $self->_run_system_cmd("rabbitmqctl","set_permissions", "-p", $self->mq_vhost, $self->mq_user, '.*', '.*', '.*');
}

sub _setup_ovs_hooks {
  my ($self) = @_;

  # Install openvswitch and openvswitch-switch
  #
  # '''zypper -n in openvswitch openvswitch-switch'''
  $self->_run_system_cmd("systemctl", "start", "openvswitch");
  $self->_run_system_cmd("systemctl", "enable", "openvswitch");

  path("/etc/libvirt/hooks/network")->spew("#!/bin/bash

/usr/bin/perl /usr/lib/kanku/network-setup.pl \$@
");

  path("/etc/libvirt/hooks/network")->chmod(0755);

  $self->_run_system_cmd("systemctl", "restart", "libvirtd.service");
}

1;
