package Kanku::Setup::Worker;

use Moose;
use Carp;
use Path::Tiny;
use Net::Domain qw/hostfqdn/;

with 'Kanku::Setup::Roles::Common';
with 'Kanku::Roles::Logger';

has [qw/mq_host mq_vhost mq_user mq_pass/] => (is=>'ro','isa'=>'Str');

has 'host' => (
  is      =>'rw',
  isa     =>'Str',
  lazy    => 1,
  default => sub {
     hostfqdn() || $ENV{HOSTNAME};
  }
);

has 'master' => (
  is      =>'rw',
  isa     =>'Str',
  lazy    => 1,
  default => q{},
);

has _dbfile => (
        isa     => 'Str',
        is      => 'rw',
        lazy    => 1,
        default => "/var/lib/kanku/db/kanku-schema.db",
);

sub setup {
  my ($self)    = @_;
  my $logger  = $self->logger;
  $logger->info('Starting worker setup (master: '.$self->master.')');
  if(!$self->master) {
    $logger->error('No master specified!');
    return 1;
  }

  $self->user("kankurun");

  $self->_setup_database();

  $self->_configure_libvirtd_access();

  $self->_set_sudoers();

  $self->_create_ssh_keys;

  $self->_setup_nested_kvm;

  my $gconf = "/etc/kanku/kanku-config.yml";

  $self->_backup_config_file($gconf);

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
       cache_dir      => '/var/cache/kanku',
    }
  );

  $logger->info("Created $gconf!");

  $self->_setup_ovs_hooks;

  $logger->info("Server mode setup successfully finished!");
  $logger->info("To make sure libvirtd is coming up properly we recommend a reboot");

  $logger->warn('TODO: create kanku-config.yml');
  $logger->warn('TODO: get ovs networks from master');
  $logger->warn('TODO: install keys in /root/.ssh/authorized keys');
  $logger->warn('TODO: configure openvswitch');
  $logger->error('Not implemented yet!');
}

1;

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

__END__

has [qw/mq_host mq_vhost mq_user mq_pass/] => (is=>'ro','isa'=>'Str');
has 'ca_path' => (
  is      =>'rw',
  isa     =>'Object',
  lazy    => 1,
  default => sub {
    dir('/etc/kanku/ca');
  }
);

has 'ca_pass' => (
  is      =>'rw',
  isa     =>'Str',
  lazy    => 1,
  default => ''
);

has 'cacertfile' => (
  is      =>'rw',
  isa     =>'Str',
  lazy    => 1,
  default => ''
);

has 'certfile' => (
  is      =>'rw',
  isa     =>'Str',
  lazy    => 1,
  default => ''
);

has 'keyfile' => (
  is      =>'rw',
  isa     =>'Str',
  lazy    => 1,
  default => ''
);

has 'ovs_ip_prefix' => (
  is      =>'rw',
  isa     =>'Str',
  lazy    => 1,
  default => '192.168.199'
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
    }
  );

  $logger->info("Created $gconf!");

  $self->_create_default_pool;

  $self->_create_default_network;

  $self->_setup_ovs_hooks;

  $logger->info("Server mode setup successfully finished!");
  $logger->info("To make sure libvirtd is coming up properly we recommend a reboot");

  $self->logger->fatal("PLEASE REMEMBER YOUR CA PASSWORD: ".$self->ca_pass) if $self->ca_pass;
}

sub _create_ca {
  my ($self) = @_;
  my @cmd;
  return if ( -d $self->ca_path);


  my @alphanumeric = ('a'..'z', 'A'..'Z', 0..9);
  my $pass = join '', map $alphanumeric[rand @alphanumeric], 0..12;
  $self->ca_pass($pass);

  # create all directories
  $self->ca_path->mkpath;
  for my $path (qw/certs crl csr newcerts private/) {
    dir($self->ca_path, $path)->mkpath;
  }
  chmod oct(700), dir($self->ca_path, "private")->stringify;

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

  my $ca_key_file = path($self->ca_path, '/private/ca.key.pem')->stringify;
  @cmd = ('openssl', 'genrsa', '-passout', 'stdin',
    '-aes256', '-out', $ca_key_file, '4096');

  $self->logger->debug("Command: '@cmd'");
  open(PIPE, "| @cmd");
  print PIPE $ca_pass;
  close PIPE;
  chmod oct(400), $ca_key_file;

  # create cert file
  $self->cacertfile(file($self->ca_path, 'certs/ca.cert.pem')->stringify);
  @cmd= (
    'openssl', 'req', '-passin', 'stdin',
    '-config', $openssl_cnf->stringify,
    '-key', $ca_key_file,
    '-new', '-x509', '-days', 7300, '-sha256', '-extensions', 'v3_ca',
    # '-subj', '"/CN=Kanku Autogenerated CA"',
    '-out', $self->cacertfile);
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
  $self->keyfile(path($self->ca_path, "private/$hostname.key.pem")->stringify);
  @cmd = ('openssl', 'genrsa', '-out', $self->keyfile, '4096');
  $self->logger->debug("Command: '@cmd'");
  $self->_run_system_cmd(@cmd);
  chmod oct(400), $self->keyfile;

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

  my $csr_file = path($self->ca_path, "csr/$hostname.csr.pem")->stringify;
  @cmd= (
    'openssl', 'req',
    '-config', '/dev/stdin', '-batch',
    '-key', $self->keyfile,
    '-new', '-sha256',
    '-out', $csr_file);
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
  $self->certfile(path($self->ca_path, "certs/$hostname.cert.pem")->stringify);
  @cmd = (
    'openssl', 'ca',
    '-config', $openssl_cnf->stringify,
    '-extensions', 'server_cert', '-extfile', '/dev/stdin',
    '-days', '375', '-notext', '-md', 'sha256', '-batch',
    '-in', $csr_file, '-out', $self->certfile,
    '-passin', 'env:CA_PASS'
  );
  $self->logger->debug("Command: '@cmd'");
  open(PIPE2, "| @cmd");
  print PIPE2 $cfg;
  close PIPE2;
  chmod oct(444), $self->certfile;

  if ($self->_apache) {
    my $apachecrt = "/etc/apache2/ssl.crt/server.crt";
    my $apachekey = "/etc/apache2/ssl.key/server.key";
    copy($self->certfile, $apachecrt) or die "Copy failed: $!";
    copy($self->keyfile, $apachekey)  or die "Copy failed: $!";
    chmod oct(444), $apachecrt;
    chmod oct(440), $apachekey;
  }

  my $dir = dir("/etc/rabbitmq/server");
  $dir->mkpath;
  my $ncert = $dir->stringify.'/'.path($self->certfile)->basename;
  copy($self->certfile, $ncert) or die "Copy failed: $!";
  $self->certfile($ncert);

  my $nkey = $dir->stringify.'/'.path($self->keyfile)->basename;
  copy($self->keyfile, $nkey) or die "Copy failed: $!";
  $self->keyfile($nkey);
  chmod oct(440), $self->keyfile;
  my $gid = getgrnam('rabbitmq');
  chown(0, $gid, $self->keyfile);

  return;
}

sub _setup_rabbitmq {
  my ($self) = @_;
  # install package rabbitmq-server
  # zypper -n in rabbitmq-server
  my @lines = path("/usr/lib/systemd/system/epmd.socket")->slurp;
  my @out;

  for my $line (@lines) {
    $line =~ s/127\.0\.0\.1/0.0.0.0/;
    push @out, $line;
  }

  $self->logger->debug("epmd.socket:\n@out");
  path("/etc/systemd/system/epmd.socket")->spew(\@out);

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

1;
