#!perl -w

use strict;
use Test qw(plan ok);

plan tests => 7, todo => [3];

use yTk qw(expr list lindex error);

ok(expr("2 + 2"), 4);
ok(expr("2", "+", "2"), 4);

ok(list(2, 3, 4), "{2 3 4}");
ok(j(list(2, 4, 4), "2:3:4"));
ok(lindex([0..9], 5), 5);
ok(lindex([0..9], "end"), 9);

eval { error("Foo") };
ok($@ && $@ =~ /Foo/);

sub j { join(":", @_) }
