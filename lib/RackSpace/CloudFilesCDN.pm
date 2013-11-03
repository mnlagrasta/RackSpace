package RackSpace::CloudFilesCDN;

use Moo;
use RackSpace;
use Data::Dumper;

extends 'RackSpace';

has 'name' => (is => 'rw', default => 'cloudFilesCDN');
has 'type' => (is => 'rw', default => 'rax:object-cdn');
has 'endpoints' => (is => 'rw');

sub get_containers {
	my $self = shift;
	my $enabled_only = shift;

	my $r = $self->make_request({params => {enabled_only => $enabled_only}});
	my $container_info = $r->{responseContent};

	my %containers;
	foreach my $c (@$container_info) {
		$c->{parent} = $self;
		$c->{url} = $self->{active_endpoint}->{publicURL} . '/' . $c->{name};
		$containers{$c->{name}} = RackSpace::CloudFiles::CDNContainer->new($c);
	}
	return \%containers;
}

sub get_container {
	my $self = shift;
	my $name = shift;
	
	my $r = $self->make_request({
		type => 'HEAD',
		url => $name
	});
	my $container_info = $r->{responseHeaders};

	my $c = {
		'parent' => $self,
		'name' => $name,
		'ttl' => $container_info->{'X-Ttl'},
		'cdn_uri' => $container_info->{'X-Cdn-Uri'},
		'cdn_ssl_uri' => $container_info->{'X-Cdn-Ssl-Uri'},
		'log_retention' => $container_info->{'X-Log-Retention'},
		'cdn_ios_uri' => $container_info->{'X-Cdn-Ios-Uri'},
		'cdn_streaming_uri' => $container_info->{'X-Cdn-Streaming-Uri'},
		'cdn_enabled' => $container_info->{'X-Cdn-Enabled'},
	};
	
	$c->{parent} = $self;
	return RackSpace::CloudFiles::CDNContainer->new($c);
}


package RackSpace::CloudFiles::CDNContainer;

use Moo;
use Data::Dumper;
use REST::Client;
use File::Spec;

has 'parent' => (is => 'rw');
has 'name' => (is => 'rw');
has 'ttl' => (is => 'rw');
has 'name' => (is => 'rw');
has 'cdn_uri' => (is => 'rw');
has 'cdn_ssl_uri' => (is => 'rw');
has 'log_retention' => (is => 'rw');
has 'cdn_ios_uri' => (is => 'rw');
has 'cdn_streaming_uri' => (is => 'rw');
has 'cdn_enabled' => (is => 'rw');

1;
