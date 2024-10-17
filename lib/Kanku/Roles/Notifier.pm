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
package Kanku::Roles::Notifier;


use Moose::Role;

requires 'notify';

has options => (is=>'rw',isa=>'HashRef',default=>sub {{}});

has short_message => ( is=>'rw', isa => 'Str', default => 'Message from kanku');
has full_message => ( is=>'rw', isa => 'Str', default => 'Please enter your full text message here');
has state => ( is=>'rw', isa => 'Str', default => '');
has duration => ( is=>'rw', isa => 'Int', default => 0);

has job_id => ( is=>'ro', isa => 'Int', required => 1);

has kanku_url => ( is=>'ro', isa => 'Undef|Str');

has context => ( is=>'ro', isa => 'HashRef', required => 1);

sub get_template_data {
    my ($self) = @_;
    return {
      short_message => $self->short_message || 'Got no message',
      duration      => $self->duration,
      full_message  => $self->full_message,
      job_id        => $self->job_id,
      kanku_url     => $self->kanku_url,
      context       => $self->context || {},
    };
}

1;
