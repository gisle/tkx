#!/usr/bin/perl -w

use strict;
use yTk;

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

print "NAME:" . $b->winfo_name . "\n";

yTk::MainLoop();
