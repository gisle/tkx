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

my %method = (
    bell        => "_d_bell",
    bind        => "_e_bind",
    bindtags    => "_e_bindtags",
    button      => "_n_button",
    canvas      => "_n_canvas",
    cget        => "_i_cget",
    checkbutton => "_n_checkbutton",
    chooseColor => "_p_tk_chooseColor",
    chooseDirectory => "_p_tk_chooseDirectory",
    configure   => "_i_configure",
    destroy     => "_e_destroy",
    entry       => "_n_entry",
    focus       => "_e_focus",
    frame       => "_n_frame",
    getOpenFile => "_p_tk_getOpenFile",
    getSaveFile => "_p_tk_getSaveFile",
    grid        => "_e_grid",
    label       => "_n_label",
    labelframe  => "_n_labelframe",
    listbox     => "_n_listbox",
    lower       => "_e_lower",
    menu        => "_n_menu",
    menubutton  => "_n_menubutton",
    message     => "_n_message",
    messageBox  => "_p_tk_messageBox",
    optionMenu  => "_n_tk_optionMenu",
    pack        => "_e_pack",
    panedwindow => "_n_panedwindow",
    place       => "_e_place",
    popup       => "_e_tk_popup",
    radiobutton => "_n_radiobutton",
    raise       => "_e_raise",
    scale       => "_n_scale",
    selection   => "_d_selection",
    spinbox     => "_n_spinbox",
    text        => "_n_text",
    toplevel    => "_n_toplevel",
    winfo       => "_e_winfo",
    wm          => "_e_wm",
);

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
    my $orig = $method;
    my $underline = substr($method, 0, 1) eq "_";
    my @m = $underline ? ($method) : yTk::i::expand_name($method);
    $method = shift(@m);
    $method = $method{$method} if $method{$method};
    my $self = shift;
    if (substr($method, 0, 1) eq "_") {
	my $kind = substr($method, 0, 3, "");
	($method, @m) = yTk::i::expand_name($method) if $underline;
	if ($kind eq "_n_") {
	    my $n = lc($method) . ++$count{lc($method)};
	    substr($n, 0, 0) = ($$self eq "." ? "." : "$$self.");
	    return ref($self)->_new(yTk::i::call($method, $n, @m, @_));
	}
	elsif ($kind eq "_i_") {
	    return yTk::i::call($$self, $method, @m, @_);
	}
	elsif ($kind eq "_e_") {
	    return yTk::i::call($method, @m, $$self, @_);
	}
	elsif ($kind eq "_d_" || $kind eq "_p_") {
	    return yTk::i::call($method, @m,
				($kind eq "_d_" ? "-displayof" : "-parent"), $$self,
				@_);
	}
	elsif ($kind eq "_t_") {
	    return yTk::i::call($method, @m, @_);
	}
    }
    die "Can't locate method '$orig' for yTk widget";
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
