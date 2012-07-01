#!/usr/bin/env perl

use strict;
use warnings;
use lib 'lib';
use Test::More;

BEGIN { use_ok( 'SafeMatchStats' ); }

ok( 1, 'Empty test.' );

my $r = new_ok( 'SafeMatchStats', [ { regex => '(d)(?<name>f)' } ] );

ok( $r->do_match( 'asdfg' ), 'Successful match' );
ok( $r->matched, 'matched Ok.' );

is( $r->prematch,  'as', 'Prematch ok.'  );
is( $r->match,     'df',  'Match ok.'    );
is( $r->postmatch, 'g',  'Postmatch ok.' );
is( $r->carat_n,   'f',  'Carat_n ok.'   );
is_deeply( $r->array_minus, [2,2,3], 'Array_minus ok.' );
is_deeply( $r->array_plus,  [4,3,4], 'Array_plus ok.'  );
is_deeply( $r->hash_minus,  { name =>['f'] },   'Hash_minus ok.'  );
like( $r->debug_info, qr/Match successful!$/, 'debug_info ok.' );

my $r2 = new_ok( 'SafeMatchStats', [ { regex => '(d)', modifiers => 'g' } ] );
ok( $r2->do_match( 'asdfg' ), 'Successful /g modifier match (list context)' );
ok( $r2->matched, 'matched Ok with /g' );
is_deeply( $r2->match_rv, [ 'd' ], 'Match_rv ok with /g.' );

done_testing();
