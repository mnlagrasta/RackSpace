package RackSpace;

use Moose;
use REST::Client;
use JSON;
use Date::Parse;
use HTTP::Status qw(:constants :is status_message);
use Data::Dumper;

has 'api_url' => (is => 'rw', default => 'https://identity.api.rackspacecloud.com/v2.0');
has 'user' => (is => 'rw');
has 'api_key' => (is => 'rw');
has 'token' => (is => 'rw');
has 'token_expiration' => (is => 'rw');
has 'token_expiration_epoch' => (is => 'rw');
has 'services' => (is => 'rw');
has 'service_names' => (is => 'rw');
has 'region' => (is => 'rw');
has 'endpoints' => (is => 'rw');
has 'endpoint_names' => (is => 'rw');
has 'active_endpoint' => (is => 'rw');
has 'this_service' => (is => 'rw');

sub auth() {
	my $self = shift;
	
	if ($self->{token_expiration_epoch} && $self->{token_expiration_epoch} >= time() + 3600) {
		return 1;
	} elsif ($self->{token_expiration_epoch} && $self->{token_expiration_epoch} <= time() + 3600) {
		$self->delete_token();
	}

	my $client = REST::Client->new({host => $self->api_url });
	my $auth_body = {
		"auth" => {
			"RAX-KSKEY:apiKeyCredentials" => {
				"username" => $self->user,
				"apiKey" => $self->api_key
			}
		}
	};

	$client->addHeader('Content-Type', 'application/json');
	$client->POST('/tokens', JSON::to_json($auth_body));

	my $rc = $client->responseCode();
	if (is_error($rc)) {
		die("ERROR: " . status_message($rc));
	}
	
	my $auth_result = JSON::from_json($client->responseContent());

	$self->token($auth_result->{access}->{token}->{id});
	$self->token_expiration($auth_result->{access}->{token}->{expires});
	$self->{token_expiration_epoch} = str2time($self->{token_expiration});
	
	$self->parse_services($auth_result->{access}->{serviceCatalog});
	
	$self->this_service($self->services->{$self->name()});
	$self->parse_endpoints();
	$self->set_endpoint($self->{region});
	
	return 1;
}

sub delete_token {
	my $self = shift;
	return undef unless $self->{token};

	my $url = "/tokens/$self->{token}";
	
	my $client = REST::Client->new( { host => $self->api_url } );

	$client->addHeader('x-Auth-Token', $self->{token});
	$client->DELETE($url . '?format=json');
	
	$self->{token} = undef;
	$self->{token_expiration} = undef;
	$self->{token_expiration_epoch} = undef;
	
	return 1;
}

sub set_endpoint() {
	my $self = shift;
	
	if ($self->{region}) {
		$self->active_endpoint($self->endpoints->{$self->{region}});
	} else {
		my $region = (keys %{$self->endpoints})[0];
		$self->active_endpoint($self->{endpoints}->{$region});
	}
	
	return $self->active_endpoint;
}

sub parse_endpoints() {
	my $self = shift;
	
	my $endpoints = {};
	my @endpoint_regions;
	
	foreach my $ep (@{$self->this_service->{endpoints}}) {
		push @endpoint_regions, $ep->{region};
		$endpoints->{$ep->{region}} = $ep;
	}
	
	$self->endpoint_names(\@endpoint_regions);
	$self->endpoints($endpoints);
}

sub parse_services() {
	my $self = shift;
	my $service_list = shift;
	my $service_hash = {};
	my @service_names;
	
	foreach my $service (@{$service_list}) {
		push @service_names, $service->{name};
		$service_hash->{$service->{name}} = $service;
	}
	
	$self->services($service_hash);
	$self->service_names(\@service_names);
	
	return 1;
}

sub make_request() {
	my $self = shift;
	
	my $data = shift;
	
	$data->{type} ||= 'GET';
	$data->{url} ||= '';
	
	$self->auth();
	
	my $client = REST::Client->new();
	$client->addHeader('x-Auth-Token', $self->{token});
	
	if (defined $data->{headers}) {
		foreach my $header (keys %{$data->{headers}}) {
			$client->addHeader($header, $data->{headers}{$header});
		}
	}
	
	my $full_url = $self->{active_endpoint}->{publicURL};
	
	if ($data->{url}) {
		$full_url .= '/' . $data->{url};
	}
	
	$full_url .= '?';
	
	if ($data->{params}) {
		foreach my $param (keys %{$data->{params}}) {
			$full_url .= $param . '=' . $data->{params}{$param} . '&';
		}
	}
	
	$full_url .= 'format=json';
	
	if ($data->{params}) {
		print "$full_url\n";
	}
	
	print Dumper($full_url);
	
	if ($data->{type} eq 'GET') {
		$client->GET($full_url);
	} elsif ($data->{type} eq 'PUT') {
		$client->PUT($full_url, $data->{body});
	} elsif ($data->{type} eq 'DELETE') {
		$client->DELETE($full_url);
	} elsif ($data->{type} eq 'HEAD') {
		$client->HEAD($full_url);
	}
	
	#check for, and handle, bad responses
	my $rc = $client->responseCode();
	if (is_error($rc)) {
		die("ERROR: " . status_message($rc));
	}

	my @rh_names = $client->responseHeaders();
	my %rh_return;
	foreach my $rh_name (@rh_names) {
		$rh_return{$rh_name} = $client->responseHeader($rh_name);
	}
	
	my $content;
	if ($client->responseContent()) {
		if (substr($rh_return{'Content-Type'}, 0, 16) eq 'application/json' ) {
			$content = JSON::from_json($client->responseContent());
		} else {
			$content = $client->responseContent();
		}
	}

	return {
		responseHeaders => \%rh_return,
		responseContent => $content
	};
}

1;
