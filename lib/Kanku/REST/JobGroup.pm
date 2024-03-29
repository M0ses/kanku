package Kanku::REST::JobGroup;

use Moose;

with 'Kanku::Roles::REST';

use Try::Tiny;
use JSON::XS;
use Kanku::Config;

sub trigger {
  my ($self) = @_;
  my $name   = $self->params->{name};
  my $cfg           = Kanku::Config->instance();
  my @job_groups    = $cfg->job_group_list;
  my $jg_cfg        = $cfg->job_group_config($name);
  my $data   = $self->params->{data} || $self->_calc_default_data($name, $jg_cfg);
  my @jobs_to_trigger;

  for (my $g = 0; $g < @{$jg_cfg->{groups}}; $g++) {
    my $jobs = $jg_cfg->{groups}->[$g]->{jobs};
    $jobs_to_trigger[$g] = {};
    for (my $j=0; $j < @{$jobs}; $j++) {
      # The default for jobs is "enabled"
      $jobs_to_trigger[$g]->{$jobs->[$j]} = (defined $data->[$g]->[$j] ) ? $data->[$g]->[$j] : 1;
    }
  }

  my $jgd = {
    name => $name,
    creation_time  => time(),
  };
  my $job_group = $self->rset('JobGroup')->create($jgd);

  my @prev_jobs;
  my $jg_count=0;
  my $json = JSON::XS->new();
  for my $jg (@jobs_to_trigger) {
    my $pj = $prev_jobs[$jg_count+1] = [];
    for my $job_name (keys %{$jg}) {
      my @wait_for = map { {wait_for=>$_} } @{$prev_jobs[$jg_count]};
      my $jd = {
        name          => $job_name,
        state         => 'triggered',
        creation_time => time(),
	wait_for      => \@wait_for,
	job_group_id  => $job_group->id,
      };
      return {state=>'error', msg=>"Wrong data used for job"} if (ref($jg->{$job_name}) eq 'HASH');
      $jd->{args} = $json->encode($jg->{$job_name}) if (ref($jg->{$job_name}) eq 'ARRAY');
      my $job_id = $self->rset('JobHistory')->create($jd);
      push @$pj, $job_id;
    }
    $jg_count++;
  }

  return {state => 'success', msg => "Successfully triggered job group '$name'"};
}

sub _calc_default_data {
  my ($self, $name, $jg_cfg) = @_;
  my $data          = [];

  my $g = 0;

  for my $group (@{$jg_cfg->{groups}}) {
    my $j = 0;
    for my $job (@{$jg_cfg->{groups}->[$g]->{jobs}}) {
      $data->[$g]->[$j] = 1;
      $j++;
    }
    $g++;
  }
  return $data;
}

__PACKAGE__->meta->make_immutable();

1;
