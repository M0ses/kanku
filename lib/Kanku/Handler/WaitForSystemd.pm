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
package Kanku::Handler::WaitForSystemd;

use Moose;
use Kanku::Util::VM;
use Kanku::Util::VM::Console;

sub _build_gui_config {[]}
has 'distributable' => (is=>'ro', isa=>'Bool', default => 1);
with 'Kanku::Roles::Handler';


has [qw/domain_name login_user login_pass/] => (is=>'rw',isa=>'Str',lazy=>1,default=>'');
has timeout => (is=>'rw',isa=>'Int',lazy=>1,default=>3600);
has delay   => (is=>'rw',isa=>'Int',lazy=>1,default=>1);

sub prepare {
  my $self = shift;

  $self->evaluate_console_credentials;

  return {
    code    => 0,
    message => "Using login_user: ". $self->login_user,
  };
}

sub execute {
  my $self   = shift;
  my $ctx    = $self->job()->context();
  my $logger = $self->logger;
  my $con;

  $con = Kanku::Util::VM::Console->new(
        domain_name => $self->domain_name,
        login_user  => $self->login_user(),
        login_pass  => $self->login_pass(),
        job_id      => $self->job->id,
        cmd_timeout => $self->timeout,
        log_file    => $ctx->{log_file} || q{},
        log_stdout  => defined ($ctx->{log_stdout}) ? $ctx->{log_stdout} : 1,
	no_wait_for_bootloader => 1,
  );

  $con->init();
  $con->login();

  $con->cmd(
    'export to='.$self->timeout.";".
    'while [ "$s" != "No jobs running." ];do '.
      's=`systemctl list-jobs`;'.
      'logger "systemctl list-jobs: $s";'.
      'sleep '.($self->delay || 1).';'.
      '[ $to -lt 0 ] && exit 1;'.
      'to=$(($to-1));'.
    'done'
  );

  $con->logout();

  return {
    code    => 0,
    message => "Startup of systemd successfully finished on domain " . $self->domain_name
  }
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Kanku::Handler::WaitForSystemd

=head1 SYNOPSIS

Here is an example how to configure the module in your jobs file or KankuFile

  -
    use_module: Kanku::Handler::WaitForSystemd
    options:
      timeout: 600

=head1 DESCRIPTION

This handler logs into serial console and waits for all systemd jobs to finish

=head1 OPTIONS

  timeout - seconds to wait for systemd

=head1 CONTEXT

=head1 DEFAULTS

=cut
