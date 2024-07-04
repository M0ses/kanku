# Copyright (c) 2017 SUSE LLC
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
package Kanku::NotifyQueue::RabbitMQ;

=head1 NAME

 Kanku::NotifyQueue - A class to send notifications from daemons to rabbitmq

=head1 SYNOPSIS

  my $notification = {
    type    => ...,
    message => '...'
  };

  my $nq = Kanku::NotifyQueue->new();
  $nq->prepare();
  $nq->send($notification);

=cut

use Moose;
use JSON::XS;

use Kanku::Config;

BEGIN { Kanku::Config->initialize(); }

use Kanku::RabbitMQ;

with 'Kanku::Roles::NotifyQueue';

=head1 ATTRIBUTES

=over

=item shutdown_file -

=back

=cut

=head1 METHODS

=head2 prepare - create Kanku::RabbitMQ object and declare exchange if needed

 $nq->prepare();

=cut

sub prepare {
    my ($self) = @_;
    my $cfg    = Kanku::Config->instance();
    my $config = $cfg->config()->{'Kanku::RabbitMQ'};
    my $kmq    = Kanku::RabbitMQ->new(%{ $config || {}});

    $kmq->shutdown_file($self->shutdown_file);
    $kmq->connect();
    $self->_queue($kmq);
    return $kmq;
}

=head2 send - send a notification to the notify exchange

$notification can be a json string or a reference

 $nq->send($notification);

=cut

sub send {
  my ($self, $msg) = @_;
  $msg = encode_json($msg) if ref($msg);
  $self->_queue->publish(
    'kanku.notify',
    $msg,
    {exchange => 'amq.direct'}
  );
}

__PACKAGE__->meta->make_immutable();

1;
