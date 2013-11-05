#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 3;

BEGIN {
    use_ok( 'RackSpace' ) || print "Bail out!\n";
    use_ok( 'RackSpace::CloudFiles' ) || print "Bail out!\n";
    use_ok( 'RackSpace::CloudFilesCDN' ) || print "Bail out!\n";
}

diag( "Testing RackSpace $RackSpace::VERSION, Perl $], $^X" );
