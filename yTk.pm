package yTk;

use strict;
our $VERSION = '0.01';

{
    # predeclare
    package yTk::widget;
    package yTk::i;
}

package_require("Tk");
our $MW = yTk::widget::->_new(".");

sub AUTOLOAD {
    our $AUTOLOAD;
    my $method = substr($AUTOLOAD, rindex($AUTOLOAD, '::')+2);
    return yTk::i::call(yTk::i::expand_name($method), @_);
}

sub MainLoop {
    while (yTk::i::call("winfo", "exists", ".")) {
	yTk::i::DoOneEvent(0);
    }
}

package yTk::widget;

use overload '""' => sub { ${$_[0]} },
             fallback => 1;

my %count;
my %data;
my %class;

sub _new {
    my $class = shift;
    my $name = shift;
    return bless \$name, $class{$name} || ($class eq __PACKAGE__ ? $class : ($class{$name} = $class));
}

sub _data {
    my $self = shift;
    return $data{$$self} ||= {};
}

sub AUTOLOAD {
    our $AUTOLOAD;
    my $method = substr($AUTOLOAD, rindex($AUTOLOAD, '::')+2);
    my $self = shift;
    if (substr($method, 0, 1) eq "_") {
	my $kind = substr($method, 0, 3, "");
	if ($kind eq "_n_") {
	    my $n = $method . ++$count{$method};
	    substr($n, 0, 0) = ($$self eq "." ? "." : "$$self.");
	    no strict 'refs';
	    my $m = "yTk::$method";
	    return ref($self)->_new(&$m($n, @_));
	}
	elsif ($kind eq "_i_") {
	    return yTk::i::call($$self, yTk::i::expand_name($method), @_);
	}
	elsif ($kind eq "_e_") {
	    no strict 'refs';
	    my $m = "yTk::$method";
	    return &$m($$self, @_);
	}
	elsif ($kind eq "_d_" || $kind eq "_p_") {
	    no strict 'refs';
	    my $m = "yTk::$method";
	    return &$m(($kind eq "_d_" ? "-displayof" : "-parent"), $$self, @_);
	}
	elsif ($kind eq "_t_") {
	    no strict 'refs';
	    my $m = "yTk::$method";
	    return &$m(@_);
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
my $TRACE = 0;
my $trace_count = 0;

BEGIN {
    $interp = Tcl->new;
    $interp->Init;
}

sub expand_name {
    my(@f) = (shift);
    @f = split(/(?<!_)_(?!_)/, $f[0]);
    for (@f) {
	s/(?<!_)__(?!_)/::/g;
	s/(?<!_)___(?!_)/_/g;
    }
    @f;
}

sub call {
    if ($TRACE) {
	$trace_count++;
	print STDERR join(" ", "yTk-$trace_count:", @_) . "\n";
    }
    return $interp->call(@_);
}

sub DoOneEvent {
    $interp->DoOneEvent(@_);
}

1;
