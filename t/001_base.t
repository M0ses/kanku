use strict;
use warnings;

use FindBin;
use Test::More tests => 33;

use_ok 'Kanku::Cli::Roles::Remote';
use_ok 'Kanku::Cli::Roles::RemoteCommand';
use_ok 'Kanku::Cli::Roles::Schema';
use_ok 'Kanku::Cli::Roles::VM';
use_ok 'Kanku::Cli::Roles::View';
use_ok 'Kanku::Cli::api';
use_ok 'Kanku::Cli::ca';
use_ok 'Kanku::Cli::check_configs';
use_ok 'Kanku::Cli::console';
use_ok 'Kanku::Cli::db';
use_ok 'Kanku::Cli::destroy';
use_ok 'Kanku::Cli::init';
use_ok 'Kanku::Cli::ip';
use_ok 'Kanku::Cli::list';
use_ok 'Kanku::Cli::login';
use_ok 'Kanku::Cli::logout';
use_ok 'Kanku::Cli::lsi';
use_ok 'Kanku::Cli::pfwd';
use_ok 'Kanku::Cli::rabbit';
use_ok 'Kanku::Cli::rcomment';
use_ok 'Kanku::Cli::retrigger';
use_ok 'Kanku::Cli::rguest';
use_ok 'Kanku::Cli::rhistory';
use_ok 'Kanku::Cli::rjob';
use_ok 'Kanku::Cli::rr';
use_ok 'Kanku::Cli::rtrigger';
use_ok 'Kanku::Cli::rworker';
use_ok 'Kanku::Cli::setup';
use_ok 'Kanku::Cli::snapshot';
use_ok 'Kanku::Cli::ssh';
use_ok 'Kanku::Cli::startui';
use_ok 'Kanku::Cli::startvm';
use_ok 'Kanku::Cli::status';
use_ok 'Kanku::Cli::stopui';
use_ok 'Kanku::Cli::stopvm';
use_ok 'Kanku::Cli::up';
use_ok 'Kanku::Cli::urlwrapper';
use_ok 'Kanku::Setup::LibVirt::Network';
use_ok 'Kanku::Setup::Devel';
use_ok 'Kanku::Setup::Roles::Common';
use_ok 'Kanku::Setup::Roles::Server';
use_ok 'Kanku::Setup::Server::Distributed';
use_ok 'Kanku::Setup::Server::Standalone';
use_ok 'Kanku::Setup::Worker';
use_ok 'Kanku::Airbrake';
use_ok 'Kanku::Airbrake::Dummy';
use_ok 'Kanku::Cli';
use_ok 'Kanku::Cmd';
use_ok 'Kanku::Config';
use_ok 'Kanku::Config::Defaults';
use_ok 'Kanku::Daemon::Dispatcher';
use_ok 'Kanku::Daemon::Scheduler';
use_ok 'Kanku::Daemon::TriggerD';
use_ok 'Kanku::Daemon::Worker';
use_ok 'Kanku::Dispatch::Local';
use_ok 'Kanku::Dispatch::RabbitMQ';
use_ok 'Kanku::GPG';
use_ok 'Kanku::Handler::ChangeDomainState';
use_ok 'Kanku::Handler::CleanupIPTables';
use_ok 'Kanku::Handler::CopyProfile';
use_ok 'Kanku::Handler::CreateDomain';
use_ok 'Kanku::Handler::DomainSnapshot';
use_ok 'Kanku::Handler::ExecuteCommandOnHost';
use_ok 'Kanku::Handler::ExecuteCommandViaConsole';
use_ok 'Kanku::Handler::ExecuteCommandViaSSH';
use_ok 'Kanku::Handler::GIT';
use_ok 'Kanku::Handler::HTTPDownload';
use_ok 'Kanku::Handler::K8NodePortForward';
use_ok 'Kanku::Handler::OBSServerFrontendTests';
use_ok 'Kanku::Handler::PortForward';
use_ok 'Kanku::Handler::PrepareSSH';
use_ok 'Kanku::Handler::Reboot';
use_ok 'Kanku::Handler::RemoveDomain';
use_ok 'Kanku::Handler::ResizeImage';
use_ok 'Kanku::Handler::RevertQcow2Snapshot';
use_ok 'Kanku::Handler::SaltSSH';
use_ok 'Kanku::Handler::SetupNetwork';
use_ok 'Kanku::Handler::Wait';
use_ok 'Kanku::Handler::WaitForSystemd';
use_ok 'Kanku::Handler::OBSCheck';
use_ok 'Kanku::Handler::SetJobContext';
use_ok 'Kanku::Handler::ImageDownload';
use_ok 'Kanku::Job';
use_ok 'Kanku::JobList';
use_ok 'Kanku::LibVirt::HostList';
use_ok 'Kanku::Listener::RabbitMQ';
use_ok 'Kanku::Notifier';
use_ok 'Kanku::Notifier::NSCA';
use_ok 'Kanku::Notifier::NSCAng';
use_ok 'Kanku::Notifier::Sendmail';
use_ok 'Kanku::NotifyQueue';
use_ok 'Kanku::NotifyQueue::Dummy';
use_ok 'Kanku::NotifyQueue::RabbitMQ';
use_ok 'Kanku::REST';
use_ok 'Kanku::REST::Admin::Role';
use_ok 'Kanku::REST::Admin::Task';
use_ok 'Kanku::REST::Admin::User';
use_ok 'Kanku::REST::Guest';
use_ok 'Kanku::REST::Job';
use_ok 'Kanku::REST::JobComment';
use_ok 'Kanku::REST::JobGroup';
use_ok 'Kanku::REST::Worker';
use_ok 'Kanku::RabbitMQ';
use_ok 'Kanku::Roles::Config';
use_ok 'Kanku::Roles::Config::Base';
use_ok 'Kanku::Roles::Config::KankuFile';
use_ok 'Kanku::Roles::DB';
use_ok 'Kanku::Roles::Daemon';
use_ok 'Kanku::Roles::Dispatcher';
use_ok 'Kanku::Roles::Handler';
use_ok 'Kanku::Roles::Helpers';
use_ok 'Kanku::Roles::Logger';
use_ok 'Kanku::Roles::ModLoader';
use_ok 'Kanku::Roles::Notifier';
use_ok 'Kanku::Roles::NotifyQueue';
use_ok 'Kanku::Roles::REST';
use_ok 'Kanku::Roles::SSH';
use_ok 'Kanku::Roles::Serialize';
use_ok 'Kanku::Schema';
use_ok 'Kanku::Task';
use_ok 'Kanku::Task::Local';
use_ok 'Kanku::Task::Remote';
use_ok 'Kanku::Task::RemoteAll';
use_ok 'Kanku::Test::RabbitMQ';
use_ok 'Kanku::Util';
use_ok 'Kanku::Util::IPTables';
use_ok 'Kanku::Util::VM';
use_ok 'Kanku::Util::VM::Console';
use_ok 'Kanku::Util::VM::Image';
use_ok 'Kanku::Util::CurlHttpDownload';
use_ok 'Kanku::Util::DoD';
use_ok 'Kanku::WebSocket::Notification';
use_ok 'Kanku::WebSocket::Session';
use_ok 'Kanku::YAML';
use_ok 'Dancer2::Plugin::GitLab::Webhook';
use_ok 'Kanku';
