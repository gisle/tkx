use Tcl;

$| = 1;

print "1..8\n";

sub foo {
    my $interp = $_[1];
    my $glob = $interp->GetVar("bar", Tcl::GLOBAL_ONLY);
    my $loc = $interp->GetVar("bar");
    print "$glob $loc\n";
    $interp->GlobalEval('puts $four');
}

$i = new Tcl;

$i->SetVar("foo", "ok 1");
$i->Eval('puts $foo');

$i->Eval('set foo "ok 2\n"');
print $i->GetVar("foo");

$i->CreateCommand("foo", \&foo);
$i->Eval(<<'EOT');
set bar ok
set four "ok 4"
proc baz {} {
    set bar 3
    set four "not ok 4"
    foo
}
baz
EOT

$i->Eval('set a(OK) ok; set a(five) 5');
$ok = $i->GetVar2("a", "OK");
$five = $i->GetVar2("a", "five");
print "$ok $five\n";

print defined($i->GetVar("nonesuch")) ? "not ok 6\n" : "ok 6\n";

# some Unicode tests
if ($]>=5.006 && $i->GetVar("tcl_version")>=8.1) {
    $i->SetVar("univar","\x{abcd}\x{1234}");
    if ($i->GetVar("univar") ne "\x{abcd}\x{1234}") {
	print "not ";
    }
    print "ok 7 # Unicode persistence during [SG]etVar\n";
    my $r;
    tie $r, Tcl::Var, $i, "perl_r";
    $r = "\x{abcd}\x{1234}";
    if ($r ne "\x{abcd}\x{1234}") {
	print "not ";
    }
    print "ok 8 # Unicode persistence for tied variable\n";
    binmode(STDOUT, ":utf8") if $] >= 5.008;
    print "# $r\n";
}
else {
    for (7..8) {print "ok $_  # skipped: not Unicode-aware Perl or Tcl\n";}
}

