#!perl -w

use strict;
use Test qw(plan ok);

plan tests => 6;

use Tcl;
use Sys::Hostname qw(hostname);
use File::Spec::Functions;

my $tcl = Tcl->new;

ok($tcl);
ok(canonpath($tcl->Eval("info nameofexecutable")), canonpath($^X));
ok($tcl->Eval("info hostname"), hostname);

my $tclversion = $tcl->Eval("info tclversion");
ok($tclversion =~ /^8\.\d+$/);
ok(substr($tcl->Eval("info patchlevel"), 0, length($tclversion)), $tclversion);
ok(length($tcl->Eval("info patchlevel")) > length($tclversion));
