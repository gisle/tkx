package Tkx::MegaConfig;

use strict;
our $VERSION = "1.07";

my %spec;

sub _Config {
    my $class = shift;
    while (@_) {
	my($opt, $spec) = splice(@_, 0, 2);
	$spec{$class}{$opt} = $spec;
    }
}

sub m_configure {
    my $self = shift;
    my @rest;
    while (@_) {
	my($opt, $val) = splice(@_, 0, 2);
	my $spec = $spec{ref($self)}{$opt} || $spec{ref($self)}{DEFAULT};
	unless ($spec) {
	    push(@rest, $opt => $val);
	    next;
	}

	my $where = $spec->[0];
	my @where_args;
	if (ref($where) eq "ARRAY") {
	    ($where, @where_args) = @$where;
	}

	if ($where =~ s/^\.//) {
            my $fwd_opt = $where_args[0] || $opt;
	    if ($where eq "") {
		$self->Tkx::widget::m_configure($fwd_opt, $val);
		next;
	    }
            if ($where eq "*") {
                for my $kid ($self->_kids) {
                    $kid->m_configure($fwd_opt, $val);
                }
                next;
            }
	    $self->_kid($where)->m_configure($fwd_opt, $val);
	    next;
	}

	if ($where eq "METHOD") {
	    my $method = $where_args[0] || "_config_" . substr($opt, 1);
	    $self->$method($val);
	    next;
	}

	if ($where eq "PASSIVE") {
	    $self->_data->{$opt} = $val;
	    next;
	}

	die;
    }

    $self->Tkx::widget::m_configure(@rest) if @rest;   # XXX want NEXT instead
}

sub m_cget {
    my($self, $opt) = @_;
    my $spec = $spec{ref($self)}{$opt} || $spec{ref($self)}{DEFAULT};
    return $self->Tkx::widget::m_cget($opt) unless $spec;  # XXX want NEXT instead

    my $where = $spec->[0];
    my @where_args;
    if (ref($where) eq "ARRAY") {
	($where, @where_args) = @$where;
    }

    if ($where =~ s/^\.//) {
        my $fwd_opt = $where_args[0] || $opt;
	return $self->Tkx::widget::m_cget($fwd_opt) if $where eq "";
        return ($self->_kids)[0]->m_cget($fwd_opt) if $where eq "*";
	return $self->_kid($where)->m_cget($fwd_opt);
    }

    if ($where eq "METHOD") {
	my $method = $where_args[0] || "_config_" .substr($opt, 1);
	return $self->$method;
    }

    if ($where eq "PASSIVE") {
	return $self->_data->{$opt};
    }

    die;
}

1;

__END__

=head1 NAME

Tkx::MegaConfig - handle configuration options for megawidgets

=head1 SYNOPSIS

  package Foo;
  use base qw(Tkx::widget Tkx::MegaConfig);

  __PACKAGE__->_Mega("foo");
  __PACKAGE__->_Config(
      -option  => [$where, $dbName, $dbClass, $default],
  );

=head1 DESCRIPTION

The C<Tkx::MegaConfig> class provide implementations of m_configure()
and m_cget() that can handle configuration options for megawidgets.
How these methods behave is set up by calling the _Config() class
method.  The _Config() method takes a set option/option spec pairs as
argument.

An option argument is either the name of an option with leading '-'
or the string 'DEFAULT' if this spec applies to all option with no
explict spec.

If there is no 'DEFAULT' then unmatched options are applied directly
to the megawidget root itself.  This is the same behaviour you get if
you specify:

   __PACKAGE__->_Config(
      ...
      DEFAULT => ['.'],
   );

The option spec should be an array reference.  The first element of
the array ($where) describe how this option is handled.  Some $where
specs take arguments.  If you need to provide argument replace $where
with an array reference containg [$where, @args].  The rest of the
option spec specify names and default for the options database, but is
currently ignored (feature unimplemented).

The following $where specs are understood:

=over

=item .foo

Delegate the given configuration option to the "foo" kid of the mega
widget root.  The name "." can be used to delegate to the megawidget
root itself.  The name ".*" can be used to delegate to all kids of the
megawidget root.

An argument can be given to delegate using a different
configuration name name on the "foo" widget.  Examples:

   -foo => [".inner"],                 # forward -foo
   -bg  => [[".", "-background]],      # alias
   -bg2 => [[".inner", "-background]], # forward as -background
   -background => [".*"]               # forward --background to kids

=item METHOD

Call the _config_I<opt> method.  For m_cget() no arguments are given,
while for m_configure() the new value is passed.  If an extra $where
argument is given it will be the method called instead of
_config_I<opt>.  Examples:

   __PACKAGE__->_Config(
      -foo => ["METHOD"];
      -bar => [["METHOD", "bar"]],
   }

   sub _config_foo {
       my $self = shift;
       return "foo" unless @_;
       print "Ignoring setting configuration option -foo to '$_[0]'";
   }

   sub handle_bar {
       my $self = shift;
       return "bar" unless @_;
       print "Ignoring setting configuration option -bar to '$_[0]'";
   }

=item PASSIVE

Store or retrieve option from $self->_data.

=back

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

Copyright 2005 ActiveState.  All rights reserved.

=head1 SEE ALSO

L<Tkx>, L<Tkx::LabEntry>

Inspiration for this module comes from L<Tk::ConfigSpecs>.
