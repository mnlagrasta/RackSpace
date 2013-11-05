package RackSpace;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Moo;
use REST::Client;
use JSON;
use Date::Parse;
use HTTP::Status qw(:constants :is status_message);


=head1 NAME

RackSpace - Perl wrapper for RackSpace's Cloud Services API

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

First pass at a Perl interface to RackSpace's Cloud services, beginning with CloudFiles.

You really won't use this module directly, but instead use the service specific modules
such as RackSpace::CloudFiles and RackSpace::CloudFilesCDN.


=head1 AUTHOR

Michael LaGrasta, C<< <michael at lagrasta.com> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc RackSpace


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Michael LaGrasta.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

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

1; # End of RackSpace
