#!perl -w

use strict;
use Test qw(plan ok);

plan tests => 3;

use Tcl;

# These tests are bit lame, as they depend on the actual values,
# but at least it verifies that the constants are set up.

ok(Tcl::OK, 0);
ok(Tcl::ERROR, 1);

ok(Tcl::GLOBAL_ONLY      |
   Tcl::NAMESPACE_ONLY   |
   Tcl::APPEND_VALUE     |
   Tcl::LIST_ELEMENT     |
   Tcl::TRACE_READS      |
   Tcl::TRACE_WRITES     |
   Tcl::TRACE_UNSETS     |
   Tcl::TRACE_DESTROYED  |
   Tcl::INTERP_DESTROYED |
   Tcl::LEAVE_ERR_MSG    |
   Tcl::TRACE_ARRAY,
   0xBFF);
