#!perl -w

use strict;
use Test qw(plan ok);

plan tests => 4;

{
    package MyTcl;
    require Tcl;
    @MyTcl::ISA = qw(Tcl);

    sub eval {
	my $self = shift;
	$self->Eval(@_);
    }
}

my $tcl = MyTcl->new;
ok(ref($tcl), "MyTcl");
ok($tcl->isa("Tcl"));
ok($tcl->eval("set var 42"), 42);
ok($tcl->eval("set var"), 42);
