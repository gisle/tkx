#!perl -w

use strict;
use Test qw(plan ok);

plan tests => 1;

use yTk;
use yTk::LabEntry;

my $delay = shift || 1;

my $mw = yTk::widget->new(".");
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

yTk::after($delay * 1000, sub {
    $mw->e_destroy;
});

yTk::MainLoop;

