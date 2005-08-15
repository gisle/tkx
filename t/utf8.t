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

use yTk;

my $delay = shift || 1;
my $text = "«1000 \x{2030}»";

my $mw = yTk::widget->new(".");
#$mw->configure(-border => 10);

my $b = $mw->n_button(
    -text => "«1000 \x{2030}»",
    -width => 40,
);
$b->e_pack(-fill => "x", -expand => 1);

my $e = $mw->n_entry(
    -textvariable => \$text,
);
$e->e_pack(-fill => "x", -expand => 1);

$mw->e_wm_title("«1000 \x{2030}» is enough");
ok($mw->e_wm_title, "«1000 \x{2030}» is enough");

yTk::after($delay * 1000, sub {
    $mw->e_destroy;
});

yTk::MainLoop;

sub j { join(":", @_) }
