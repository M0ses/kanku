use strict;
use warnings;

use FindBin;
use Test::More tests => 33;

use_ok 'Kanku';
use_ok 'Kanku::Schema';
use_ok 'Kanku::Util::DoD';
use_ok 'Kanku::Util::VM::Console';
use_ok 'Kanku::Util::CurlHttpDownload';
use_ok 'Kanku::Util::DoD';
use_ok 'Kanku::Util::VM';
use_ok 'Kanku::Util::IPTables';
use_ok 'Kanku::Job';
use_ok 'Kanku::Roles::Logger';
use_ok 'Kanku::Roles::Config';
use_ok 'Kanku::Roles::Handler';
use_ok 'Kanku::Config';
use_ok 'Kanku::Handler::GIT';
use_ok 'Kanku::Handler::RemoveDomain';
use_ok 'Kanku::Handler::OBSDownload';
use_ok 'Kanku::Handler::PortForward';
use_ok 'Kanku::Handler::ExecuteCommandViaSSH';
use_ok 'Kanku::Handler::HTTPDownload';
use_ok 'Kanku::Handler::PrepareSSH';
use_ok 'Kanku::Handler::Wait';
use_ok 'Kanku::Handler::CreateDomain';
use_ok 'Kanku::Daemon::Scheduler';
use_ok 'Kanku::Cmd';
use_ok 'Kanku::Cmd::Roles::Schema';
use_ok 'Kanku::Cmd::Command::setup';
use_ok 'Kanku::Cmd::Command::init';
use_ok 'Kanku::Cmd::Command::up';
use_ok 'Kanku::Cmd::Command::ssh';
use_ok 'Kanku::Cmd::Command::startui';
use_ok 'Kanku::Cmd::Command::stopui';
use_ok 'Kanku::Cmd::Command::destroy';
