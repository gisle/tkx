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
    return bless \$name, $class{$name} ||
	                 ($class eq __PACKAGE__ ? $class :
                                                  ($class{$name} = $class));
}

sub _data {
    my $self = shift;
    return $data{$$self} ||= {};
}

my @method_re_map;
my %method_map;

sub _MapMethod {
    my($from, $to) = @_;
    if (ref($from) eq "Regexp") {
	push(@method_re_map, [$from, $to]);
    }
    else {
	$method_map{$from} = $to;
    }
}

sub _method {
    my(undef, $method) = @_;  # ignore self
    return $method_map{$method} if exists $method_map{$method};
    for (@method_re_map) {
	my($re, $replacement) = @$_;
	if ($method =~ $re) {
	    print "MATCH [$method] [@-] [@+]\n";
	    substr($method, $-[0], $+[0] - $-[0]) = $replacement;
	    print "   --- $method\n";
	    last;
	}
    }
    return $method;
}

sub AUTOLOAD {
    my $self = shift;

    our $AUTOLOAD;
    my $method = substr($AUTOLOAD, rindex($AUTOLOAD, '::')+2);
    my $orig = $method;

    $method = $self->_method($method) unless substr($method, 0, 1) eq "_";

    if (substr($method, 0, 1) eq "_") {
	my $kind = substr($method, 0, 3, "");
	my @m_args;
	($method, @m_args) = yTk::i::expand_name($method);
	if ($kind eq "_n_") {
	    my $n = lc($method) . ++$count{lc($method)};
	    substr($n, 0, 0) = ($$self eq "." ? "." : "$$self.");
	    return ref($self)->_new(yTk::i::call($method, $n, @m_args, @_));
	}
	elsif ($kind eq "_i_") {
	    return yTk::i::call($$self, $method, @m_args, @_);
	}
	elsif ($kind eq "_e_") {
	    return yTk::i::call($method, @m_args, $$self, @_);
	}
	elsif ($kind eq "_d_" || $kind eq "_p_") {
	    return yTk::i::call($method, @m_args,
				($kind eq "_d_" ? "-displayof" : "-parent"), $$self,
				@_);
	}
	elsif ($kind eq "_t_") {
	    return yTk::i::call($method, @m_args, @_);
	}
    }
    die "Can't locate method '$orig' for " . ref($self);
}

sub DESTROY {
    my $self = shift;
    print "DESTROY widget handle for $$self\n";
}

package yTk::widget::_destroy;

sub new {
    my($class, @paths) = @_;
    bless \@paths, $class;
}

sub DESTROY {
    my $self = shift;
    print "DESTROY @$self\n";
    for my $path (@$self) {
	if ($path eq ".") {
	    %data = ();
	    %class = ();
	    return;
	}

	my $path_re = qr/^\Q$path\E(?:\.|\z)/;
	for my $hash (\%data, \%class) {
	    for my $key (keys %$hash) {
		next unless $key =~ $path_re;
		delete $hash->{$key};
	    }
	}
    }
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
    my @cleanup;
    if ($_[0] eq "destroy") {
	my @paths = @_;
	shift(@paths);
	push(@cleanup, yTk::widget::_destroy->new(@paths));
    }
    return $interp->call(@_);
}

sub DoOneEvent {
    $interp->DoOneEvent(@_);
}

1;
