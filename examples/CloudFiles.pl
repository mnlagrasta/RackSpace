#!/usr/bin/perl

use strict;
use lib '../lib';
use RackSpace::CloudFiles;
use Data::Dumper;

# You will need to set the rs_user and rs_key environment variables or hard code them here.
my $user = $ENV{'rs_user'};
my $api_key  = $ENV{'rs_key'};
my $region = 'DFW';

# create a local file to test with
`echo "This is a test.\nIt is a test file\n" > rs_test.txt`;

# basic cf container operations
my $cf = RackSpace::CloudFiles->new({user => $user, api_key => $api_key, region => $region});

# create a container, returns a container object on success
my $container = $cf->create_container('api_test');

# get all containers
my $containers = $cf->get_containers();

# use an individual container from set by name
my $cf_pa = $cf->get_container('api_test');

# upload
$cf_pa->upload_file('rs_test.txt');

# get files
my $files = $cf_pa->get_files();

# copy
$files->{'rs_test.txt'}->copy('api_test/copy_good.pl');

# download
my $dl_data = $files->{'rs_test.txt'}->download();
print $dl_data;

# delete
$files->{'rs_test.txt'}->delete();

# delete our test file
unlink('rs_test.txt');

# basic cf cdn container operations
#my $cfcdn = RackSpace::CloudFilesCDN->new({user => $user, api_key => $api_key, region => $region });
#my $cdn_containers = $cfcdn->get_containers();
#my $cdn_pu = $cfcdn->get_container('dev_photo_upload');
#print Dumper($cdn_pu);
