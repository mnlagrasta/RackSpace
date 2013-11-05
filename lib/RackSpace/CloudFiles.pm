=head1 NAME

RackSpace::CloudFiles - Perl wrapper for RackSpace's CloudFiles API

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

First pass at a Perl interface to RackSpace's Cloud services, beginning with CloudFiles

Looks like this:

	use RackSpace::CloudFiles;

	my $user = $ENV{'rs_user'};
	my $api_key  = $ENV{'rs_key'};
	my $region = 'DFW';
	
	# create the main object
	my $cf = RackSpace::CloudFiles->new({user => $user, api_key => $api_key, region => $region});
	
	# each API call will call auth if needed, no need to do it explicitly

	# create a container, returns a container object on success
	my $container = $cf->create_container('api_test');
	
	# get all containers
	my $containers = $cf->get_containers();
	
	# use an individual container from set by name
	my $container = $cf->get_container('api_test');
	
	# upload
	$cf_pa->upload_file('rs_test.txt');
	
	# get files
	my $files = $container->get_files();
	
	# copy
	$files->{'rs_test.txt'}->copy('api_test/copy_good.pl');
	
	# download
	my $dl_data = $files->{'rs_test.txt'}->download();
	
	# delete
	$files->{'rs_test.txt'}->delete();
	

=head1 AUTHOR

Michael LaGrasta, C<< <michael at lagrasta.com> >>



=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc RackSpace


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

package RackSpace::CloudFiles;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Moo;
use RackSpace;

extends 'RackSpace';

has 'name' => (is => 'rw', default => 'cloudFiles');
has 'type' => (is => 'rw', default => 'rax:object-cdn');
has 'endpoints' => (is => 'rw');

sub get_containers {
	my $self = shift;
	my $container_info = $self->make_request();

	my %containers;
	foreach my $c (@{$container_info->{responseContent}}) {
		$c->{parent} = $self;
		$c->{url} = $self->{active_endpoint}->{publicURL} . '/' . $c->{name};
		$containers{$c->{name}} = RackSpace::CloudFiles::Container->new($c);
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
		name => $name,
		count => $container_info->{'X-Container-Object-Count'},
		bytes => $container_info->{'X-Container-Bytes-Used'},
		timestamp => $container_info->{'X-Timestamp'},
		url => $self->{active_endpoint}->{publicURL} . '/' . $name
	};
	
	$c->{parent} = $self;
	return RackSpace::CloudFiles::Container->new($c);
}

sub create_container {
	my $self = shift;
	my $name = shift;
	
	my $r = $self->make_request({
		type => 'PUT',
		url => $name
	});
	
	return $self->get_container($name);
}

package RackSpace::CloudFiles::Container;

use Moo;
use REST::Client;
use File::Spec;

has 'parent' => (is => 'rw');
has 'url' => (is => 'rw');
has 'name' => (is => 'rw');
has 'bytes' => (is => 'rw');
has 'count' => (is => 'rw');
has 'timestamp' => (is => 'rw');

sub get_files() {
	my $self = shift;
	my $prefix = shift;

	my $req_data = {
		type => 'GET',
		url => $self->{name},
	};
	
	if ($prefix) {
		$req_data->{params} = {prefix => $prefix};
	}
	
	
	my $r = $self->{parent}->make_request($req_data);
	my $file_info = $r->{responseContent};
	
	my %result;
	foreach my $file (@$file_info) {
		$file->{url} = $self->{parent}->{active_endpoint}->{publicURL} . '/' . $self->{name} . '/' . $file->{name};
		$file->{parent} = $self;
		$result{$file->{name}} = RackSpace::CloudFiles::File->new($file);
	}
	
	return \%result;
}

sub upload_file {
	my $self = shift;
	my $file_name = shift;

	my ($volume,$directories,$file) = File::Spec->splitpath($file_name);
	open( my $fh, "<", $file_name ) || die "Can't open $file_name: $!";
	my $body = join('', <$fh>);	

	$self->{parent}->make_request({
		type => 'PUT',
		url => $self->{name} . '/' . $file,
		body => $body
	});

	return 1;
}

package RackSpace::CloudFiles::File;

use Moo;

has 'name' => (is => 'rw');
has 'hash' => (is => 'rw');
has 'content_type' => (is => 'rw');
has 'bytes' => (is => 'rw');
has 'last_modified' => (is => 'rw');
has 'parent' => (is => 'rw');
has 'url' => (is => 'rw');

sub download {
	my $self = shift;
	my $r = $self->{parent}->{parent}->make_request({
		type => 'GET',
		url => $self->{parent}->{name} . '/' . $self->{name}
	});
	return $r->{responseContent};
}

sub delete {
	my $self = shift;
	$self->{parent}->{parent}->make_request({
		type => 'DELETE',
		url => $self->{parent}->{name} . '/' . $self->{name}
	});
}

sub copy {
	my $self = shift;
	my $target = shift;
	
	$self->{parent}->{parent}->make_request({
		type => 'PUT',
		url => $target,
		headers => {
			'x-Copy-From' => $self->{parent}->{name} . '/' . $self->{name},
			'Content-Length' => 0
		}
	});
}

1; # End of RackSpace
