#!perl -w

use strict;
use Test;

plan tests => 7;

use Tkx qw(set after);

set("foo", sub {
    ok @_, 2;
    ok "@_", "a b c";
});
ok set("foo"), qr/^::perl::CODE\(0x/;
Tkx::eval('[set foo] a {b c}');

set("foo", [sub {
    ok @_, 4;
    ok "@_", "a b c d e f";
}, "d", "e f"]);
Tkx::eval('[set foo] a {b c}');

set("foo", [sub {
    ok @_, 6;
    ok "@_", "2 3 a b c d";
}, Tkx::Ev('[expr 1+1]', '[expr 1+2]'), "c", "d"]);
Tkx::eval('eval [set foo] a b');
