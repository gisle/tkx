#!/usr/bin/perl -w

use strict;
use yTk;

my $b;
$b = $yTk::MW->_n_button(-text => "Hello, world!",
			 -command => sub {
			     $b->_i_configure(-state => "disabled",
					      -background => "red");
			     yTk::after(3000, sub {
			         $yTk::MW->_e_destroy;
			     });
			 },
			);
$b->_e_pack;

yTk::MainLoop();
