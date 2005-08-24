#!perl -w

# This test is more useful as an interactive test where you can
# verify that what is displayed look right.  The \x{2030} is the
# permille sign.
#
# On Unix this progam shows different wrong behaviour depending
# on what kind of locale it runs under.

use strict;
use Test qw(plan ok);

plan tests => 1;

use Tkx;

my $delay = shift || 1;
my $text = "«1000 \x{2030}»";

my $mw = Tkx::widget->new(".");
#$mw->configure(-border => 10);

my $b = $mw->new_button(
    -text => "«1000 \x{2030}»",
    -width => 40,
);
$b->g_pack(-fill => "x", -expand => 1);

my $e = $mw->new_entry(
    -textvariable => \$text,
);
$e->g_pack(-fill => "x", -expand => 1);

$mw->g_wm_title("«1000 \x{2030}» is enough");
ok($mw->g_wm_title, "«1000 \x{2030}» is enough");

Tkx::after($delay * 1000, sub {
    $mw->g_destroy;
});

Tkx::MainLoop;

sub j { join(":", @_) }
