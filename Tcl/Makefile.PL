#!perl -w

# before running this script make sure you have 'tclsh' in your path, 
# and this 'tcl' distribution is required one.
# FreeBSD users may want to modify name of tcl interpreter (this is
# $tclsh variable below) as long as 'tclsh' does not work in their case

use strict;
use Getopt::Long qw(GetOptions);
use ExtUtils::MakeMaker;

my $tclsh = 'tclsh';
my $tclconfig = "/local/ActiveTcl/8.4.6.1.99118/lib/tclConfig.sh";
my $buildspec;
my $usestubs;
my $libpath;
my $incpath;
my $wince;

GetOptions("tclsh=s", \$tclsh,
	   "tclconfig=s", \$tclconfig,
	   "buildspec", \$buildspec,
	   "usestubs", \$usestubs,
	  )
    || die <<EOT;

Usage: perl Makefile.PL [--tclsh <path>] [--tclconfig <path>]
                        [--buildspec] [--usestubs] [<makemaker opts>...]

or for WinCE cross-compilation:

       perl -MCross=[your-cross-name] Makefile.PL PERL_CORE=1
             PERL_SRC=[your-perl-distribution-for-wince-crosscompiling]

EOT


if (defined $Cross::platform) {
    # All appropriate environment variables shoult be set properly, such
    # as OSVERSION, PLATFORM, WCEROOT, SDKROOT. This is usually done with
    # appropriate 'bat' file. such as WCEMIPS.BAT
    #
    #
    # edit following two paths to reflect your situation
    # when editing please note that there should be tcl84.lib
    # libraries at "$tcldir\\wince\\$Cross::platform-release"
    #
    my $tcldir = 'D:\personal\pocketPC\tcltk\84a2\tcl8.4a2';

    WriteMakefile(
        NAME => "Tcl",
        VERSION_FROM => 'Tcl.pm',
        LIBS => ["-l$tcldir\\wince\\$Cross::platform-release\\tcl84.lib"],
        INC => "-I$tcldir\\generic",
    );
    exit;
}

my $buildtype = ($usestubs ? "stub" : "");
my $defs      = ($usestubs ? "-DUSE_TCL_STUBS" : "");

# If using stubs, we will set the LIB_RUNTIME_DIR and TCL_LIB_FILE
# to point to the install location as the default dll to load.

if ($tclconfig) {
    die "Tcl config file '$tclconfig' not found\n" unless (-f $tclconfig);

    # Retrieve all info based on tclConfig.sh
    my $variant    = ($usestubs ? "_STUB" : "");
    $variant       = "_BUILD$variant" if $buildspec;
    my $libspecvar = "TCL${variant}_LIB_SPEC";
    my %tclcfg;
    process_tclconfig($tclconfig, \%tclcfg);
    die "Tcl requires Tcl v8.4 or greater, found '$tclcfg{TCL_VERSION}'\n"
	unless (defined $tclcfg{'TCL_VERSION'}
		&& $tclcfg{'TCL_VERSION'} >= 8.4);
    $libpath = $tclcfg{$libspecvar};
    $incpath = $tclcfg{'TCL_INCLUDE_SPEC'};
    if ($usestubs) {
	if ($^O eq 'MSWin32') {
	    $defs .= " -DLIB_RUNTIME_DIR=\\\"$tclcfg{'TCL_EXEC_PREFIX'}/bin\\\"";
	    $defs .= " -DTCL_LIB_FILE=\\\"$tclcfg{'TCL_DLL_FILE'}\\\""; 
	} else {
	    $defs .= " -DLIB_RUNTIME_DIR=\\\"$tclcfg{'TCL_EXEC_PREFIX'}/lib\\\"";
	    $defs .= " -DTCL_LIB_FILE=\\\"$tclcfg{'TCL_LIB_FILE'}\\\""; 
	}
    }
} else {
    open(TCLSH, "$tclsh tclcfg.tcl |") or die "error starting tclsh: $!\n";
    my $tclcfg = join '', <TCLSH>;
    close(TCLSH);
    print $tclcfg;
    my %tclcfg = $tclcfg =~ /^([^=]+)=(.*?)\n/gm;

    if (0 && -f $tclcfg{'tclConfig.sh'}) {
	# Retrieve all info based on tclConfig.sh
	# Don't do this unless the user passes --tclconfig
	process_tclconfig($tclcfg{'tclConfig.sh'}, \%tclcfg);
	# libpath/incpath vars need to be set here if used ...
    } else {
	my $tclver = $tclcfg{tcl_version};

	# currently version must be 8.4+
	my ($vmaj,$vmin) = ($tclver =~ /^(\d+)\.(\d+)/);
	die "Tcl requires Tcl v8.4 or greater, found '$vmaj.$vmin'\n"
	    if ($vmaj < 8 || ($vmaj == 8 && $vmin < 4));

	if ($tclcfg{tcl_library} =~ /^(.*)[\\\/]lib[\\\/]/) {
	    $libpath = "-L$1/lib";
	    $incpath = "-I$1/include";
	    $defs .= " -DLIB_RUNTIME_DIR=\\\"$1/lib\\\"" if $usestubs;
	}

	if ($^O eq 'MSWin32') {
	    $tclver=~s/\.//;
	    $defs .= " -DTCL_LIB_FILE=\\\"tcl$tclver.dll\\\"" if $usestubs; 
	}
	elsif ($^O eq 'freebsd') {
	    $tclver=~s/\.//;
	    $tclsh=~/([\d.]+)$/ and $incpath .= " -I/usr/local/include/tcl$1";
	    $defs .= " -DTCL_LIB_FILE=\\\"libtcl$tclver.so\\\"" if $usestubs; 
	}
	else {
	    #$tclver = '';
	    $defs .= " -DTCL_LIB_FILE=\\\"libtcl$tclver.so\\\"" if $usestubs; 
	}
	$libpath .= " -ltcl$buildtype$tclver";
    }
}
print "LIBS   = $libpath\n";
print "INC    = $incpath\n";
print "DEFINE = $defs\n";

#print <<"#EOS";
WriteMakefile(
    NAME => "Tcl",
    VERSION_FROM => 'Tcl.pm',
    LIBS => ["$libpath"],
    INC => "$incpath",
    DEFINE => $defs,
);

#EOS

sub process_tclconfig {
    # Process a tclConfig.sh file for build info
    my $tclconfig = shift;
    my $hashref   = shift;

    open(TCLSH, $tclconfig)
	or die "error opening file '$tclconfig': $!\n";
    print "Using config data in $tclconfig\n";
    my $tclcfg = join '', <TCLSH>;
    close(TCLSH);
    %$hashref = $tclcfg =~ /^(\w+)=['"]?(.*?)["']?\n/gm;

    for my $k (keys %$hashref) {
	# Handle sh subs like ${TCL_DBGX}
	$hashref->{$k} =~ s/\$\{(\w+)\}/(exists $hashref->{$1} ? $hashref->{$1} : $&)/eg;
	# Handle any cygdrive-style paths
	$hashref->{$k} =~ s,/cygdrive/(\w)/,$1:/,ig;
    }
}
