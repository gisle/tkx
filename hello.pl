#!/usr/bin/perl -w

use strict;
use yTk;

my $b;
$b = $yTk::MW->button(-text => "Hello, world!",
		      -command => sub {
			  $b->configure(-state => "disabled",
					-background => "red");
			  yTk::after(3000, sub {
			      $yTk::MW->destroy;
			  });
		      },
		     );
$b->pack;

print "NAME:" . $b->winfo_name . "\n";

yTk::MainLoop();
