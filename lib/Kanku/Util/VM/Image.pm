# Copyright (c) 2015 SUSE LLC
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
package Kanku::Util::VM::Image;

use Moose;

use Sys::Virt;
use Sys::Virt::Stream;
use Expect;
use YAML;
use Template;
use Cwd;
use Net::IP;
use Kanku::Util::VM::Console;
use Data::Dumper;
use XML::XPath;
use Try::Tiny;
use File::LibMagic;

has [qw/uri pool_name vol_name source_file size format/ ]  => ( is=>'rw', isa => 'Str');


has '+uri'       => ( default => 'qemu:///system');
has '+pool_name' => ( default => 'default');
has '+format'    => ( default => 'qcow2');

has pool => (
  is => 'rw',
  isa => 'Object|Undef',
  lazy => 1,
  default => sub {
    my $self = shift;
    my $vmm = $self->vmm();
    for my $pool ( $vmm->list_all_storage_pools() ) {
      if ( $self->pool_name eq $pool->get_name ) {
        return $pool
      }
    }
    return undef;
  }
);

has vmm => (
  is => 'rw',
  isa => 'Object|Undef',
  lazy => 1,
  default => sub {
    return Sys::Virt->new(uri => $_[0]->uri);
  }
);

has logger => (
  is => 'rw',
  isa => 'Object',
  lazy => 1,
  default => sub { Log::Log4perl->get_logger(); }
);

sub create_volume {
  my $self = shift;

  $self->delete_volume();

  $self->logger->info("Creating volume '" . ($self->vol_name || '')."'");

  my $xml  = "
<volume type='file'>
  <name>" . $self->vol_name . "</name>
  <capacity unit='bytes'>". $self->get_image_size() ."</capacity>
  <target>
    <format type='".$self->format."'/>
  </target>
</volume>
";
  try {
      my $vol  = $self->pool->create_volume($xml);

      $self->_copy_volume($vol) if $self->source_file;

      return $vol;
  }
  catch {
    my ($e) = @_;
    if ( ref($e) eq 'Sys::Virt::Error' ){
      die $e->stringify();
    } else {
      die $e
    }
  };

}

sub delete_volume {
  my $self = shift;

  my @volumes = $self->pool->list_all_volumes();
  for my $vol (@volumes) {
    die "Got no vol_name\n" if (!$self->vol_name);
    $self->logger->debug("Checking volume " . ( $vol->get_name || '' ));
    if ( $vol->get_name() eq $self->vol_name()) {
      $self->logger->info("Deleting volume " . $vol->get_name);
      try {
        $vol->delete(Sys::Virt::StorageVol::DELETE_NORMAL);
      }
      catch {
        my ($e) = @_;
        if ( ref($e) eq 'Sys::Virt::Error' ){
          die $e->stringify();
        } else {
          die $e
        }
      };
    }
  }
}

sub get_image_size {
  my $self = shift;

  if ( $self->source_file ) {
    my $file = File::LibMagic->new();
    my $info = $file->info_from_filename($self->source_file);

    if ( $info->{description} =~ /^QEMU QCOW Image .* (\d+) bytes/ ) {
      return $1;
    } else {
      my @stat = stat($self->source_file);
      return $stat[7];
    }
  }

  my $sh = {
             b => 1,                   k => 1024 ,
             m => 1024*1024,           g => 1024*1024*1024,
             t => 1024*1024*1024*1024, p => 1024*1024*1024*1024*1024
           };
  if ($self->size =~ /^(\d+)([bkmgtp]m?)?/i ) {
    return $1 * $sh->{lc($2)}
  }

  die "Size of volume '".$self->vol_name."' could not be determined\n";
}

sub _copy_volume {
  my ($self, $vol) = @_;
  my $vmm  = $self->vmm();
  my $st   = $self->vmm()->new_stream();
  my $f    = $self->source_file();

  open FILE, "<$f" or die "cannot open $f: $!";

  eval {
      $vol->upload($st, 0, 0);
      my $nbytes = 1024;
      while (1) {
	  my $data;
	  my $rv = sysread FILE, $data, $nbytes;
	  if ($rv < 0) {
	      die "cannot read $f: $!";
	  }
	  last if $rv == 0;
	  while ($rv > 0) {
	      my $done = $st->send($data, $rv);
	      if ($done) {
		  $data = substr $data, $done;
		  $rv -= $done;
	      }
	  }
      }

      $st->finish();
  };

  if ($@) {
      close FILE;
      die $@;
  }

  close FILE or die "cannot save $f: $!";
}
1;