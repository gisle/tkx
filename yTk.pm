package yTk;

use strict;
our $VERSION = '0.01';

{
    # predeclare
    package yTk::widget;
    package yTk::i;
}

package_require("Tk");
our $MW = yTk::widget::->new(".");
our $TRACE;
$TRACE = $ENV{PERL_YTK_TRACE} unless defined $TRACE;

sub AUTOLOAD {
    our $AUTOLOAD;
    my $method = substr($AUTOLOAD, rindex($AUTOLOAD, '::')+2);
    return yTk::i::call(yTk::i::expand_name($method), @_);
}

sub MainLoop {
    while (eval { yTk::i::call("winfo", "exists", ".") }) {
	yTk::i::DoOneEvent(0);
    }
}

*Ev = \&Tcl::Ev;

package yTk::widget;

use overload '""' => sub { ${$_[0]} },
             fallback => 1;

my %count;
my %data;
my %class;

sub new {
    my $class = shift;
    my $name = shift;
    return bless \$name, $class{$name} ||
	                 ($class eq __PACKAGE__ ? $class :
                                                  ($class{$name} = $class));
}

sub data {
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
	my $name = lc($widget) . ++$count{lc($widget)};
	while ((my $i = index($name, "::")) >= 0) {
	    substr($name, $i, 2) = "_";
	}
	substr($name, 0, 0) = ($$self eq "." ? "." : "$$self.");
	return ref($self)->new(yTk::i::call($widget, $name, @_));
    }

    if ($prefix eq "e_") {
        return yTk::i::call(yTk::i::expand_name(substr($method, 2)), $$self, @_);
    }

    if (substr($prefix, 1, 1) eq "_") {
	require Carp;
	Carp::croak("method '$method' reserved by yTk");
    }

    $method = substr($method, 2) if $prefix eq "i_";
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
	print STDERR join(" ", "yTk-$trace_count-$ts:", @_) . "\n";
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
  $yTk::MW->n_button(
       -text => "Hello, world",
       -command => sub { $yTk::MW->_e_destroy; },
  )->e_pack;
  yTk::MainLoop();

=head1 DESCRIPTION

The yTk module provide yet another Tk interface.  The main idea behind
yTk is that it should only be a thin wrapper on top of Tcl.  The
following functions are provided by the yTk namespace:

=over

=item yTk::MainLoop( )

This will enter the Tk mainloop and start processing events.  The
function returns when the main window has been destoryed.  There is no
return value.

=item yTk::Ev( $field )

This creates an object that if passed as an argument to a callback
will expand the corresponding Tcl template vars in the context of that
callback.

=item yTk::I<foo>( @args )

Any other function will invoke the given Tcl function with the given
arguments.

The name I<foo> is first undergo the following substitutions of
embedded underlines:

    foo_bar  -->  "foo", "bar"
    tk_bar   -->  "tk_bar"       # don't expand a "tk_" prefix
    foo__bar -->  "foo::bar"
    foo___bar --> "foo_bar"

This allow us conveniently to map most of the Tcl namespace to perl.
Examples:

    yTk::expr("3 + 3");
    yTk::package_require("BWidget");
    yTk::DynamicHelp__add(".", -text => "Hi there");

The arguments passed can be plain scalars or array references which
are converted to Tcl lists.  The arrays can contain other array
references or plain scalars.

For Tcl APIs that require callbacks you can pass references to a
perl function.  Alternatively an array reference with a code
reference as the first argument will allow the callback to receive the
given arguments when invoked.  The yTk::Ev() function can be used to
fill in Tcl provided info as arguments.  Eg:

    yTk::after(3000, sub { print "Hi" });
    yTk::bind(".", "<Key>", [sub { print "$_[0]\n"; }, yTk::Ev("%A")]);

=item yTk::i:call($foo, @args)

This will invoke the $foo function without doing any magic
substitutions on its name.

=back

The following variables are provided by the yTk namespace:

=over

=item $yTk::MW

This variable holds a reference to widget handle for the root widget;
C<.> in Tcl.  See L</Widget handles> for more information.

=item $yTk::TRACE

If this boolean is set to a true value, then we a trace of all
commands passed to Tcl will be printed on STDERR.  This variable is
initialized from the C<PERL_YTK_TRACE> environment variable.

=back

=head2 Widget handles

The class C<yTk::widget> is used to wrap Tk widget paths or names.
These objects stringify as the path they wrap so they can be used as
if they were the plain path as well.

Only names starting with C<_> are used by the interface.  All other
names can be set up for as suitable by the user code.  See the
_MapMethod() function for details.

The following methods are provided:

=over

=item $w = yTk::widget->new( $path )

This constructs a new widget handle for a given path.  It is not a
problem to have multiple handle objects to the same path.

=item $w->data

Returns a hash that can be used to keep instance specific data.
Hopefully useful for implementing mega-widgets.  The data is
automatically destroyed when the corresponding widget is destroyed.

=item $new_w = $w->n_I<foo>( @args )

This creates a new I<foo> widget as a child of the current widget.  It
will call the I<foo> Tcl command and pass it a new unique subpath of
the current path.  The handle to the new widget is returned.
Any underscores in the name I<foo> is expanded as described for
yTk::foo() above.

Example:

    $w->n_label(-text => "Hello", -relief => "sunken");

=item $w->i_I<foo>( @args )

This will invoke the I<foo> subcommand for the current widget.  This
is the same as:

    $func = "yTk::$w";
    &$func(expand("foo"), @args);

where the expand() function expands underscores as described for
yTk::foo() above.

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

