package Tcl;
use Carp;

$Tcl::VERSION = '0.81';
$Tcl::STACK_TRACE = 1;

=head1 NAME

Tcl - Tcl extension module for Perl

=head1 SYNOPSIS

    use Tcl;

    $interp = new Tcl;
    $interp->Eval('puts "Hello world"');

=head1 DESCRIPTION

The Tcl extension module gives access to the Tcl library with
functionality and interface similar to the C functions of Tcl.
In other words, you can

=over 8

=item create Tcl interpreters

The Tcl interpreters so created are Perl objects whose destructors
delete the interpreters cleanly when appropriate.

=item execute Tcl code in an interpreter

The code can come from strings, files or Perl filehandles.

=item bind in new Tcl procedures

The new procedures can be either C code (with addresses presumably
obtained using I<dl_open> and I<dl_find_symbol>) or Perl subroutines
(by name, reference or as anonymous subs). The (optional) deleteProc
callback in the latter case is another perl subroutine which is called
when the command is explicitly deleted by name or else when the
destructor for the interpreter object is explicitly or implicitly called.

=item Manipulate the result field of a Tcl interpreter

=item Set and get values of variables in a Tcl interpreter

=item Tie perl variables to variables in a Tcl interpreter

The variables can be either scalars or hashes.

=back

=head2 Methods in class Tcl

To create a new Tcl interpreter, use

    $i = new Tcl;

The following methods and routines can then be used on the Perl object
returned (the object argument omitted in each case).

=over 8

=item Init ()

Invoke I<Tcl_Init> on the interpeter.

=item Eval (STRING)

Evaluate script STRING in the interpreter. If the script returns
successfully (TCL_OK) then the Perl return value corresponds to
interp->result otherwise a I<die> exception is raised with the $@
variable corresponding to interp->result. In each case, I<corresponds>
means that if the method is called in scalar context then the string
interp->result is returned but if the method is called in list context
then interp->result is split as a Tcl list and returned as a Perl list.

=item GlobalEval (STRING)

Evalulate script STRING at global level. Otherwise, the same as
I<Eval>() above.

=item EvalFile (FILENAME)

Evaluate the contents of the file with name FILENAME. Otherwise, the
same as I<Eval>() above.

=item EvalFileHandle (FILEHANDLE)

Evaluate the contents of the Perl filehandle FILEHANDLE. Otherwise, the
same as I<Eval>() above. Useful when using the filehandle DATA to tack
on a Tcl script following an __END__ token.

=item call (PROC, ARG, ...)

Looks up procedure PROC in the interpreter and invokes it using Tcl's eval
semantics that does command tracing and will use the ::unknown (AUTOLOAD)
mechanism.  The arguments (ARG, ...) are not passed through the Tcl parser.
For example, spaces embedded in any ARG will not cause it to be split into
two Tcl arguments before being passed to PROC.

Before invoking procedure PROC special processing is performed on ARG list:

1.  All subroutine references within ARG will be substituted with Tcl name
which is responsible to invoke this subroutine. This Tcl name will be
created using CreateCommand subroutine (see below).

2.  All references to scalars will be substituted with names of Tcl variables
transformed appropriately.

These first two items allows to write and expect it to work properly such
code as:

  my $r = 'aaaa';
  button(".d", -textvariable => \$r, -command=>sub {$r++});

3.  As a special case, it is supported a mechanism to deal with Tk's
special event variables (they are mentioned as '%x', '%y' and so on
throughout Tcl).  When creating a subrutine reference that uses such
variables, you must declare the desired variables using Tcl::Ev as
the first argument to the subroutine.  Example:

  sub textPaste {
      my ($x,$y,$w) = @_;
      widget($w)->insert("\@$x,$y", $interp->Eval('selection get'));
  }
  $widget->bind('<2>', [\&textPaste, Tcl::Ev('%x', '%y'), $widget] );

=item icall (PROC, ARG, ...)

Looks up procedure PROC in the interpreter and invokes it using Tcl's eval
semantics that does command tracing and will use the ::unknown (AUTOLOAD)
mechanism.  The arguments (ARG, ...) are not passed through the Tcl parser.
For example, spaces embedded in any ARG will not cause it to be split into
two Tcl arguments before being passed to PROC.

This is the lower-level procedure that the 'call' method uses.  Arguments
are converted efficiently from Perl SVs to Tcl_Objs.  A Perl AV array
becomes a Tcl_ListObj, an SvIV becomes a Tcl_IntObj, etc.  The reverse
conversion is done to the result.

=item invoke (PROC, ARG, ...)

Looks up procedure PROC in the interpreter and invokes it directly with
arguments (ARG, ...) without passing through the Tcl parser. For example,
spaces embedded in any ARG will not cause it to be split into two Tcl
arguments before being passed to PROC.  This differs from icall/call in
that it directly invokes the command name without allowing for command
tracing or making use of Tcl's unknown (AUTOLOAD) mechanism.  If the
command does not already exist in the interpreter, and error will be
thrown.

Arguments are converted efficiently from Perl SVs to Tcl_Objs.  A Perl AV
array becomes a Tcl_ListObj, an SvIV becomes a Tcl_IntObj, etc.  The
reverse conversion is done to the result.

=item Tcl::Ev (FIELD, ...)

Used to declare %-substitution variables of interest to a subroutine
callback.  FIELD is expected to be of the form "%#" where # is a single
character, and multiple fields may be specified.  Returns a blessed object
that the 'call' method will recognize when it is passed as the first
argument to a subroutine in a callback.  See description of 'call' method
for details.

=item result ()

Returns the current interp->result field. List v. scalar context is
handled as in I<Eval>() above.

=item CreateCommand (CMDNAME, CMDPROC, CLIENTDATA, DELETEPROC)

Binds a new procedure named CMDNAME into the interpreter. The
CLIENTDATA and DELETEPROC arguments are optional. There are two cases:

(1) CMDPROC is the address of a C function

(presumably obtained using I<dl_open> and I<dl_find_symbol>. In this case
CLIENTDATA and DELETEPROC are taken to be raw data of the ClientData and
deleteProc field presumably obtained in a similar way.

(2) CMDPROC is a Perl subroutine

(either a sub name, a sub reference or an anonymous sub). In this case
CLIENTDATA can be any perl scalar (e.g. a ref to some other data) and
DELETEPROC must be a perl sub too. When CMDNAME is invoked in the Tcl
interpeter, the arguments passed to the Perl sub CMDPROC are

    (CLIENTDATA, INTERP, LIST)

where INTERP is a Perl object for the Tcl interpreter which called out
and LIST is a Perl list of the arguments CMDNAME was called with.
As usual in Tcl, the first element of the list is CMDNAME itself.
When CMDNAME is deleted from the interpreter (either explicitly with
I<DeleteCommand> or because the destructor for the interpeter object
is called), it is passed the single argument CLIENTDATA.

=item DeleteCommand (CMDNAME)

Deletes command CMDNAME from the interpreter. If the command was created
with a DELETEPROC (see I<CreateCommand> above), then it is invoked at
this point. When a Tcl interpreter object is destroyed either explicitly
or implicitly, an implicit I<DeleteCommand> happens on all its currently
registered commands.

=item SetResult (STRING)

Sets interp->result to STRING.

=item AppendResult (LIST)

Appends each element of LIST to interp->result.

=item AppendElement (STRING)

Appends STRING to interp->result as an extra Tcl list element.

=item ResetResult ()

Resets interp->result.

=item SplitList (STRING)

Splits STRING as a Tcl list. Returns a Perl list or the empty list if
there was an error (i.e. STRING was not a properly formed Tcl list).
In the latter case, the error message is left in interp->result.

=item SetVar (VARNAME, VALUE, FLAGS)

The FLAGS field is optional. Sets Tcl variable VARNAME in the
interpreter to VALUE. The FLAGS argument is the usual Tcl one and
can be a bitwise OR of the constants $Tcl::GLOBAL_ONLY,
$Tcl::LEAVE_ERR_MSG, $Tcl::APPEND_VALUE, $Tcl::LIST_ELEMENT.

=item SetVar2 (VARNAME1, VARNAME2, VALUE, FLAGS)

Sets the element VARNAME1(VARNAME2) of a Tcl array to VALUE. The optional
argument FLAGS behaves as in I<SetVar> above.

=item GetVar (VARNAME, FLAGS)

Returns the value of Tcl variable VARNAME. The optional argument FLAGS
behaves as in I<SetVar> above.

=item GetVar2 (VARNAME1, VARNAME2, FLAGS)

Returns the value of the element VARNAME1(VARNAME2) of a Tcl array.
The optional argument FLAGS behaves as in I<SetVar> above.

=item UnsetVar (VARNAME, FLAGS)

Unsets Tcl variable VARNAME. The optional argument FLAGS
behaves as in I<SetVar> above.

=item UnsetVar2 (VARNAME1, VARNAME2, FLAGS)

Unsets the element VARNAME1(VARNAME2) of a Tcl array.
The optional argument FLAGS behaves as in I<SetVar> above.

=back

=head2 Linking Perl and Tcl variables

You can I<tie> a Perl variable (scalar or hash) into class Tcl::Var
so that changes to a Tcl variable automatically "change" the value
of the Perl variable. In fact, as usual with Perl tied variables,
its current value is just fetched from the Tcl variable when needed
and setting the Perl variable triggers the setting of the Tcl variable.

To tie a Perl scalar I<$scalar> to the Tcl variable I<tclscalar> in
interpreter I<$interp> with optional flags I<$flags> (see I<SetVar>
above), use

	tie $scalar, Tcl::Var, $interp, "tclscalar", $flags;

Omit the I<$flags> argument if not wanted.

To tie a Perl hash I<%hash> to the Tcl array variable I<array> in
interpreter I<$interp> with optional flags I<$flags>
(see I<SetVar> above), use

	tie %hash, Tcl::Var, $interp, "array", $flags;

Omit the I<$flags> argument if not wanted. Any alteration to Perl
variable I<$hash{"key"}> affects the Tcl variable I<array(key)>
and I<vice versa>.

=head1 AUTHORS

Malcolm Beattie, mbeattie@sable.ox.ac.uk, 23 Oct 1994.
Vadim Konovalov, vkonovalov@peterstar.ru, 19 May 2003.
Jeff Hobbs, jeff (a) activestate . com, 22 Mar 2004.
Gisle Aas, gisle (a) activestate . com, 14 Apr 2004.

=head1 COPYRIGHT

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut

use strict;
use DynaLoader;
use vars qw(@ISA);
@ISA = qw(DynaLoader);

Tcl->bootstrap($Tcl::VERSION);

END {
    Tcl::_Finalize();
}

#TODO make better wording here
# %anon_refs keeps track of anonymous subroutines that were created with
# "CreateComand" method during process of transformation of arguments for
# "call" and other stuff such as scalar refs and so on.
# (TODO -- find out how to check for refcounting and proper releasing of
# resources)

my %anon_refs;

# Subroutine "call" preprocess the arguments for special cases
# and then calls "icall" (implemented in Tcl.xs), which invokes
# the command in Tcl.
sub call {
    my $interp = shift;
    my @args = @_;

    # Process arguments looking for special cases
    for (my $argcnt=0; $argcnt<=$#args; $argcnt++) {
	my $arg = $args[$argcnt];
	my $ref = ref($arg);
	next unless $ref;
	if ($ref eq 'CODE') {
	    # We have been passed something like \&subroutine
	    # Create a proc in Tcl that invokes this subroutine (no args)
	    $args[$argcnt] = $interp->create_tcl_sub($arg);
	}
	elsif ($ref =~ /^Tcl::Tk::Widget\b/) {
	    # We have been passed a widget reference.
	    # Convert to its Tk pathname (eg, .top1.fr1.btn2)
	    $args[$argcnt] = $arg->path;
	}
	elsif ($ref eq 'SCALAR') {
	    # We have been passed something like \$scalar
	    # Create a tied variable between Tcl and Perl.

	    # stringify scalar ref, create in ::perl namespace on Tcl side
	    # This will be SCALAR(0xXXXXXX) - leave it to become part of a
	    # Tcl array.
	    my $nm = "::perl::$arg";
	    #$nm =~ s/\W/_/g; # remove () from stringified name
	    unless (exists $anon_refs{$nm}) {
		$anon_refs{$nm}++;
		my $s = $$arg;
		tie $$arg, 'Tcl::Var', $interp, $nm;
		$s = '' unless defined $s;
		$$arg = $s;
	    }
	    $args[$argcnt] = $nm; # ... and substitute its name
	}
	elsif ($ref eq 'ARRAY' && ref($arg->[0]) eq 'CODE') {
	    # We have been passed something like [\&subroutine, $arg1, ...]
	    # Create a proc in Tcl that invokes this subroutine with args
	    my $events;
	    # Look for Tcl::Ev objects as the first arg - these must be
	    # passed through for Tcl to evaluate.  Used primarily for %-subs
	    # This could check for any arg ref being Tcl::Ev obj, but it
	    # currently doesn't.
	    if ($#$arg >= 1 && ref($arg->[1]) eq 'Tcl::Ev') {
		$events = splice(@$arg, 1, 1);
	    }
	    $args[$argcnt] =
		$interp->create_tcl_sub(sub {
		    splice @_, 0, 3; # remove ClientData, Interp and CmdName
		    $arg->[0]->(@_, @$arg[1..$#$arg]);
		}, $events);
	}
	elsif (ref($arg) eq 'REF' and ref($$arg) eq 'SCALAR') {
	    # this is a very special shortcut: if we see construct like \\"xy"
	    # then place proper Tcl::Ev(...) for easier access
	    my $events = [map {"%$_"} split '', $$$arg];
	    if (ref($args[$argcnt+1]) eq 'ARRAY' && 
		ref($args[$argcnt+1]->[0]) eq 'CODE') {
		$arg = $args[$argcnt+1];
		$args[$argcnt] =
		    $interp->create_tcl_sub(sub {
			splice @_, 0, 3; # remove ClientData, Interp and CmdName
			$arg->[0]->(@_, @$arg[1..$#$arg]);
		    }, $events);
	    }
	    elsif (ref($args[$argcnt+1]) eq 'CODE') {
		$args[$argcnt] = $interp->create_tcl_sub($args[$argcnt+1],$events);
	    }
	    else {
		warn "not CODE/ARRAY expected after description of event fields";
	    }
	    splice @args, $argcnt+1, 1;
	}
    }
    # Done with special var processing.  The only processing that icall
    # will do with the args is efficient conversion of SV to Tcl_Obj.
    # A SvIV will become a Tcl_IntObj, ARRAY refs will become Tcl_ListObjs,
    # and so on.  The return result from icall will do the opposite,
    # converting a Tcl_Obj to an SV.
    if (!$Tcl::STACK_TRACE) {
	return $interp->icall(@args);
    }
    elsif (wantarray) {
	my @res;
	eval { @res = $interp->icall(@args); };
	if ($@) {
	    confess "Tcl error '$@' while invoking array result call:\n" .
		"\t\"@args\"";
	}
	return @res;
    } else {
	my $res;
	eval { $res = $interp->icall(@args); };
	if ($@) {
	    confess "Tcl error '$@' while invoking scalar result call:\n" .
		"\t\"@args\"";
	}
	return $res;
    }
}

# wcall is simple wrapper to 'call' but it tries to search $res in %anon_hash
# This implementation is temporary
sub wcall {
    if (wantarray) {
	return call(@_);
    } else {
	my $res = call(@_);
	if (exists $anon_refs{$res}) {
	    return $anon_refs{$res};
	}
	return $res;
    }
}

# create_tcl_sub will create TCL sub that will invoke perl anonymous sub
# If $events variable is specified then special processing will be
# performed to provide needed '%' variables.
# If $tclname is specified then procedure will have namely that name,
# otherwise it will have machine-readable name.
# Returns tcl script suitable for using in tcl events.
sub create_tcl_sub {
    my ($interp,$sub,$events,$tclname) = @_;
    unless ($tclname) {
	# stringify sub, becomes "CODE(0x######)" in ::perl namespace
	$tclname = "::perl::$sub";
    }
    unless (exists $anon_refs{$tclname}) {
	$anon_refs{$tclname}++;
	$interp->CreateCommand($tclname, $sub);
    }
    if ($events) {
	# Add any %-substitutions to callback
	$tclname = "$tclname " . join(' ', @{$events});
    }
    return $tclname;
}
sub Ev {
    my @events = @_;
    return bless \@events, "Tcl::Ev";
}


package Tcl::Var;

sub TIESCALAR {
    my $class = shift;
    my @objdata = @_;
    Carp::croak 'Usage: tie $s, Tcl::Var, $interp, $varname [, $flags]'
	unless @_ == 2 || @_ == 3;
    bless \@objdata, $class;
}

sub TIEHASH {
    my $class = shift;
    my @objdata = @_;
    Carp::croak 'Usage: tie %hash, Tcl::Var, $interp, $varname [, $flags]'
	unless @_ == 2 || @_ == 3;
    bless \@objdata, $class;
}

sub UNTIE {
    my $ref = shift;
    print STDERR "UNTIE:$ref(@_)\n"; # Why this never called?
}
sub DESTROY {
    my $ref = shift;
    delete $anon_refs{$ref->[1]};
}

# This is the perl equiv to the C version, for reference
#
#sub STORE {
#    my $obj = shift;
#    Carp::croak "STORE Usage: objdata @{$obj} $#{$obj}, not 2 or 3 (@_)"
#	unless @{$obj} == 2 || @{$obj} == 3;
#    my ($interp, $varname, $flags) = @{$obj};
#    my ($str1, $str2) = @_;
#    if ($str2) {
#	$interp->SetVar2($varname, $str1, $str2, $flags);
#    } else {
#	$interp->SetVar($varname, $str1, $flags || 0);
#    }
#}
#
#sub FETCH {
#    my $obj = shift;
#    Carp::croak "FETCH Usage: objdata @{$obj} $#{$obj}, not 2 or 3 (@_)"
#	unless @{$obj} == 2 || @{$obj} == 3;
#    my ($interp, $varname, $flags) = @{$obj};
#    my $key = shift;
#    if ($key) {
#	return $interp->GetVar2($varname, $key, $flags || 0);
#    } else {
#	return $interp->GetVar($varname, $flags || 0);
#    }
#}

1;
__END__
