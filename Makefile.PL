#!perl -w

use strict;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME => "yTk",
    VERSION_FROM => 'yTk.pm',
    PREREQ_PM => {
#	Tcl => 0.81,
    },
);
