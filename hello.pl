#!/usr/bin/perl -w

use strict;
use yTk;

my $b = $yTk::MW->_n_button(-text => "Hello, world!", -command => sub { $yTk::MW->_e_destroy });
$b->_e_pack;

yTk::MainLoop();
