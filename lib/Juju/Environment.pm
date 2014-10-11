package Juju::Environment;
$Juju::Environment::VERSION = '1.0';
# ABSTRACT: Exposed juju api environment


use strict;
use warnings;
use HTTP::Tiny;
use JSON::PP;
use Devel::Deprecate 'deprecate';
use parent 'Juju::RPC';


use Class::Tiny qw(password is_authenticated), {
    endpoint => sub {'wss://localhost:17070'},
    username => sub {'user-admin'},
    Jobs     => sub {
        +{  HostUnits     => 'JobHostUnits',
            ManageEnviron => 'JobManageEnviron',
            ManageState   => 'JobManageSate'
        };
    }
};



sub query_cs {
    my ($self,   $charm)  = @_;
    my ($series, $_charm) = $charm =~ /^(precise|trusty)\/(\w+)/i;
    my $cs_url = 'https://manage.jujucharms.com/api/3/charm';
    if (!$series) {
        $series = 'trusty';
        $_charm = $charm;
    }

    my $composed_url = sprintf("%s/%s/%s", $cs_url, $series, $_charm);
    my $res = HTTP::Tiny->new->get($composed_url);
    die "Unable to query charm store\n" unless $res->{success};
    return decode_json($res->{content});
}



sub _prepare_constraints {
    my ($self, $constraints) = @_;
    foreach my $key (keys %{$constraints}) {
        if ($key =~ /^(cpu-cores|cpu-power|mem|root-disk)/) {
            $constraints->{k} = int($constraints->{k});
        }
    }
    return $constraints;
}


sub login {
    my $self = shift;
    $self->create_connection unless $self->is_connected;
    $self->call(
        {   "Type"      => "Admin",
            "Request"   => "Login",
            "RequestId" => $self->request_id,
            "Params"    => {
                "AuthTag"  => $self->username,
                "Password" => $self->password
            }
        },
        sub {
            $self->is_authenticated(1);
        }
    );
}



sub reconnect {
    my $self = shift;
    $self->close;
    $self->create_connection;
    $self->login;
    $self->request_id = 1;
}


sub info {
    my $self = shift;
    my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
    my $params = {"Type" => "Client", "Request" => "EnvironmentInfo"};

    deprecate(
              reason => 'Please use environment_info() for getting environment',
              die => '2014-12-01'
             );

    return $self->environment_info unless $cb;
    return $self->environment_info($cb);
}


sub environment_info {
    my $self = shift;
    my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
    my $params = {"Type" => "Client", "Request" => "EnvironmentInfo"};

    # block
    return $self->call($params) unless $cb;

    # non-block
    return $self->call($params, $cb);
}



sub status {
    my $self   = shift;
    my $cb     = ref $_[-1] eq 'CODE' ? pop : undef;
    my $params = {
        "Type"   => "Client",
        "Request" => "FullStatus"
    };

    # block
    return $self->call($params) unless $cb;

    # non-block
    return $self->call($params, $cb);
}



sub get_watcher {
    my $self = shift;
    my $cb     = ref $_[-1] eq 'CODE' ? pop : undef;
    my $params = {"Type" => "Client", "Request" => "WatchAll"};

    # block
    return $self->call($params) unless $cb;

    # non-block
    return $self->call($params, $cb);
}


sub get_watched_tasks {
    my ($self, $watcher_id) = @_;
    my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
    die "Unable to run synchronously, provide a callback" unless $cb;

    my $params =
      {"Type" => "AllWatcher", "Request" => "Next", "Id" => $watcher_id};

    # non-block
    return $self->call($params, $cb);
}



sub add_charm {
    my ($self, $charm_url) = @_;
    my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
    my $params = {
        "Type"    => "Client",
        "Request" => "AddCharm",
        "Params"  => {"URL" => $charm_url}
    };

    # block
    return $self->call($params) unless $cb;

    # non-block
    return $self->call($params, $cb);
}


sub get_charm {
    my ($self, $charm_url) = @_;
    my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
    my $params = {
        "Type"    => "Client",
        "Request" => "CharmInfo",
        "Params"  => {"CharmURL" => $charm_url}
    };

    # block
    return $self->call($params) unless $cb;

    # non-block
    return $self->call($params, $cb);
}


sub get_env_constraints {
    my $self   = shift;
    my $cb     = ref $_[-1] eq 'CODE' ? pop : undef;
    my $params = {
        "Type"    => "Client",
        "Request" => "GetEnvironmentConstraints"
    };

    # block
    return $self->call($params) unless $cb;

    # non-block
    return $self->call($params, $cb);

}


sub set_env_constraints {
    my ($self, $constraints) = @_;
    my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
    my $params = {
        "Type"    => "Client",
        "Request" => "SetEnvironmentConstraints",
        "Params"  => $constraints
    };

    # block
    return $self->call($params) unless $cb;

    # non-block
    return $self->call($params, $cb);
}


sub get_env_config {
    my $self   = shift;
    my $cb     = ref $_[-1] eq 'CODE' ? pop : undef;
    my $params = {
        "Type"    => "Client",
        "Request" => "EnvironmentGet"
    };

    # block
    return $self->call($params) unless $cb;

    # non-block
    return $self->call($params, $cb);
}


sub set_env_config {
    my ($self, $config) = @_;
    my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
    my $params = {
        "Type"    => "Client",
        "Request" => "EnvironmentSet",
        "Params"  => {"Config" => $config}
    };

    # block
    return $self->call($params) unless $cb;

    # non-block
    return $self->call($params, $cb);
}


sub add_machine {
    my ($self, $series, $constraints, $machine_spec, $parent_id,
        $container_type)
      = @_;
    my $cb     = ref $_[-1] eq 'CODE' ? pop : undef;

    my $params = {
        "Series"        => $series,
        "Constraints"   => $self->_prepare_constraints($constraints),
        "ContainerType" => $container_type,
        "ParentId"      => $parent_id,
        "Jobs"          => $self->Jobs->{HostUnits},
    };

    return $self->add_machines([$params]) unless $cb;
    return $self->add_machines([$params], $cb);
}


sub add_machines {
    my ($self, $machines) = @_;
    my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
    my $params = {
        "Type"    => "Client",
        "Request" => "AddMachines",
        "Params"  => {"MachineParams" => $machines}
    };

    # block
    return $self->call($params) unless $cb;

    # non-block
    return $self->call($params, $cb);
}


sub destroy_machines {
    my ($self, $machine_ids, $force) = @_;
    my $cb = ref $_[-1] eq 'CODE' ? pop : undef;

    my $params = {
        "Type"    => "Client",
        "Request" => "DestroyMachines",
        "Params"  => {"MachineNames" => $machine_ids}
    };

    if ($force) {
        $params->{Params}->{Force} = 1;
    }

    # block
    return $self->call($params) unless $cb;

    # non-block
    return $self->call($params, $cb);

}


sub add_relation {
    my ($self, $endpoint_a, $endpoint_b) = @_;
    my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
    my $params = {
        'Type'    => 'Client',
        'Request' => 'AddRelation',
        'Params'  => {'Endpoints' => [$endpoint_a, $endpoint_b]}
    };

    # block
    return $self->call($params) unless $cb;

    # non-block
    return $self->call($params, $cb);
}


sub remove_relation {
    my ($self, $endpoint_a, $endpoint_b) = @_;
    my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
    my $params = {
        'Type'    => 'Client',
        'Request' => 'DestroyRelation',
        'Params'  => {'Endpoints' => [$endpoint_a, $endpoint_b]}
    };

    # block
    return $self->call($params) unless $cb;

    # non-block
    return $self->call($params, $cb);
}


sub deploy {
    my ($self, $service_name, $charm_url, $num_units, $config_yaml,
        $constraints, $machine_spec)
      = @_;
    my $cb     = ref $_[-1] eq 'CODE' ? pop : undef;

    my $params = {ServiceName => $service_name};
    $num_units = 1 unless $num_units;
    $params->{NumUnits}   = $num_units;
    $params->{ConfigYAML} = $config_yaml;
    my $svc_constraints;
    if ($constraints) {
        $params->{Constraints} = $self->_prepare_constraints($constraints);
    }
    if ($machine_spec) {
        $params->{ToMachineSpec} = $machine_spec;
    }
    $self->call(
        {   "Type"    => "Client",
            "Request" => "ServiceDeploy",
            "Params"  => $params
        }
    );
}


sub set_config {
    my ($self, $service_name, $config) = @_;
    my $cb     = ref $_[-1] eq 'CODE' ? pop : undef;

    die "Not a hash" unless ref $config eq 'HASH';
    return $self->call(
        {   "Type"    => "Client",
            "Request" => "ServiceSet",
            "Params"  => {
                "ServiceName" => $service_name,
                "Options"     => $config
            }
        }
    );
}


sub unset_config {
    my ($self, $service_name, $config_keys) = @_;
    my $cb     = ref $_[-1] eq 'CODE' ? pop : undef;

    return $self->call(
        {   "Type"    => "Client",
            "Request" => "ServiceUnset",
            "Params"  => {
                "ServiceName" => $service_name,
                "Options"     => $config_keys
            }
        }
    );
}


sub set_charm {
    my ($self, $service_name, $charm_url, $force) = @_;
    my $cb     = ref $_[-1] eq 'CODE' ? pop : undef;

    $force = 0 unless $force;
    $self->call(
        {   "Type"    => "Client",
            "Request" => "ServiceSetCharm",
            "Params"  => {
                "ServiceName" => $service_name,
                "CharmUrl"    => $charm_url,
                "Force"       => $force
            }
        }
    );
}


sub get_service {
    my ($self, $service_name) = @_;
    my $cb     = ref $_[-1] eq 'CODE' ? pop : undef;

    $self->call(
        {   "Type"    => "Client",
            "Request" => "ServiceGet",
            "Params"  => {"ServiceName" => $service_name}
        },
        sub { my $res = shift; return $res }
    );
}


sub get_config {
    my ($self, $service_name) = @_;
    my $cb     = ref $_[-1] eq 'CODE' ? pop : undef;

    my $svc = $self->get_service($service_name);
    return $svc->{Config};
}


sub get_constraints {
    my ($self, $service_name) = @_;
    my $cb     = ref $_[-1] eq 'CODE' ? pop : undef;

    $self->call(
        {   "Type"    => "Client",
            "Request" => "GetServiceConstraints",
            "Params"  => {"ServiceName" => $service_name}
        },
        sub {
            my $res = shift;
            return $res->{Constraints};
        }
    );
}


sub set_constraints {
    my ($self, $service_name, $constraints) = @_;
    my $cb     = ref $_[-1] eq 'CODE' ? pop : undef;

    $self->call(
        {   "Type"    => "Client",
            "Request" => "SetServiceConstraints",
            "Params"  => {
                "ServiceName" => $service_name,
                "Constraints" => $self->_prepare_constraints($constraints)
            }
        },
        sub { my $res = shift; return $res }
    );
}


sub update_service {
    my ($self, $service_name, $charm_url, $force_charm_url,
        $min_units, $settings, $constraints)
      = @_;
    my $cb     = ref $_[-1] eq 'CODE' ? pop : undef;

    $self->call(
        {   "Type"    => "Client",
            "Request" => "SetServiceConstraints",
            "Params"  => {
                "ServiceName"     => $service_name,
                "CharmUrl"        => $charm_url,
                "MinUnits"        => $min_units,
                "SettingsStrings" => $settings,
                "Constraints"     => $self->_prepare_constraints($constraints)
            }
        },
        sub { my $res = shift; return $res }
    );
}


sub destroy_service {
    my ($self, $service_name) = @_;
    my $cb     = ref $_[-1] eq 'CODE' ? pop : undef;

    $self->call(
        {   "Type"    => "Client",
            "Request" => "ServiceDestroy",
            "Params"  => {"ServiceName" => $service_name}
        },
        sub { my $res = shift; return $res }
    );
}


sub expose {
    my ($self, $service_name) = @_;
    my $cb     = ref $_[-1] eq 'CODE' ? pop : undef;

    $self->call(
        {   "Type"    => "Client",
            "Request" => "ServiceExpose",
            "Params"  => {"ServiceName" => $service_name}
        }
    );
}


sub unexpose {
    my ($self, $service_name) = @_;
    my $cb     = ref $_[-1] eq 'CODE' ? pop : undef;

    $self->call(
        {   "Type"    => "Client",
            "Request" => "ServiceUnexpose",
            "Params"  => {"ServiceName" => $service_name}
        },
        sub { my $res = shift; return $res }
    );
}


sub valid_relation_names {
    my ($self, $service_name) = @_;
    my $cb     = ref $_[-1] eq 'CODE' ? pop : undef;

    $self->call(
        {   "Type"    => "Client",
            "Request" => "ServiceCharmRelations",
            "Params"  => {"ServiceName" => $service_name}
        },
        sub { my $res = shift; return $res }
    );
}


sub add_units {
    my ($self, $service_name, $num_units) = @_;
    my $cb     = ref $_[-1] eq 'CODE' ? pop : undef;

    $num_units = 1 unless $num_units;
    $self->call(
        {   "Type"    => "Client",
            "Request" => "AddServiceUnits",
            "Params"  => {
                "ServiceName" => $service_name,
                "NumUnits"    => $num_units
            }
        },
        sub {
            my $res = shift;
            return $res;
        }
    );
}


sub add_unit {
    my ($self, $service_name, $machine_spec) = @_;
    my $cb     = ref $_[-1] eq 'CODE' ? pop : undef;

    $machine_spec = 0 unless $machine_spec;
    my $params = {
        "ServiceName" => $service_name,
        "NumUnits"    => 1
    };

    if ($machine_spec) {
        $params->{ToMachineSpec} = $machine_spec;
    }
    $self->call(
        {   "Type"    => "Client",
            "Request" => "AddServiceUnits",
            "Params"  => $params
        },
        sub { my $res = shift; return $res }
    );
}



sub remove_unit {
    my ($self, $unit_names) = @_;
    my $cb     = ref $_[-1] eq 'CODE' ? pop : undef;

    $self->call(
        {   "Type"    => "Client",
            "Request" => "DestroyServiceUnits",
            "Params"  => {"UnitNames" => $unit_names}
        },
        sub { my $res = shift; return $res }
    );
}


sub resolved {
    my ($self, $unit_name, $retry) = @_;
    my $cb     = ref $_[-1] eq 'CODE' ? pop : undef;

    $retry = 0 unless $retry;
    $self->call(
        {   "Type"    => "Client",
            "Request" => "Resolved",
            "Params"  => {
                "UnitName" => $unit_name,
                "Retry"    => $retry
            }
        },
        sub { my $res = shift; return $res }
    );
}



sub get_public_address {
    my ($self, $target) = @_;
    my $cb     = ref $_[-1] eq 'CODE' ? pop : undef;

    $self->call(
        {   "Type"    => "Client",
            "Request" => "PublicAddress",
            "Params"  => {"Target" => $target}
        },
        sub { my $res = shift; return $res; }
    );
}


sub set_annotation {
    my ($self, $entity, $entity_type, $annotation) = @_;
    my $cb     = ref $_[-1] eq 'CODE' ? pop : undef;

    $self->call(
        {   "Type"    => "Client",
            "Request" => "SetAnnotations",
            "Params"  => {
                "Tag"   => sprintf("%s-%s", $entity_type, $entity =~ s|/|-|g),
                "Pairs" => $annotation
            }
        },
        sub { my $res = shift; return $res }
    );
}


sub get_annotation {
    my ($self, $entity, $entity_type) = @_;
    my $cb     = ref $_[-1] eq 'CODE' ? pop : undef;

    $self->call(
        {   "Type"    => "Client",
            "Request" => "GetAnnotations",
            "Params" =>
              {"Tag" => sprintf("%s-%s", $entity_type, $entity =~ s|/|-|g)}
        },
        sub { my $res = shift; return $res }
    );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Juju::Environment - Exposed juju api environment

=head1 VERSION

version 1.0

=head1 SYNOPSIS

  use Juju;

  my $juju = Juju->new(endpoint => 'wss://localhost:17070', password => 's3cr3t');

=head1 ATTRIBUTES

=head2 endpoint

Websocket address

=head2 username

Juju admin user, this is a tag and should not need changing from the
default.

B<Note> This will be changing once multiple user support is released.

=head2 password

Password of juju administrator, found in your environments configuration
under B<password>

=head2 is_authenticated

Stores if user has authenticated with juju api server

=head2 Jobs

Supported juju jobs

=head1 METHODS

=head2 query_cs ($charm)

helper for querying charm store for charm details

=head2 _prepare_constraints ($constraints)

Makes sure cpu-cores, cpu-power, mem are integers

C<constraints> - hash of service constraints

B<Returns> - an updated constraint hash with any integers set properly.

=head2 login

Login to juju

=head2 reconnect

Reconnects to API server in case of timeout

=head2 info

(Deprecated) Environment information

B<Returns> - Juju environment state

=head2 environment_info

Return Juju Environment information

=head2 status

Returns juju environment status

=head2 get_watcher

Returns watcher

=head2 get_watched_tasks ($watcher_id)

List of all watches for Id

=head2 add_charm ($charm_url)

Add charm

C<charm_url> - url of charm

=head2 get_charm ($charm_url)

Get charm

C<charm_url> - url of charm

=head2 get_env_constraints

Get environment constraints

=head2 set_env_constraints ($constraints)

Set environment constraints

C<constraints> - environment constraints

=head2 get_env_config

=head2 set_env_config ($config)

C<config> - Config parameters

=head2 add_machine ($series, $constraints, $machine_spec, $parent_id, $container_type)

Allocate new machine from the iaas provider (i.e. MAAS)

C<series> - OS series (i.e precise)

C<constraints> - machine constraints

C<machine_spec> - not sure yet..

C<parent_id> - not sure yet..

C<container_type> - uh..

Note: Not quite right as I've no idea wtf its doing yet, need to read
the specs.

=head2 add_machines ($machines)

Add multiple machines from iaas provider

C<machines> - List of machines

=head2 destroy_machines

Destroy machines

=head2 provisioning_script

Not implemented

=head2 add_relation ($endpoint_a, $endpoint_b)

Sets a relation between units

=head2 remove_relation ($endpoint_a, $endpoint_b)

Removes relation between endpoints

=head2 deploy ($service_name, $charm_url, $num_units, $config_yaml, $constraints, $machine_spec)

Deploys a charm to service

=head2 set_config ($service_name, $config)

Set's configuration parameters for unit

C<service_name> - name of service (ie. blog)

C<config> - hash of config parameters

=head2 unset_config ($service_name, $config_keys)

Unsets configuration value for service to restore charm defaults

C<service_name> - name of service

C<config_keys> - hash of config keys to unset

=head2 set_charm ($service_name, $charm_url, $force)

Sets charm url for service

C<service_name> - name of service

C<charm_url> - charm location (ie. cs:precise/wordpress)

=head2 get_service ($service_name)

Returns information on charm, config, constraints, service keys.

C<service_name> - name of service

B<Returns> - Hash of information on service

=head2 get_config ($service_name)

Get service configuration

C<service_name> - name of service

B<Returns> - Hash of service configuration

=head2 get_constraints ($service_name)

C<service_name> - Name of service

=head2 set_constraints ($service_name, $constraints)

C<service_name> - Name of service

C<constraints> - Service constraints

=head2 update_service ($service_name, $charm_url, $force_charm_url, $min_units, $settings, $constraints)

Update a service

=head2 destroy_service ($service_name)

Destroys a service

C<service_name> - name of service

=head2 expose ($service_name)

Expose service

C<service_name> - Name of service

=head2 unexpose ($service_name)

Unexpose service

C<service_name> - Name of service

=head2 valid_relation_names

All possible relation names of a service

=head2 add_units

=head2 add_unit

=head2 remove_unit

=head2 resolved

=head2 get_public_address

=head2 set_annotation

Set annotations on entity, valid types are C<service>, C<unit>,
C<machine>, C<environment>

=head2 get_annotation

=head1 AUTHOR

Adam Stokes <adamjs@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2014 by Adam Stokes.

This is free software, licensed under:

  The MIT (X11) License

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT
WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER
PARTIES PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND,
EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE
SOFTWARE IS WITH YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME
THE COST OF ALL NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE LIABLE
TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE
SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH
DAMAGES.

=cut
