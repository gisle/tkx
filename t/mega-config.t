#!perl -w

use strict;
use Test qw(plan ok);

plan tests => 7;

use Tkx;

my $delay = shift || 1;

my $mw = Tkx::widget->new(".");
$mw->configure(-border => 10);

$mw->new_foo(-name => "myfoo", -text => "Bar")->g_pack;

my $foo = $mw->new_foo(-text => "Other", -foo => 42);
$foo->g_pack;

$foo->configure(-foo => 42);
ok($foo->cget("-foo"), 42);
ok($foo->_data->{"-foo"}, 42);

$foo->configure(-bw => 10, -bg => "blue");
ok($foo->cget("-bw"), 10);

$foo->configure(-bar, sub { ok(1) });
ok($foo->cget("-bar"), "_config_bar");
$foo->configure(-baz, sub { ok(1) });
ok($foo->cget("-baz"), "_config_bar");

Tkx::after($delay * 1000, sub {
    $mw->g_destroy;
});

Tkx::MainLoop;

sub j { join(":", @_) }


BEGIN {
    package Foo;
    use base qw(Tkx::widget Tkx::MegaConfig);
    __PACKAGE__->_Mega("foo");
    __PACKAGE__->_Config(
       DEFAULT =>  ["PASSIVE"],
       -bg =>   ["."],
       -bw =>   [[".", "-borderwidth"]],
       -text => [".t"],
       -bar =>  ["METHOD"],
       -baz =>  [["METHOD", "baz"]],

    );

    sub _Populate {
	my($class, $widget, $path, %opt) = @_;

	my $parent = $class->new($path)->_parent;
	my $self = $parent->new_frame(-name => $path);
	$self->_class($class);
	$self->new_label(-name => "t")->g_pack;
	$self->configure(%opt) if %opt;
	$self;
    }

    sub _config_bar {
        my $self = shift;
	if (@_) {
	    my $cb = shift;
	    &$cb();
	}
	else {
	    return "_config_bar";
	}
    }

    *baz = \&_config_bar; # lazy
}
