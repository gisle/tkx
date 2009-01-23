#!perl -w

use strict;
use Test qw(plan ok);

plan tests => 2;

use Tkx;
use Tkx::LabEntry;

my $delay = shift || 1;

my $mw = Tkx::widget->new(".");
$mw->configure(-border => 10);

$mw->new_tkx_LabEntry(-label => "foo", -name => "e")->g_pack;

my $e = $mw->_kid("e");

$mw->new_button(
    -text => "Hit me",
    -command => sub {
	my $text = $e->get;
	print "It is [$text] now\n";
	$e->configure(-label => $text, -background => $text);
    }
)->g_pack;

ok($e->cget("-label"), "foo");
ok($e->g_winfo_class, "Tkx_LabEntry");

Tkx::after($delay * 1000, sub {
    $mw->g_destroy;
});

Tkx::MainLoop;

