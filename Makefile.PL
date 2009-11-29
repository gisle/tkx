#!perl -w

use strict;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME => "Tkx",
    VERSION_FROM => 'lib/Tkx.pm',
    ABSTRACT_FROM => 'lib/Tkx.pm',
    PREREQ_PM => {
	Tcl => 0.98,
    },
    AUTHOR => 'Gisle Aas <gisle@activestate.com>',
    EXE_FILES => [qw(tkx-ed tkx-prove)],
    LICENSE => "perl",
    MIN_PERL_VERSION => 5.008,
    META_MERGE => {
	resources => {
            repository => 'http://github.com/gisle/tkx/',
	    MailingList => 'mailto:tcltk@perl.org',
        }
    },
);

BEGIN {
    # compatibility with older versions of MakeMaker
    my $developer = -f ".gitignore";
    my %mm_req = (
        LICENCE => 6.31,
        META_MERGE => 6.45,
        META_ADD => 6.45,
        MIN_PERL_VERSION => 6.48,
    );
    undef(*WriteMakefile);
    *WriteMakefile = sub {
        my %arg = @_;
        for (keys %mm_req) {
            unless (eval { ExtUtils::MakeMaker->VERSION($mm_req{$_}) }) {
                warn "$_ $@" if $developer;
                delete $arg{$_};
            }
        }
        ExtUtils::MakeMaker::WriteMakefile(%arg);
    };
}
