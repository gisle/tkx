#!perl -w

use strict;
use Test qw(plan ok);

plan tests => 4;

use yTk;
use yTk::LabEntry;

my $delay = shift || 1;

my $mw = yTk::widget->new(".");
$mw->configure(-border => 10);

$mw->n_ytk_LabEntry(-label => "foo", -name => "e")->e_pack;

$mw->n_button(
    -text => "Hit me",
    -command => sub {
	print "It is [" . $mw->_kid("e")->get . "] now\n";
    }
)->e_pack;
	 

yTk::after($delay * 1000, sub {
    $mw->e_destroy;
});

yTk::MainLoop;

sub j { join(":", @_) }
