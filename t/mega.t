#!perl -w

use strict;
use Test qw(plan ok);

plan tests => 4;

use yTk;

my $delay = shift || 1;

my $mw = yTk::widget->new(".");
$mw->configure(-border => 10);

$mw->n_label(-text => "Foo")->e_pack;
$mw->n_foo(-name => "myfoo", -text => "Bar")->e_pack;

my $f = $mw->n_frame(-border => 5, -background => "#555555");
$f->e_pack;

my $foo = $f->n_foo(-text => "Other", -foo => 42);
$foo->e_pack;
ok($foo->cget("-foo"), 42);

$foo = $mw->_kid("myfoo");
ok(ref($foo), "Foo");
ok($foo->cget("-foo"), undef);
$foo->configure(-background => "yellow", -foo => 1);
ok($foo->cget("-foo"), 1);

yTk::after($delay * 1000, sub {
    $mw->e_destroy;
});

yTk::MainLoop;

sub j { join(":", @_) }


BEGIN {
    package Foo;
    use base 'yTk::widget';
    yTk::widget->_Mega("foo");

    sub _Populate {
	my($class, $widget, $path, %opt) = @_;

	my $parent = $class->new($path)->_parent;
	my $self = $parent->n_frame(-name => $path);

	$self->_data->{foo} = $opt{-foo};

	$self->n_label(-name => "lab", -text => delete $opt{-text})->e_pack(-side => "left");
	$self->n_entry->e_pack(-side => "left", -fill => "both", -expand => 1);

	$self->_class($class);
	$self;
    }

    sub _i {
	my $self = shift;
	"$self.lab";  # delegate
    }

    sub i_configure {
	my($self, %opt) = @_;
	if (exists $opt{-foo}) {
	    $self->_data->{foo} = delete $opt{-foo};
	}
	return $self->SUPER::i_configure(%opt);
    }

    sub i_cget {
	my($self, $opt) = @_;
	if ($opt eq "-foo") {
	    return $self->_data->{foo};
	}

	return $self->SUPER::i_cget($opt);
    }
}
