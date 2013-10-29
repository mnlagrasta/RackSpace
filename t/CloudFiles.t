#!/usr/bin/perl

use Test::More;
use Data::Dumper;
use lib 'lib';

BEGIN { use_ok('RackSpace::CloudFiles'); }

die ('rs_user and rs_key environment variables must be set to use this test') unless ($ENV{rs_user} && $ENV{rs_key});
my $region = $ENV{'rs_region'} || 'DFW';
my $cf = RackSpace::CloudFiles->new({user => $ENV{rs_user}, api_key => $ENV{rs_key}, region => $region});
ok($cf->auth(), 'Auth');
ok($cf->delete_token(), 'Delete token');

done_testing();
