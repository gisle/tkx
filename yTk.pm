package yTk;

use strict;
our $VERSION = '0.01';

package_require("Tk");
our $MW = yTk::widget::->_new(".");

sub AUTOLOAD {
    our $AUTOLOAD;
    my $method = substr($AUTOLOAD, rindex($AUTOLOAD, '::')+2);
    return yTk::i::call($method, @_);
}

sub MainLoop {
    while (winfo_exists(".")) {
	yTk::i::DoOneEvent(0);
    }
}

package yTk::widget;

use overload '""' => sub { ${$_[0]} },
             fallback => 1;

my %c;

sub _new {
    my $class = shift;
    my $name = shift;
    bless \$name, $class;
}

sub AUTOLOAD {
    our $AUTOLOAD;
    my $method = substr($AUTOLOAD, rindex($AUTOLOAD, '::')+2);
    my $self = shift;
    if (substr($method, 0, 1) eq "_") {
	my $kind = substr($method, 0, 3, "");
	if ($kind eq "_n_") {
	    my $n = $method . ++$c{$method};
	    substr($n, 0, 0) = ($$self eq "." ? "." : "$$self.");
	    no strict 'refs';
	    my $m = "yTk::$method";
	    return ref($self)->_new(&$m($n, @_));
	}
	elsif ($kind eq "_e_") {
	    no strict 'refs';
	    my $m = "yTk::$method";
	    return &$m($$self, @_);
	}
	$method = "$kind$method";
    }
    die "Can't locate method '$method' for yTk widget";
}

sub DESTROY {
    my $self = shift;
    print "DESTROY $self\n";
}

package yTk::i;

use Tcl;

my $interp;
my $TRACE = 1;
my $trace_count = 0;

BEGIN {
    $interp = Tcl->new;
    $interp->Init;
}

sub call {
    my(@f) = (shift);
    @f = split(/(?<!_)_(?!_)/, $f[0]);
    for (@f) {
	s/(?<!_)__(?!_)/::/g;
	s/(?<!_)___(?!_)/_/g;
    }
    if ($TRACE) {
	$trace_count++;
	print STDERR join(" ", "yTk-$trace_count:", @f, @_) . "\n";
    }
    return $interp->call(@f, @_);
}

sub DoOneEvent {
    $interp->DoOneEvent(@_);
}

1;
