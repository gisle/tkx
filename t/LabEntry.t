#!perl -w

use strict;
use Test qw(plan ok);

plan tests => 1;

use Tkx;
use Tkx::LabEntry;

my $delay = shift || 1;

my $mw = Tkx::widget->new(".");
$mw->configure(-border => 10);

$mw->n_ytk_LabEntry(-label => "foo", -name => "e")->e_pack;

my $e = $mw->_kid("e");

$mw->n_button(
    -text => "Hit me",
    -command => sub {
	my $text = $e->get;
	print "It is [$text] now\n";
	$e->configure(-label => $text, -background => $text);
    }
)->e_pack;

ok($e->cget("-label"), "foo");

Tkx::after($delay * 1000, sub {
    $mw->e_destroy;
});

Tkx::MainLoop;

