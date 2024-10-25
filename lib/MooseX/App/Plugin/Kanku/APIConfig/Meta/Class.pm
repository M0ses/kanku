# ============================================================================
package MooseX::App::Plugin::Kanku::APIConfig::Meta::Class;
# ============================================================================

use 5.010;
use utf8;

use namespace::autoclean;
use Moose::Role;
use Kanku::YAML;

around 'command_proto' => sub {
    my ($orig,$self,$metaclass) = @_;

    my ($result,$errors) = $self->$orig($metaclass);
    delete $result->{api_config}
        unless defined $result->{api_config};

    return $self->proto_api_config($metaclass,$result,$errors);
};

sub proto_api_config {
    my ($self,$metaclass,$result,$errors) = @_;

    # Check if we have a config
    $result->{api_config} = "$::ENV{HOME}/.kankurc"
        unless defined $result->{api_config};

    # Read config
    my $config_file = $result->{api_config};

    unless (-e $config_file) {
	$result->{apiurl} = q{};
	$result->{keyring} = q{};
	$result->{user} = q{};
	$result->{password} = q{};
        return ($result,$errors);
    }

    my $config_data = Kanku::YAML::LoadFile($config_file);

    # Set config data
    $result->{_api_config_data} = $config_data || {};

    # Set all config elements
    if (defined $config_data->{apiurl}) {
        $result->{apiurl}  = $config_data->{apiurl};
        $result->{keyring} = $config_data->{keyring} || 'None';
	my $apidata = $config_data->{$config_data->{apiurl}};
        $result->{user} =  $apidata->{user} if defined $apidata->{user};
	if ($result->{keyring} ne 'None') {
            my $mod = my $lib = 'Passwd::Keyring::'.$result->{keyring};
            $lib =~ s{::}{/}g;
            $lib .= '.pm';
	    require $lib;
	    my $keyring = $mod->new(app=>'kanku', group => 'kanku');
            # Store new default settings
            $result->{password} = $keyring->get_password($result->{user}, $result->{apiurl});
	} else {
            $result->{password} = $apidata->{password} if defined $apidata->{password};
	} 
    }

    return ($result, $errors);
};

1;
