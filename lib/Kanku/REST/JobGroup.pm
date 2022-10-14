package Kanku::REST::JobGroup;

use Moose;

with 'Kanku::Roles::REST';

use Try::Tiny;
use Kanku::Config;

sub trigger {
  my ($self) = @_;
  my $name   = $self->params->{name};
  my $data   = $self->params->{data} || [];
  my $cfg           = Kanku::Config->instance();
  my @job_groups    = $cfg->job_group_list;
  my $jg_cfg        = $cfg->job_group_config($name);
  my @jobs_to_trigger;

  for (my $g = 0; $g < @{$data}; $g++) {
     my $jobs = $jg_cfg->{groups}->[$g]->{jobs};
     $jobs_to_trigger[$g] = {};
     for (my $j=0; $j < @{$jobs}; $j++) {
       $jobs_to_trigger[$g]->{$jobs->[$j]} = 1 if $data->[$g]->[$j];
     }
  }

  my @prev_jobs;
  my $jg_count=0;
  for my $jg (@jobs_to_trigger) {
    my $pj = $prev_jobs[$jg_count+1] = [];
    for my $job_name (keys %{$jg}) {
      my @wait_for = map { {wait_for=>$_} } @{$prev_jobs[$jg_count]};
      my $jd = {
        name          => $job_name,
        state         => 'triggered',
        creation_time => time(),
	wait_for      => \@wait_for,
      };
      my $job_id = $self->rset('JobHistory')->create($jd);
      push @$pj, $job_id;
    }
    $jg_count++;
  }

  return {state => 'success', msg => "Successfully triggered job group '$name'"};
}

__PACKAGE__->meta->make_immutable();

1;
