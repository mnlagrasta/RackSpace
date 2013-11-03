package RackSpace::CloudFiles;

use Moose;
use RackSpace;
use Data::Dumper;

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
	
	print Dumper($r);
	
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

use Moose;
use Data::Dumper;
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

use Moose;
use Data::Dumper;

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

1;

=head1 NAME

RackSpace::CloudFiles - A Perl wrapper around RackSpace's CloudFiles API

=head1 SYNOPSIS

# create object with credentials
my $cf = RackSpace::CloudFiles->new({user => $user, api_key => $api_key, region => $region});

# return container reference objects
my $containers = $cf->get_containers();

# use a specific container object
my $cf_pa = $cf->get_container('dev_photo_archive');

# upload a local file to the container
$cf_pa->upload_file('test.txt');

# return file objects within container
my $files = $cf_pa->get_files();

# copy a single file within or across containers
$files->{'test.txt'}->copy('dev_photo_archive/copy_good.pl');

# download a single file from container
my $dl_data = $files->{'test.txt'}->download();

# delete a file from container
$files->{'test.txt'}->delete();


=head1 DESCRIPTION

An attempt to make basic CloudFiles API access more comfortable from Perl

=head1 METHODS

=over 4

=item new

 Construct a new CloudFiles object. Takes hash of config options

=item get_containers

 incomplete

=item get_container

 incomplete

=back

=head1 TODO

Complete the PerlDoc ;)

=head1 AUTHOR

Michael LaGasra, E<lt>michael@lagrasta.comE<gt>

=head1 COPYRIGHT

Copyright 2013 by Michael LaGrasta

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
