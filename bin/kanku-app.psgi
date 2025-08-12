#!/usr/bin/env perl

use strict;
use warnings;

BEGIN { 
  unshift @::INC, ($::ENV{KANKU_LIB_DIR} || '/usr/lib/kanku/lib');
  $::ENV{DANCER_CONFDIR} ||= '/etc/kanku/dancer';
}

use Plack::Builder;
use Log::Log4perl;

use Kanku;
use Kanku::REST;

my $conf_dir = $::ENV{KANKU_ETC_DIR} || '/etc/kanku';

Log::Log4perl->init("$conf_dir/logging/console.conf");

my $logger = Log::Log4perl->get_logger();

builder {
  mount '/kanku/rest' => Kanku::REST->to_app;
  mount(Kanku->websocket_mount);
  mount '/kanku' => Kanku->to_app;
};
