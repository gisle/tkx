#!/usr/bin/perl -w

use strict;
use yTk;

yTk::widget::_MapMethod("button", "_n_button");
yTk::widget::_MapMethod("pack", "_e_pack");
yTk::widget::_MapMethod(qr/^winfo_/, "_e_winfo_");
yTk::widget::_MapMethod("configure", "_i_configure");
yTk::widget::_MapMethod("destroy", "_e_destroy");

my $mw = $yTk::MW;
my $b;

$b = $mw->button(-text => "Hello, world!",
		 -command => sub {
		     $b->configure(-state => "disabled",
				   -background => "red");
		     yTk::after(3000, sub {
			 $yTk::MW->destroy;
		     });
		 },
		);
$b->pack;

yTk::package_require("BWidget");
$mw->_n_ArrowButton->pack;

$b->_e_DynamicHelp__add(-text => "Click here to exit");

print "NAME:" . $b->winfo_name . "\n";

yTk::MainLoop();
