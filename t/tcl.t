#!perl -w

use strict;
use Test qw(plan ok);

plan tests => 18;

use yTk qw(expr list lindex error);

ok(expr("2 + 2"), 4);
ok(expr("2", "+", "2"), 4);

my $list = yTk::eval("list 2 [list 3 4] 5");
ok($list, "2 {3 4} 5");
ok(ref($list), "Tcl::List");
ok($list->[0], 2);
ok($list->[1][0], 3);
ok(j(@$list), "2:3 4:5");

ok(list(2, yTk::SplitList(list(3, 4)), 5), "2 3 4 5");
ok(list(2, scalar(list(3, 4)), 5), "2 {3 4} 5");
ok(j(yTk::SplitList(list(2, scalar(list(3, 4)), 5))), "2:3 4:5");
ok(lindex([0..9, [], "}"], 5), 5);
ok(lindex([0..9], "end"), 9);

my @list = yTk::SplitList("a b");
ok(@list, 2);
ok($list[0], "a");
ok($list[1], "b");
ok(yTk::SplitList("a b"), "a b");

eval { @list = yTk::SplitList("a {") };
#print "# '$@'\n";
ok($@ && $@ =~ /valid Tcl list/);

eval { error("Foo") };
#print "# '$@'\n";
ok($@ && $@ =~ /^Foo/);

sub j { join(":", @_) }
