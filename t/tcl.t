#!perl -w

use strict;
use Test qw(plan ok);

plan tests => 13;

use yTk qw(expr list lindex error);

ok(expr("2 + 2"), 4);
ok(expr("2", "+", "2"), 4);

my $list = yTk::eval("list 2 [list 3 4] 5");
ok($list, "2 {3 4} 5");
ok(ref($list), "Tcl::List");
ok($list->[0], 2);
ok($list->[1][0], 3);
ok(j(@$list), "2:3 4:5");

ok(list(2, list(3, 4), 5), "2 3 4 5");
ok(list(2, scalar(list(3, 4)), 5), "2 {3 4} 5");
ok(j(list(2, scalar(list(3, 4)), 5)), "2:3 4:5");
ok(lindex([0..9, [], "}"], 5), 5);
ok(lindex([0..9], "end"), 9);

eval { error("Foo") };
print "# '$@'\n";
ok($@ && $@ =~ /^Foo/);

sub j { join(":", @_) }
