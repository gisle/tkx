use Tcl;

$| = 1;

print "1..5\n";

$i = new Tcl;
$i->Eval(q(puts "ok 1"));
($a, $b) = $i->Eval(q(list 2 ok));
print "$b $a\n";
eval { $i->Eval(q(error "ok 3\n")) };
print $@;
$i->call("puts", "ok 4");
$i->EvalFileHandle(\*DATA);
__END__
set foo ok
set bar 5
puts "$foo $bar"
