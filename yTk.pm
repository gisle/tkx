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
	    my $orig_method = $method;
	    substr($method, $-[0], $+[0] - $-[0]) = $replacement;
	    $method_map{$orig_method} = $method;  # faster lookup next time
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
my $trace_count = 0;
my $trace_start_time = 0;

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
  $yTk::MW->_n_button(
       -text => "Hello, world",
       -command => sub { $yTk::MW->_e_destroy; },
  )->_e_pack;
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
    foo__bar -->  "foo::bar"
    foo___bar --> "foo_bar"

This allow us conveniently to map most of the Tcl namespace to perl.
Examples:

    yTk::expr("3 + 3");
    yTk::package_require("BWidget");
    yTk::DynamicHelp__add(".", -text => "Hi there");

The tripple underscore makes it it a bit hard to invoke the Tcl
commands prefixed with "tk_", but since there is also a "tk"
subcommand it is probably not worth it to make a special rule for
them.  For many of them widget handle method mapping can be used to
avoid the inconvenience.  Alternativly you might use the yTk::i::call
API to invoke these.

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
commands passed to Tcl will be printed on STDOUT.  This variable is
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

=item $w = yTk::widget->_new( $path )

This constructs a new widget handle for a given path.  It is not a
problem to have multiple handle objects to the same path.

=item $w->_data

Returns a hash that can be used to keep instance specific data.
Hopefully useful for implementing mega-widgets.  The data is
automatically destroyed when the corresponding widget is destroyed.

=item $w2 = $w->_n_I<foo>( @args )

This creates a new I<foo> widget as a child of the current widget.  It
will call the I<foo> Tcl command and pass it a new unique subpath of
the current path.  The handle to the new widget is returned.

Any underscores in the name I<foo> is expanded as described for
yTk::foo() above.  Example:

    $w->_n_label(-text => "Hello", -relief => "sunken");

=item $w->_i_I<foo>( @args )

This will invoke the I<foo> subcommand for the current widget.  This
is the same as:

    $func = "yTk::$w";
    &$func("foo", @args);

Example:

    $w->_i_configure(-background => "red");

=item $w->_e_I<foo>( @args )

This will invoke the I<foo> command with the current widget as first
argument.  This is the same as:

    $func = "yTk::foo";
    &$func($w, @args);

Example:

    $w->_e_pack_forget;

=item $w->_d_I<foo>( @args )

This will invoke the I<foo> subcommand with C<<-displayof => $w>> as
argument.  This is the same as:

    $func = "yTk::foo";
    &$func(-displayof => $w, @args);

Example:

    $w->_d_bell;

=item $w->_p_I<foo>( @args )

This will invoke the I<foo> subcommand with C<<-parent => $w>> as
argument.  This is the same as:

    $func = "yTk::foo";
    &$func(-parent => $w, @args);

Example:

    $w->_p_tk___getOpenFile;

=item $w->_t_I<foo>( @args )

This will invoke the I<foo> subcommand with the given arguments.  The
current widget is not passed as argument.  This is the same as:

    $func = "yTk::foo";
    &$func(@args);

Example:

    $w->_t_image_create_photo(-file => "donkey.png");

Usually it would be better to just do:

    yTk::image_create_photo(-file => "donkey.png");

directly, but the _t_ form can be useful to emulate some of the Tk
APIs by mapping certain method names to the C<_t_> form.

=back

The following functions are provided by the yTk::widget namespace:

=over

=item yTk::widget::_MapMethod( $from, $to )

This allow the application to set up shotcuts for widget handle
methods that don't start with underscore.  The $from argumement might
be a plain string or a Regexp object.  If this method is called then
it is resolved as if the method $to was called instead.  If from is a
Regexp object only the part of the method name that mached $from is
replaced with $to.

Examples:

    yTk::widget::_MapMethod("new_button", "_n_button");
    yTk::widget::_MapMethod("pack", "_e_pack");
    yTk::widget::_MapMethod(qr/^winfo_/, "_e_winfo_");
    yTk::widget::_MapMethod("cset", "_i_configure");
    yTk::widget::_MapMethod("cget", "_i_cget");
    yTk::widget::_MapMethod("get_open_file", "_p_tk___getOpenFile");

=back

=head1 ENVIRONMENT

The C<PERL_YTK_TRACE> environment variable initialize the $yTk::TRACE setting.

=head1 SEE ALSO

L<Tcl>, L<Tcl::Tk>, L<Tk>

