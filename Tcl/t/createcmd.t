use Tcl;

$| = 1;

print "1..4\n";

sub foo {
    my($clientdata, $interp, @args) = @_;
    print "$clientdata->{OK} $args[1]\n";
}

sub foogone {
    my($clientdata) = @_;
    print "$clientdata->{OK} 3\n";
}

sub bar { "ok 2" }

sub bargone {
    print "ok $_[0]\n";
}

$i = new Tcl;

$i->CreateCommand("foo", \&foo, {OK => "ok"}, \&foogone);
$i->CreateCommand("bar", \&bar, 4, \&bargone);
$i->Eval("foo 1");
$i->Eval("puts [bar]");
$i->DeleteCommand("foo");
# final destructor of $i triggers destructor for Tcl proc bar
