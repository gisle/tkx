package yTk;

use strict;
our $VERSION = '0.01';

{
    # predeclare
    package yTk::widget;
    package yTk::i;
}

package_require("Tk");

our $TRACE;
our $TRACE_MAX_STRING = 64;
$TRACE = $ENV{PERL_YTK_TRACE} unless defined $TRACE;

sub import {
    my($class, @subs) = @_;
    my $pkg = caller;
    for (@subs) {
	s/^&//;
	if (/^[a-zA-Z]\w*/ && $_ ne "import") {
	    no strict 'refs';
	    *{"$pkg\::$_"} = \&$_;
	}
	else {
	    die qq("$_" is not exported by the $class module);
	}
    }
}

sub AUTOLOAD {
    our $AUTOLOAD;
    my $method = substr($AUTOLOAD, rindex($AUTOLOAD, '::')+2);
    return yTk::i::call(yTk::i::expand_name($method), @_);
}

sub MainLoop {
    while (eval { local $TRACE; yTk::i::call("winfo", "exists", ".") }) {
	yTk::i::DoOneEvent(0);
    }
}

*Ev = \&Tcl::Ev;

package yTk::widget;

use overload '""' => sub { ${$_[0]} },
             fallback => 1;

my %data;

sub new {
    my $class = shift;
    my $name = shift;
    return bless \$name, $class;
}

sub _data {
    my $self = shift;
    return $data{$$self} ||= {};
}

sub AUTOLOAD {
    my $self = shift;

    our $AUTOLOAD;
    my $method = substr($AUTOLOAD, rindex($AUTOLOAD, '::')+2);
    my $prefix = substr($method, 0, 2);

    if ($prefix eq "n_") {
	my $widget = yTk::i::expand_name(substr($method, 2));
	my $name;
	for (my $i = 0; $i < @_; $i += 2) {
	    if ($_[$i] eq "-name") {
		(undef, $name) = splice(@_, $i, 2);
		substr($name, 0, 0) = ($$self eq "." ? "." : "$$self.");
		last;
	    }
	}
	$name ||= yTk::i::wname($widget, $$self);
	return ref($self)->new(yTk::i::call($widget, $name, @_));
    }

    if ($prefix eq "e_") {
        return yTk::i::call(yTk::i::expand_name(substr($method, 2)), $$self, @_);
    }

    if ($prefix eq "i_") {
	$method = substr($method, 2);
    }
    elsif (substr($prefix, 1, 1) eq "_") {
	require Carp;
	Carp::croak("method '$method' reserved by yTk");
    }

    return yTk::i::call($$self, yTk::i::expand_name($method), @_);
}

sub DESTROY {}  # avoid AUTOLOADing it


package yTk::widget::_destroy;

sub new {
    my($class, @paths) = @_;
    bless \@paths, $class;
}

sub DESTROY {
    my $self = shift;
    for my $path (@$self) {
	if ($path eq ".") {
	    %data = ();
	    return;
	}

	my $path_re = qr/^\Q$path\E(?:\.|\z)/;
	for my $key (keys %data) {
	    next unless $key =~ $path_re;
	    delete $data{$key};
	}
    }
}

package yTk::i;

use Tcl;
$Tcl::STACK_TRACE = 0;

my $interp;
my $trace_count = 0;
my $trace_start_time = 0;

BEGIN {
    $interp = Tcl->new;
    $interp->Init;
}

sub expand_name {
    my(@f) = (shift);
    @f = split(/(?<!_)_(?!_)/, $f[0]) if wantarray;
    for (@f) {
	s/(?<!_)__(?!_)/::/g;
	s/(?<!_)___(?!_)/_/g;
    }
    splice(@f, 0, 2, "$f[0]_$f[1]") if @f >= 2 && $f[0] eq "tk";  # tk_foo kept as is
    wantarray ? @f : $f[0];
}

sub wname {
    my($class, $parent) = @_;
    my $name = lc($class);
    $name =~ s/.*:://;
    substr($name, 1) = "";
    my @kids = call("winfo", "children", $parent);
    substr($name, 0, 0) = ($parent eq "." ? "." : "$parent.");
    if (grep $_ eq $name, @kids) {
	my %kids = map { $_ => 1 } @kids;
	my $count = 2;
	$count++ while $kids{"$name$count"};
	$name .= $count;
    }
    $name;
}

sub call {
    if ($yTk::TRACE) {
	$trace_count++;
	unless ($trace_start_time) {
	    if (eval { require Time::HiRes }) {
		$trace_start_time = Time::HiRes::time();
	    }
	    else {
		$trace_start_time = time;
	    }
	}
	my $ts;
	if (defined &Time::HiRes::time) {
	    $ts = sprintf "%.1f", Time::HiRes::time() - $trace_start_time;
	}
	else {
	    $ts = time - $trace_start_time;
	}
	my($cmd, @args) = @_;
	for (@args) {
	    if (ref eq "ARRAY" || ref eq "Tcl::List") {
		$_ = $interp->call("format", "[list %s]", $_);
	    }
	    elsif (ref eq "CODE" || ref eq "ARRAY" && ref($_->[0]) eq "CODE") {
		$_ = "perl::callback";
	    }
	    else {
		if ($TRACE_MAX_STRING && length > $TRACE_MAX_STRING) {
		    substr($_, 2*$TRACE_MAX_STRING/3, -$TRACE_MAX_STRING/3) = " ... ";
		}
		s/([\\{}\"\[\]\$])/\\$1/g;
		s/\r/\\r/g;
		s/\n/\\n/g;
		s/\t/\\t/g;
		s/([^\x00-\xFF])/sprintf "\\u%04x", ord($1)/ge;
		s/([^\x20-\x7e])/sprintf "\\x%02x", ord($1)/ge;
		$_ = "{$_}" if / /;
	    }
	}
	print STDERR join(" ", "yTk-$trace_count-$ts:", $cmd, @args) . "\n";
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

__END__

=head1 NAME

yTk - Yet another Tk interface

=head1 SYNOPSIS

  use yTk;
  my $mw = yTk::widget->new(".");
  $mw->n_button(
       -text => "Hello, world",
       -command => sub { $mw->_e_destroy; },
  )->e_pack;
  yTk::MainLoop();

=head1 DESCRIPTION

The C<yTk> module provide yet another Tk interface for Perl.  Tk is a
GUI toolkit tied to the Tcl language, and C<yTk> provide a bridge to
Tcl that allows Tk based applications to be written in Perl.

The main idea behind yTk is that it should only be a thin wrapper on
top of Tcl, i.e. that what you get is exactly the behaviour you read
about in the Tcl/Tk documentation.

The following functions are provided:

=over

=item yTk::MainLoop( )

This will enter the Tk mainloop and start processing events.  The
function returns when the main window has been destroyed.  There is no
return value.

=item yTk::Ev( $field )

This creates an object that if passed as an argument to a callback
will expand the corresponding Tcl template vars in the context of that
callback.

=item yTk::I<foo>( @args )

Any other function will invoke the I<foo> Tcl function with the given
arguments.

The name I<foo> first undergo the following substitutions of
embedded underlines:

    foo_bar  -->  "foo", "bar"   # break into words
    tk_bar   -->  "tk_bar"       # but don't expand a "tk_" prefix
    foo__bar -->  "foo::bar"
    foo___bar --> "foo_bar"      # when you actually need a '_'

This allow us conveniently to map most of the Tcl namespace to perl.
If this mapping does not suit you use yTk::i::call($foo, @args); this
will invoke the given function with no substitutions.

Examples:

    yTk::expr("3 + 3");
    yTk::package_require("BWidget");
    yTk::DynamicHelp__add(".", -text => "Hi there");

The arguments passed can be plain scalars or array references.  Array
references are converted to Tcl lists.  The arrays can contain other
array references or plain scalars to form nested lists.

For Tcl APIs that require callbacks you can pass a reference to a
perl function.  Alternatively an array reference with a code
reference as the first argument, will allow the callback to receive the
given arguments when invoked.  The yTk::Ev() function can be used to
fill in Tcl provided info as arguments.  Eg:

    yTk::after(3000, sub { print "Hi" });
    yTk::bind(".", "<Key>", [sub { print "$_[0]\n"; }, yTk::Ev("%A")]);

In scalar context the Tcl string result is returned.  In array context
the return value is interpreted as a list and broken up before it is
returned to Perl.  Tcl errors are propagated as Perl exceptions.

If the boolean variable $yTk::TRACE is set to a true value, then a
trace of all commands passed to Tcl will be printed on STDERR.  This
variable is initialized from the C<PERL_YTK_TRACE> environment
variable.  The trace is useful for debugging and if you need to report
errors to the Tcl maintainers.  The trace lines are prefixed with:

    yTk-$seq-$ts:

where $seq is a sequence number and $ts is a timestamp in seconds
since the first command was issued.

=back

All these functions can be exported by yTk if you grow tired of typing
the C<yTk::> prefix.  Example:

    use strict;
    use yTk qw(MainLoop button pack destroy);

    pack(button(".b", -text => "Press me!", -command => [\&destroy, "."]));
    MainLoop;

=head2 Widget handles

The class C<yTk::widget> is used to wrap Tk widget paths or names.
These objects stringify as the path they wrap.

The following methods are provided:

=over

=item $w = yTk::widget->new( $path )

This constructs a new widget handle for a given path.  It is not a
problem to have multiple handle objects to the same path.

=item $w->_data

Returns a hash that can be used to keep instance specific data.
Hopefully useful for implementing mega-widgets.  The data is
automatically destroyed when the corresponding widget is destroyed.

=item $new_w = $w->n_I<foo>( @args )

This creates a new I<foo> widget as a child of the current widget.  It
will call the I<foo> Tcl command and pass it a new unique subpath of
the current path.  The handle to the new widget is returned.  Any
double underscores in the name I<foo> is expanded as described for
yTk::foo() above.

Example:

    $w->n_label(-text => "Hello", -relief => "sunken");

The name selected for the child will be the first letter in the
widget.  If that name is not unique a number is appended to ensure
uniqueness among the children.  If a C<-name> argument is passed it is
used to form the name and then removed from the arglist passed to Tcl.
Example:

    $w->n_iwidgets_calendar(-name => "cal");

=item $w->i_I<foo>( @args )

This will invoke the I<foo> subcommand for the current widget.  This
is the same as:

    $func = "yTk::$w";
    &$func(expand("foo"), @args);

where the expand() function expands underscores as described for
yTk::foo() above.  Note that methods that do not start with a prefix
of the form /^[a-zA-Z]_/ are also treated as the C<i_> methods.

Example:

    $w->i_configure(-background => "red");

=item $w->e_I<foo>( @args )

This will invoke the I<foo> command with the current widget as first
argument.  This is the same as:

    $func = "yTk::foo";
    &$func($w, @args);

Example:

    $w->e_pack_forget;

=item $w->I<foo>( @args )

If there is no prefix of the form /^[a-zA-Z]_/, then it is treated as
if it had the "i_" prefix, i.e. the I<foo> subcommand for the current
widget is invoked.

The method names with prefix /^[a-zA-Z]_/ are reserved for future
extensions to this API.

=back

=head1 ENVIRONMENT

The C<PERL_YTK_TRACE> environment variable initialize the $yTk::TRACE setting.

=head1 SEE ALSO

L<Tcl>, L<Tcl::Tk>, L<Tk>

L<http://www.tcl.tk/>
