#!perl -w

use strict;
use Test qw(plan ok);

plan tests => 10;

use yTk;

my $delay = shift || 1;

my $mw = yTk::widget->new(".");
$mw->configure(-border => 10);

my $b = $mw->n_button(
    -text => "Test",
    -background => "gray",
    -command => sub {
	if (yTk::tk_messageBox(
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
$b->e_pack;

ok(j($mw->e_winfo_children), $b);
ok(j($b->e_winfo_children), "");
ok($b, ".b");
ok($b->i_cget("-text"), "Test");
ok($b->cget("-text"), "Test");
ok($b->configure(-text => "Test me!"), '');
ok(!$b->e_winfo_ismapped);

ok(ref($b->_data), "HASH");
$b->_data->{foo} = "bar";
ok($b->_data->{foo}, "bar");

yTk::after($delay * 1000, sub {
    ok($b->e_winfo_ismapped);
    $mw->e_destroy;
});

yTk::MainLoop;

sub j { join(":", @_) }
