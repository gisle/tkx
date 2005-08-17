#!perl -w

use strict;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME => "Tkx",
    VERSION_FROM => 'Tkx.pm',
    PREREQ_PM => {
	Tcl => 0.81,
    },
);
