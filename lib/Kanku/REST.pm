package Kanku::REST;

use Moose;

use Dancer2;
use Dancer2::Plugin::REST;
use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::Auth::Extensible;
use Dancer2::Plugin::WebSocket;

use Sys::Virt;
use Try::Tiny;
use Session::Token;
use Carp qw/longmess/;
use Digest::SHA qw(sha512_base64);

use Kanku::Config;
use Kanku::Schema;
use Kanku::Util::IPTables;
use Kanku::LibVirt::HostList;

use Kanku::REST::Admin::User;
use Kanku::REST::Admin::Task;
use Kanku::REST::Admin::Role;
use Kanku::REST::JobComment;
use Kanku::REST::Guest;
use Kanku::REST::Job;
use Kanku::REST::JobGroup;
use Kanku::REST::Worker;

prepare_serializer_for_format;

Kanku::Config->initialize();

################################################################################
# Functions
################################################################################
sub app_opts {
  return 'app'=> app, 'current_user' => ( logged_in_user || {} ), 'schema' => schema;
}

sub userinfo {
  my $liu = logged_in_user;
  my $ret = {};
  # filter out some sensitive information
  for (qw/id name username email deleted lastlogin role_id/) {
   $ret->{$_} = $liu->{$_};
  }
  return $ret;
}

################################################################################
# Routes
################################################################################

# ROUTES FOR JOBS
get '/jobs/list.:format' => sub {
  my $jo = Kanku::REST::Job->new(app_opts());
  return $jo->list;
};

get '/job/:id.:format' => sub {
  my $jo = Kanku::REST::Job->new(app_opts());
  return $jo->details;
};

post '/job/trigger/:name.:format' => require_any_role [qw/Admin User/] =>  sub {
  my $jo = Kanku::REST::Job->new(app_opts());
  return $jo->trigger;
};

post '/job/retrigger/:id.:format' => require_any_role [qw/Admin User/] =>  sub {
  my $jo = Kanku::REST::Job->new(app_opts());
  return $jo->retrigger;
};

get '/job/config/:name.:format' => require_any_role [qw/Admin User/] =>  sub {
  my $jo = Kanku::REST::Job->new(app_opts());
  return $jo->config;
};

# ROUTES FOR JOB COMMENTS
get '/job/comment/:job_id.:format' => require_any_role [qw/Admin User/] =>  sub {
  my $jco = Kanku::REST::JobComment->new(app_opts());
  return $jco->list();
};

post '/job/comment/:job_id.:format' => require_any_role [qw/Admin User/] =>  sub {
  my $jco = Kanku::REST::JobComment->new(app_opts());
  return $jco->create;
};

put '/job/comment/:comment_id.:format' => require_any_role [qw/Admin User/] =>  sub {
  my $jco = Kanku::REST::JobComment->new(app_opts());
  return $jco->update;
};

del '/job/comment/:comment_id.:format' => require_any_role [qw/Admin User/] =>  sub {
  my $jco = Kanku::REST::JobComment->new(app_opts());
  return $jco->remove;
};

# ROUTES FOR JOBGROUPS

post '/job_group/trigger/:name.:format' => require_any_role [qw/Admin/] =>  sub {
  my $jg = Kanku::REST::JobGroup->new(app_opts());
  return $jg->trigger;
};

get '/gui_config/job_group.:format'  => requires_role Admin => sub {
  my $cfg           = Kanku::Config->instance();
  my @job_groups    = $cfg->job_group_list;
  my $filter        = params->{filter} || '.*';
  my $limit         = params->{limit};
  my $page          = params->{page};
  my @config        = ();
  my @errors        = ();
  my @filtered_job_groups = ();

  foreach my $name (sort @job_groups) {
    push(@filtered_job_groups, $name) if $name =~ m/$filter/;
  }

  my $total_entries = @filtered_job_groups;

  my @_job_groups;

  if ($limit) {
    # limit = 10
    # page1 = 0:9
    # page2 = 10:19
    my $start = $limit * ($page - 1);
    my $end   = $start + $limit - 1;
    my $last  = $total_entries - 1;
    $end = ($end > $last) ? $last : $end;
    @_job_groups = @filtered_job_groups[$start..$end];
  } else {
    @_job_groups = @filtered_job_groups;
  }

  foreach my $name (@_job_groups) {
    my $job_group_config = { name => $name, groups => [], digest => undef};
    push @config , $job_group_config;
    my $job_group_cfg;
    try {
      $job_group_cfg = $cfg->job_group_config($name);
      $job_group_config->{digest} = sha512_base64($cfg->job_group_config_plain($name));
    } catch {
      $job_group_cfg = $_;
    };

    if (ref($job_group_cfg) ne 'HASH') {
      push @errors, "Error while parsing config file of job group '$name': $job_group_cfg";
      next;
    }

    $job_group_config->{groups} = $job_group_cfg->{groups};
  }

  return {
    config        => \@config ,
    errors        => \@errors,
    limit         => $limit,
    total_entries => $total_entries,
  };
};

# ROUTES FOR GUESTS
get '/guest/list.:format' => sub {
  my $go = Kanku::REST::Guest->new(app_opts());
  return $go->list;
};

# ROUTES FOR TASKS
get '/admin/task/list.:format' => requires_role Admin => sub {
  my ($self) = @_;
  my $to = Kanku::REST::Admin::Task->new(app_opts());
  return $to->list;
};

post '/admin/task/resolve.:format' => requires_role Admin => sub {
  my ($self) = @_;
  my $to = Kanku::REST::Admin::Task->new(app_opts());
  return $to->resolve;
};

post '/request_roles.:format' => require_login sub {
  my ($self) = @_;
  my $to = Kanku::REST::Admin::Task->new(app_opts());
  return $to->create_role_request;
};

# ROUTES FOR USERS
get '/admin/user/list.:format' => requires_role Admin => sub {
  my ($self) = @_;
  my $uo = Kanku::REST::Admin::User->new(app_opts());
  return $uo->list;
};

get '/user/:username.:format' => sub {
  my ($self) = @_;
  my $uo = Kanku::REST::Admin::User->new(app_opts());
  return $uo->details;
};

put '/user/:user_id.:format' => sub {
  my ($self) = @_;
  my $uo = Kanku::REST::Admin::User->new(app_opts());

  return $uo->update();
};

get '/userinfo.:format' => sub {
  my ($self) = @_;
  return { logged_in_user => userinfo() };
};

post '/admin/user/deactivate/:user_id.:format' => sub {
  my ($self) = @_;
  my $uo = Kanku::REST::Admin::User->new(app_opts());

  return $uo->deactivate(params->{user_id});
};

post '/admin/user/activate/:user_id.:format' => sub {
  my ($self) = @_;
  my $uo = Kanku::REST::Admin::User->new(app_opts());

  return $uo->activate(params->{user_id});
};

del '/admin/user/:user_id.:format' => requires_role Admin => sub {
  my $uo = Kanku::REST::Admin::User->new(app_opts());
  return $uo->remove(params->{user_id});
};

# ROUTES FOR ROLES
get '/admin/role/list.:format' => requires_role Admin => sub {
  my $ro = Kanku::REST::Admin::Role->new(app_opts());
  return $ro->list;
};

# ROUTES FOR AUTH
post '/login.:format' => sub {
  if ( session 'logged_in_user' ) {
    # user is authenticated by valid session
    return { authenticated => 1 };
  }
  my $username = params->{username};
  my $password = params->{password};

  if (! $username || ! $password) {
    # could not get username/password combo
    return { authenticated => 0 };
  }

  my ($success, $realm) = authenticate_user($username, $password);

  if ($success) {
    # user successfully authenticated by username/password
    session logged_in_user       => $username;
    session logged_in_user_realm => $realm;
    my $ws_session = Kanku::WebSocket::Session->new(
      user_id => userinfo()->{id},
      schema  => schema,
    );
    debug "Session auth_token: ".$ws_session->auth_token;

    return {
     authenticated  => 1,
     kanku_notify_session => $ws_session->auth_token,
     logged_in_user => userinfo(),
    };
  } else {
    # could not authrenticate user
    return { authenticated => 0 };
  }
};

get 'login' => sub {
  return {
    errors        => ['Your are not logged in!'],
  };
};

post '/logout.:format' => require_login sub {
    my $uid    = userinfo()->{id},
    my $token  = params->{kanku_notify_session};
    my $result = app->destroy_session;
    if ($token) {
      my $ws_session = Kanku::WebSocket::Session->new(
	user_id => $uid,
	schema  => schema,
      );
      $ws_session->auth_token(params->{kanku_notify_session});
      $ws_session->cleanup_session();
    }
    return { authenticated => 0 };
};

# ROUTES FOR MISC STUFF
get '/gui_config/job.:format' => sub {
  my $cfg           = Kanku::Config->instance();
  my @config        = ();
  my @errors        = ();
  my @jobs          = $cfg->job_list;
  my $filter        = params->{filter} || '.*';
  my $limit         = params->{limit};
  my $page          = params->{page};
  my @filtered_jobs = ();

  foreach my $job_name (sort @jobs) {
    push(@filtered_jobs, $job_name) if $job_name =~ m/$filter/;
  }

  my $total_entries = @filtered_jobs;

  my @_jobs;

  if ($limit) {
    # limit = 10
    # page1 = 0:9
    # page2 = 10:19
    my $start = $limit * ($page - 1);
    my $end   = $start + $limit - 1;
    my $last  = $total_entries - 1;
    $end = ($end > $last) ? $last : $end;
    @_jobs = @filtered_jobs[$start..$end];
  } else {
    @_jobs = @filtered_jobs;
  }

  foreach my $job_name (@_jobs) {
    my $job_config = { job_name => $job_name, sub_tasks => []};
    push @config , $job_config;
    my $job_cfg;
    try {
      $job_cfg = $cfg->job_config($job_name)->{tasks};
    } catch {
      $job_cfg = $_;
    };

    if (ref($job_cfg) ne 'ARRAY') {
      push @errors, "Error while parsing config file of job '$job_name': $job_cfg";
      next;
    }

    foreach my $sub_tasks ( @{$job_cfg}) {
        my $mod = $sub_tasks->{use_module};
        my $defaults = {};
        my $mod2require = $mod;
        $mod2require =~ s{::}{/}smxg;
        $mod2require = "$mod2require.pm";
        require "$mod2require";    ## no critic (Modules::RequireBarewordIncludes)
        my $tmp = [];
        my $can = $mod->can('gui_config');

        if (! $can) {
          error "Could not find method gui_config in module $mod2require configured in job $job_name";
          next;
        }

        $tmp = $can->();

        foreach my $opt (@{$tmp}) {
          $opt->{default} = ($opt->{secure}) ? '' : $sub_tasks->{options}->{$opt->{param}};
          $defaults->{$opt->{param}} = ($opt->{secure}) ? '' : $sub_tasks->{options}->{$opt->{param}};
        }
        push @{$job_config->{sub_tasks}},
            {
              use_module => $mod,
              gui_config => $tmp,
              defaults   => $defaults,
            },
        ;
    }
  }

  return {
    config        => \@config ,
    errors        => \@errors,
    limit         => $limit,
    total_entries => $total_entries,
  };
};

get '/test.:format' => sub {  return {test=>'success'} };

get '/worker/list.:format' => sub {
  my $jo = Kanku::REST::Worker->new(app_opts());
  return $jo->list;
};

get '/pwreset/:user.:format' => sub {
  my $user = params->{user};

  if (defined password_reset_send username => $user ) {
    return {state => 'success', msg => 'Succeed'};
  } else {
    return {state => 'danger', msg => 'Failed'};
  }
};

post '/signup.:format' => sub {
  my $fullname = params->{fullname};
  my $username = params->{username};
  my $email    = params->{email};

  if (get_user_details($username)) {
    return {state => 'danger', msg => 'Signup failed! User already exists.'};
  }

  # Taken from https://perlmaven.com/email-validation-using-regular-expression-in-perl
  my $user     = qr/[a-z0-9_+]([a-z0-9_+.]*[a-z0-9_+])?/;
  my $domain   = qr/[a-z0-9.-]+/;
  my $regex = $email =~ /^$user\@$domain$/;

  if (!$regex) {
    return {state => 'danger', msg => 'Signup failed! Email address invalid.'};
  }


  # email_welcome_send
  my $res = create_user username => $username, email => $email, email_welcome => 1, name => $fullname;

  if (defined $res) {
    return {state => 'success', msg => 'Signup succeed. Please check your emails and set your password!'};
  } else {
    return {state => 'danger', msg => 'Signup failed! Reason unknown.'};
  }
};

post '/setpass.:format' => sub {
  my $res = user_password code => params->{code}, new_password => params->{new_password};

  if (defined $res) {
    return {state => 'success', msg => "Setting new password for user '$res' succeed!"};
  } else {
    return {state => 'danger', msg => 'Setting new password failed'};
  }
};

sub reset_text_handler {
    my ($dsl, %params) = @_;
    my $site       = $dsl->app->request->base;
    my $reset_link = $site . "/#/login?code=$params{code}";
    $reset_link =~ s#([^:])//+#$1/#;
    $reset_link =~ s#rest/##;

    return (
        from    => $dsl->config->{mail_from},
        subject => "Password reset request",
        plain   => "
A request has been received to reset your password for Kanku. If
you would like to do so, please follow the link below:

$reset_link

",
    );
}

__PACKAGE__->meta->make_immutable();

1;
