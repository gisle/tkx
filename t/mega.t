#!perl -w

use strict;
use Test qw(plan ok);

plan tests => 5;

use Tkx;

my $delay = shift || 1;

my $mw = Tkx::widget->new(".");
$mw->configure(-border => 10);

$mw->new_label(-text => "Foo")->g_pack;
$mw->new_foo(-name => "myfoo", -text => "Bar")->g_pack;

my $f = $mw->new_frame(-border => 5, -background => "#555555");
$f->g_pack;

my $foo = $f->new_wrapped("foo", -text => "Other", -foo => 42);
$foo->g_pack;
ok($foo->cget("-foo"), 42);
ok($foo->blurb, "...");

$foo = $mw->_kid("myfoo");
ok(ref($foo), "Foo");
ok($foo->cget("-foo"), undef);
$foo->configure(-background => "yellow", -foo => 1);
ok($foo->cget("-foo"), 1);

Tkx::after($delay * 1000, sub {
    $mw->g_destroy;
});

Tkx::MainLoop;

sub j { join(":", @_) }


BEGIN {
    package Foo;
    use base 'Tkx::widget';
    Tkx::widget->_Mega("foo");

    sub _Populate {
	my($class, $widget, $path, %opt) = @_;

	my $parent = $class->new($path)->_parent;
	my $self = $parent->new_frame(-name => $path);

	$self->_data->{foo} = $opt{-foo};

	$self->new_label(-name => "lab", -text => delete $opt{-text})->g_pack(-side => "left");
	$self->new_entry->g_pack(-side => "left", -fill => "both", -expand => 1);

	$self->_class($class);
	$self;
    }

    sub _mpath {
	my $self = shift;
	"$self.lab";  # delegate
    }

    sub m_configure {
	my($self, %opt) = @_;
	if (exists $opt{-foo}) {
	    $self->_data->{foo} = delete $opt{-foo};
	}
	return $self->SUPER::m_configure(%opt);
    }

    sub m_cget {
	my($self, $opt) = @_;
	if ($opt eq "-foo") {
	    return $self->_data->{foo};
	}

	return $self->SUPER::m_cget($opt);
    }

    sub m_blurb {
        return "...";
    }

    package Tkx::Wrapped;
    use base qw(Tkx::widget Tkx::MegaConfig);
    __PACKAGE__->_Mega('wrapped');
    __PACKAGE__->_Config(
        DEFAULT => [".wrapped"],
    );

    sub _Populate {
        my $class  = shift;
        my $widget = shift;
        my $path   = shift;
        my $type   = shift;
        my %opt    = @_;

        my $self = $class->new($path)->_parent->new_frame(-name => $path);
        $self->_class($class);

        my $new_thing = "new_$type";
        my $w = $self->$new_thing(-name => 'wrapped', %opt);

        $w->g_pack();

        return $self;
    }

    sub _mpath {
        my $self = shift;
        $$self . '.wrapped';
    }

}
