use Tcl;

$| = 1;

print "1..5\n";

sub foo {
    my $interp = $_[1];
    $i->SetResult("ok 2");
    return undef;
}

$i = new Tcl;


$i->Eval('expr 10 + 30');
print $i->result == 40 ? "ok 1\n" : "not ok 1\n";

$i->CreateCommand("foo", \&foo);

# previously it was assumed that perl when subroutine returns undef it is
# treated as an exception. This is very uncomfortable from, say, handlers,
# where undef could be returned if a user is not aware os return value.
# As long as this was not documented, let's change this, so following test
# should always return "ok 2"
$i->Eval('if {[catch foo res]} {puts $res} else {puts "ok 2"}');

$i->ResetResult();
@qlist = qw(a{b  g\h  j{{k}  l}m{   \}n);
foreach (@qlist) {
    $i->AppendElement($_);
}

if ($i->result eq 'a\{b {g\h} j\{\{k\} l\}m\{ {\}n}') {
    print "ok 3\n";
} else {
    print "not ok 3\n";
}

@qlistout = $i->SplitList($i->result);
if ("@qlistout" eq "@qlist") {
    print "ok 4\n";
} else {
    print "not ok 4\n";
}

if ($i->SplitList('bad { format')) {
    print "not ok 5\n";
} else {
    print "ok 5\n";
}
