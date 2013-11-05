=head1 NAME

RackSpace::CloudFilesCDN - Perl wrapper for RackSpace's CloudFilesCDN API

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Provides a Perl wrapper to RackSpace's CLoudFiles CDN containers.

Perhaps a little code snippet.

    use RackSpace::CloudFilesCDN;
	
	# You will need to set the rs_user and rs_key environment variables or hard code them here.
	my $user = $ENV{'rs_user'};
	my $api_key  = $ENV{'rs_key'};
	my $region = 'DFW';
	
	my $cfcdn = RackSpace::CloudFilesCDN->new({user => $user, api_key => $api_key, region => $region });
	my $cdn_containers = $cfcdn->get_containers();
	my $cdn_pu = $cfcdn->get_container('dev_photo_upload');


=head1 AUTHOR

Michael LaGrasta, C<< <michael at lagrasta.com> >>


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc RackSpace::CloudFilesCDN


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

package RackSpace::CloudFilesCDN;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Moo;

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

use 5.006;
use strict;
use warnings FATAL => 'all';

use Moo;
use REST::Client;
use File::Spec;

has 'parent' => (is => 'rw');
has 'name' => (is => 'rw');
has 'ttl' => (is => 'rw');
has 'cdn_uri' => (is => 'rw');
has 'cdn_ssl_uri' => (is => 'rw');
has 'log_retention' => (is => 'rw');
has 'cdn_ios_uri' => (is => 'rw');
has 'cdn_streaming_uri' => (is => 'rw');
has 'cdn_enabled' => (is => 'rw');

1; # End of RackSpace::CloudFilesCDN
