#!/usr/bin/perl

use Test::More;
use Data::Dumper;
use lib 'lib';

BEGIN { use_ok('RackSpace::CloudFiles'); }

die ('rs_user and rs_key environment variables must be set to use this test') unless ($ENV{rs_user} && $ENV{rs_key});
my $region = $ENV{'rs_region'} || 'DFW';

my $cf_target = {
                  'api_url' => 'https://identity.api.rackspacecloud.com/v2.0',
                  'user' => 'drjays',
                  'region' => 'DFW',
                  'name' => 'cloudFiles',
                  'type' => 'rax:object-cdn',
                  'api_key' => 'ca59f184be49bd69af912efd7fe4af56'
                };
my $cf = RackSpace::CloudFiles->new({user => $ENV{rs_user}, api_key => $ENV{rs_key}, region => $region});
ok( eq_hash($cf, $cf_target), 'Object Creation' );

ok($cf->auth(), 'Auth');

ok($cf->delete_token(), 'Delete token');

my $ct1 = $cf->create_container('test1');
ok($ct1, 'Create Container');

my $ct2 = $cf->create_container('test2');

my $containers = $cf->get_containers();
ok($containers, 'Get Containers');

my $ct3 = $cf->get_container('test1');
ok($ct3, 'Get Container');

# upload
my $test_content = "This is a test file.\nIt has two lines.\n";
open(my $fh, '>', 'test.txt');
print $fh $test_content;
close($fh);
my $upload_result = $ct1->upload_file('test.txt');
ok($upload_result, 'File Upload');

# get files
my $files = $ct1->get_files();
ok($files, 'Get Files');

# copy
my $copy_result = $files->{'test.txt'}->copy('test2/copy_good.txt');
ok($copy_result, 'File Copy');

# filtered get files
my $filtered_files = $ct2->get_files('copy');
ok($filtered_files, 'Get Files (filtered)');

# download
my $dl_data = $files->{'test.txt'}->download();
is($dl_data, $test_content, 'File Download');

# delete
my $delete_result = $files->{'test.txt'}->delete();
ok($delete_result, 'File Delete');

# remove our test file
unlink('test.txt');

done_testing();
