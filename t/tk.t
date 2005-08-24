#!perl -w

use strict;
use Test qw(plan ok);

plan tests => 10;

use Tkx;

my $delay = shift || 1;

my $mw = Tkx::widget->new(".");
$mw->configure(-border => 10);

my $b = $mw->new_button(
    -text => "Test",
    -background => "gray",
    -command => sub {
	if (Tkx::tk_messageBox(
	        -title => "Hi there",
                -icon => "question",
                -message => "Is this a fine day?",
                -parent => ".",
	         -type => "yesno",
            ) eq "yes")
        {
	    $mw->configure(-background => "#AAAAFF");
        }
	else {
	    $mw->configure(-background => "#444444");
	}
    },
);
$b->g_pack;

ok(j($mw->g_winfo_children), $b);
ok(j($b->g_winfo_children), "");
ok($b, ".b");
ok($b->m_cget("-text"), "Test");
ok($b->cget("-text"), "Test");
ok($b->configure(-text => "Test me!"), '');
ok(!$b->g_winfo_ismapped);

ok(ref($b->_data), "HASH");
$b->_data->{foo} = "bar";
ok($b->_data->{foo}, "bar");

Tkx::after($delay * 1000, sub {
    ok($b->g_winfo_ismapped);
    $mw->g_destroy;
});

Tkx::MainLoop;

sub j { join(":", @_) }
