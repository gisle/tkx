package yTk::MegaConfig;

use strict;

my %spec;

sub _Config {
    my $class = shift;
    while (@_) {
	my($opt, $spec) = splice(@_, 0, 2);
	$spec{$class}{$opt} = $spec;
    }
}

sub i_configure {
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
	    $self->_kid($where)->i_configure($where_args[0] || $opt, $val);
	    next;
	}

	if ($where eq "METHOD") {
	    $opt =~ s/^-//;
	    my $method = $where_args[0];
	    unless ($method) {
		$method = "_config_" . substr($opt, 1);
	    }
	    $self->$method($val);
	    next;
	}

	if ($where eq "PASSIVE") {
	    $self->_data->{$opt} = $val;
	    next;
	}

	die;
    }

    $self->yTk::widget::i_configure(@rest) if @rest;   # XXX want NEXT instead
}

sub i_cget {
    my($self, $opt) = @_;
    my $spec = $spec{ref($self)}{$opt} || $spec{ref($self)}{DEFAULT};
    return $self->yTk::widget::i_cget($opt) unless $spec;  # XXX want NEXT instead

    my $where = $spec->[0];
    my @where_args;
    if (ref($where) eq "ARRAY") {
	($where, @where_args) = @$where;
    }

    if ($where =~ s/^\.//) {
	return $self->_kid($where)->i_cget($where_args[0] || $opt);
    }

    if ($where eq "METHOD") {
	$opt =~ s/^-//;
	my $method = $where_args[0];
	unless ($method) {
	    $method = "_config_" . substr($opt, 1);
	}
	return $self->$method;
    }

    if ($where eq "PASSIVE") {
	return $self->_data->{$opt};
    }

    die;
}

1;
