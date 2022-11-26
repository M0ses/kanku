package Kanku::REST::Job;

use Moose;

with 'Kanku::Roles::REST';

use Try::Tiny;
use Kanku::Config;

sub list {
  my ($self) = @_;
  my $opts;
  my $search = {};
  my $limit = $self->params->{limit} || 10;
  my $jrs    = $self->rset('JobHistory');

  # "id",
  # "name",
  # "state",
  # "args",
  # "result",
  # "creation_time",
  # "start_time",
  # "end_time",
  # "last_modified",
  # "workerinfo",
  # "masterinfo",
  # "trigger_user",
  # "pwrand",

  my $states = ($self->params->{state}) 
    ? $self->params->{state} 
    : [qw/succeed running failed dispatching/];


  if ($self->params->{show_only_latest_results}) {
    my @fields = qw/state name start_time end_time creation_time last_modified workerinfo trigger_user pwrand/;
    my $cfg = Kanku::Config->instance();
    $opts = {
      # group_by => ['name'],
      rows     => $limit,
      page     => $self->params->{page} || 1,
      select   => [{ max => 'id'}, @fields],
      as       => ['id', @fields],
      where    => {
	name => {'-in' => [$cfg->job_list]},
	state => {'-in' => $states},
      },
      group_by => ['name'],
    };
  } else {
    $opts = {
      order_by =>{-desc  =>'id'},
      page => $self->params->{page} || 1,
      rows     => $limit,
      where    => {
	state => {'-in' => $states},
      },
    };
  }


  if ($self->params->{filter}) {
	my $jn = $self->params->{filter};
	$jn =~ s{^\s*((?:(id|state|name|worker):)?([^\s]*))\s*$}{$3}smx;
        my $field = 'name';
        my $stmt  = 'like';
        my $val   = $jn;
        if ($2 eq 'worker') {
          $field = 'workerinfo';
          $stmt  = "like";
        } elsif ($2) {
          $field = $2;
          $stmt  = "-in";
          $val   = [split ',', $jn];
        }
	$search->{$field}= { $stmt => $val };
  }

  my $rs = $self->rset('JobHistory')->search($search, $opts);
  my $rv = [];

  my $allow_comments = ($self->has_role('User') || $self->has_role('Admin'));

  while ( my $ds = $rs->next ) {
    my $data = $ds->TO_JSON();
use Data::Dumper;
$self->log('debug', Dumper($data));

    if ($allow_comments) {
      $data->{comments} = [];
      my @comments = $ds->comments;
      for my $comment (@comments) {
        push @{$data->{comments}}, $comment->TO_JSON;
      }
    }

    $data->{pwrand} = $ds->pwrand if $self->has_role('Admin');

    my ($workerhost, $workerpid, $workerqueue) = split /:/smx, $ds->workerinfo;
    $data->{workerhost}  = $workerhost;
    $data->{workerpid}   = $workerpid;
    $data->{workerqueue} = $workerqueue;
    push @{$rv}, $data;
  }

  return {
    total_entries => $rs->pager->total_entries,
    limit         => $limit,
    jobs          => $rv,
  };
}

sub details {
  my ($self) = @_;
  my $job_id = $self->params->{id};

  unless ($job_id) {
    return {
      state => 'failed',
      msg   => "Job ID was empty!",
    };
  }

  my $job    = $self->rset('JobHistory')->find($job_id);

  unless ($job) {
    return {
      state => 'failed',
      msg   => "No job with ID '$job_id' found!",
    };
  }

  my $subtasks = [];

  my $job_history_subs = $job->job_history_subs();

  while (my $job_history_sub = $job_history_subs->next ) {
    push @{$subtasks}, $job_history_sub->TO_JSON();
  }

  # workerinfo:
  # kata.suse.de:23108:job-3878-340a157a-d27d-4138-97ab-bb8f49b5bef7
  my ($workerhost, $workerpid, $workerqueue) = split /:/smx, $job->workerinfo;

  return {
      %{$job->TO_JSON},
      subtasks    => $subtasks,
      result      => $job->result || '{}',
      workerhost  => $workerhost,
      workerpid   => $workerpid,
      workerqueue => $workerqueue,
  };
}

sub trigger {
  my ($self) = @_;
  my $name   = $self->params->{name};

  if ( $name ne 'remove-domain') {
    # search for active jobs
    my @active = $self->rset('JobHistory')->search({
      name  => $name,
      state => {'not in' => [qw/skipped succeed failed/]},
    });

    if (@active) {
      return {
        state => 'warning',
        msg   => "Skipped triggering job '$name'."
                 . ' Another job is already running',
      };
    }
  }
  my $json = JSON::XS->new();
  my $body = $json->decode($self->app->request->body);

  my $jd = {
    name          => $name,
    state         => 'triggered',
    creation_time => time(),
  };

  if ($self->has_role('Admin') && $body->{is_admin}) {
    $self->log('debug', "ADMIN ROLE ACTIVE");
    $jd->{args} = $json->encode($body->{data});
  } else {
    $self->log('debug', "ADMIN ROLE NOT ACTIVE");
    my $user = $self->current_user->{username};
    $jd->{trigger_user} = $self->current_user->{username};
    for my $task (@{$body->{data}}) {
      $task->{domain_name} =~ s/^($user-)?/$user-/ if $task->{domain_name};
    }
    $jd->{args} = $json->encode($body->{data});
  }

  $self->log('debug', " ----- ARGS: $jd->{args}");
  my $job = $self->rset('JobHistory')->create($jd);

  return {state => 'success', msg => "Successfully triggered job '$name' with id ".$job->id};
}

sub retrigger {
  my ($self) = @_;
  my $id     = $self->params->{id};

  my $json   = JSON::XS->new();
  my $body   = $json->decode($self->app->request->body);

  unless ($self->has_role('Admin') && $body->{is_admin}) {
    return {
      state => 'failed',
      msg   => "User is not an Admin. Skipping.",
    };
  }

  # search for given job by id
  my @job = $self->rset('JobHistory')->search({id => $id});
  if (!@job) {
    return {
      state => 'failed',
      msg   => "Could not find job with id '$id'.",
    };
  }

  my $j    = $job[0];
  my $name = $j->name;

  if ( $name eq 'remove-domain') {
      return {
        state => 'warning',
        msg   => "Skipped re-triggering job remove-domain."
      };
  } else {
    # search for active jobs
    my @active = $self->rset('JobHistory')->search({
      name  => $name,
      state => {'not in' => [qw/skipped succeed failed/]},
    });

    if (@active) {
      return {
        state => 'warning',
        msg   => "Skipped triggering job '$name'."
                 . ' Another job is already running',
      };
    }
  };

  my $jd   = {
    name          => $name,
    args          => $j->args,
    state         => 'triggered',
    creation_time => time(),
  };

  $self->log('debug', " ----- ARGS: $jd->{args}");
  my $job = $self->rset('JobHistory')->create($jd);

  return {state => 'success', msg => "Successfully triggered job '$name' with id ".$job->id};
}

sub config {
  my ($self) = @_;
  my $cfg = Kanku::Config->instance();
  my $rval;

  try {
    $rval = $cfg->job_config_plain($self->params->{name});
  }
  catch {
    $rval = $_;
  };

  return { config => $rval };
}

__PACKAGE__->meta->make_immutable();

1;
