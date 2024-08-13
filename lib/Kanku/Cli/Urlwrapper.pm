# Copyright (c) 2016 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program (see the file COPYING); if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#
package Kanku::Cli::Urlwrapper;

use MooseX::App::Command;
extends qw(Kanku::Cli);

use File::Path qw/make_path/;

use Net::OBS::LWP::UserAgent;

use Kanku::Util::VM;

command_short_description  'open kanku url (kanku:// or kankus://)';
command_long_description   '
This command lists the standard kanku images which are based on (open)SUSEs JeOS images.

';

option 'url' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'u',
  documentation => 'URL for KankuFile ',
);

option 'outdir' => (
  isa           => 'Str',
  is            => 'rw',
  cmd_aliases   => 'd',
  documentation => 'Output directory (default: temporary directory)',
  default       => sub {
    my $dir = $_[0]->_outdir->dirname;
    return "$dir";
  },
);

has '_outdir' => (
  isa           => 'Object',
  is            => 'rw',
  default       => sub {
    return File::Temp->newdir();
  },
);

has '_exit_code' => (
  isa           => 'Int',
  is            => 'rw',
  default       => 0,
);

has '_cwd' => (
  isa           => 'Str',
  is            => 'rw',
);

has _hub_url => (
  isa           => 'Str',
  is            => 'rw',
  default       => 'https://raw.githubusercontent.com/M0ses/kanku/master/hub.txt',
);

has _must_be_signed => (
  isa           => 'Bool',
  is            => 'rw',
  default       => 0,
);

has _signature_file => (
  isa           => 'Str',
  is            => 'rw',
  lazy          => 1,
  default       => sub {
    my ($self) = @_;
    return $self->outdir.'/KankuFile.asc';
  },
);

has _KankuFile => (
  isa           => 'Str',
  is            => 'rw',
  lazy          => 1,
  default       => sub {
    my ($self) = @_;
    return $self->outdir.'/KankuFile';
  },
);

sub run {
  my ($self) = @_;
  my $url    = $self->url || $self->select_url;
  $url =~ s#kanku(|s)://#http$1://#;
  $self->ask_for_outdir;
  $self->_cwd(cwd());
  chdir $self->outdir;
  $self->get_file($url, $self->_KankuFile);
  $self->check_signature($url);
  $self->check_domain();
  `kanku up --skip_all_checks`;
  $self->query_exit(1, "Testing $url");

  chdir $self->_cwd;
  return $self->_exit_code;
}

sub ask_for_outdir {
  my ($self) = @_;
  print "Where should the Kankufile be saved (empty for temporary directory)?\n";
  my $dir = <STDIN>;
  chomp($dir);
  if ($dir) {
    if (! -d $dir) {
      make_path($dir) || die "Could not create $dir: $!";
    }
    $self->outdir($dir);
  } elsif ( -f "$dir/KankuFile") {
    print "$dir/KankuFile already exists. Would you like to overwrite? [yN]\n";
    my $ask = <STDIN>;
    chomp $ask;
    exit 1 unless ($ask =~ /^y/i);
  }
}

sub _slurp {
  my ($self, $file) = @_;
  my $fh;
  open($fh, '<', $file) || die "Could not open $file: $!\n";
  my @ret = <$fh>;
  close $fh;
  return @ret;
}

sub _spew {
  my ($self, $file, $c) = @_;
  my $fh;
  open($fh, '>', $file) || die "Could not open $file: $!\n";
  print $fh $_ for @{$c};
  close $fh || die "Could not close $file: $!\n";
}

sub check_domain {
  my ($self) = @_;
  my $domain;
  my @lines = $self->_slurp($self->_KankuFile);
  foreach my $l (@lines) {
    if ($l =~ /^domain_name:\s*(.*)/) {
      $domain = $1;
      last;
    }
  }

  die "Could not find domain_name in " unless $domain;

  my $remove_domain;
  my $vm = Kanku::Util::VM->new();

  for my $dom ( $vm->vmm->list_all_domains() ) {
    if ($dom->get_name eq $domain) {
      print "$domain already exists!\n\n";
      print "1) reconfigure KankuFile\n";
      print "2) remove domain\n";
      print "*) exit\n";
      my $sel = <STDIN>;
      chomp $sel;
      if ($sel eq "1") {
        print "Please enter new domain name\n";
        my $new_domain_name = <STDIN>;
        chomp $new_domain_name;
        my @in = $self->_slurp($self->_KankuFile);
        my @out;
        for my $l (@in) {
          if ($l =~ s/domain_name:.*/domain_name: $sel/) {
            print "$domain\n";
            print $l;
          }
          push @out, $l;
        }
        $self->_spew($self->_KankuFile, \@in);
      } elsif ($sel eq "2") {
        `kanku destroy`;
        die "Could not remove domain $dom\n" if $?;
      } else {
        exit 3;
      }
    }
  }
}

sub check_signature {
  my ($self, $url) = @_;

  try {
    $self->get_file($url.".asc", $self->_signature_file);
    $self->_check_signature;
  } catch {
    if ($self->_must_be_signed) {
      croak("KankuFile is marked as signed but no valid signature found: $_[0]\n");
    }
    $self->query_for_sig;
  };
}

sub _check_signature {
  my ($self) = @_;
  my $cmd = 'gpg --verify '.$self->_signature_file.' '.$self->_KankuFile;
  my $out = `$cmd`;
  if ($? >> 8 > 0) {
    die $out if ($self->_must_be_signed);
    $self->query_for_sig;
  }
}

sub query_for_sig {
    print "Signature checking failed!\n";
    print "It's not recommended to proceed\n";
    print "Proceed anyway? (y|N)\n";
    my $sel = <STDIN>;
    if ($sel =~ /y/i) {
      print "YOU HAVE BEEN WARNED ;-)\n";
    } else {
      exit 1;
    }
}

sub query_exit {
  my ($self, $exit, $msg) = @_;

  print "$msg\n" if $msg;
  print "Keep shell alive? (y|Y|n|N)\n";
  my $in = <STDIN>;

  exec $ENV{'SHELL'} if $in =~ /^y/i;

  chdir $self->_cwd;
  exit $exit;
}

sub select_url {
  my ($self) = @_;
  my $_url;

  my $cnt = 1;
  my $urls = $self->get_hub_data;

  print "Please select a KankuFile!\n";
  foreach my $t_url (@{$urls}) {
    my $tt_url = $t_url->{url};
    $tt_url =~ s#.*/(.*)$#$1#;
    print "$cnt. $tt_url\n";
    $cnt++;
  }

  my $in = <STDIN>;
  chomp $in;
  my $data = @{$urls}[int($in)-1];
  $self->_must_be_signed($data->{signed});
  return $data->{url};
}

sub get_hub_data {
  my ($self) = @_;
  my $data   = [];
  my $ua     = Net::OBS::LWP::UserAgent->new();
  my $response = $ua->get($self->_hub_url);
  if ($response->is_success) {
    my  @lines = split(/\n/, $response->decoded_content);
    for my $line (@lines) {
      unless ($line =~ /^#/) {
        my ($url, $signed) = split(/;/, $line, 2);
        push @{$data}, {url=>$url, signed=>$signed};
      }
    }
  } else {
    die $response->status_line;
  }

  return $data;
}

sub get_file {
 my ($self, $url, $outfile) = @_;
 my $fh;
 open($fh, '>', $outfile) || die "Could not open $outfile: $!\n";
 my $ua = Net::OBS::LWP::UserAgent->new();
 print "Downloading $url\n";
 my $response = $ua->get($url);
  if ($response->is_success) {
    print $fh $response->decoded_content;
    close $fh || die "Could not close $outfile: $!\n";
  } else {
    die $response->status_line;
  }
  return 1;
}
__PACKAGE__->meta->make_immutable;

1;
