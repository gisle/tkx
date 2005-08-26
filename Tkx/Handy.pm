package Tkx::Handy;

# Experimental module that populates the Tkx::widget with
# various convenience methods.

use strict;

package Tkx::widget;

# versions of the geometry methods that return $self
for (qw(grid pack place)) {
    my $m = "g_$_";
    no strict 'refs';
    *{"c_$_"} = sub {
	my $self = shift;
	$self->$m(@_);
	$self;
    };
}

sub c_messageBox {
    my $self = shift;
    return Tkx::tk___messageBox(-parent => $self, @_);
}

sub c_getOpenFile {
    my $self = shift;
    return Tkx::tk___getOpenFile(-parent => $self, @_);
}

sub c_getSaveFile {
    my $self = shift;
    return Tkx::tk___getSaveFile(-parent => $self, @_);
}

sub c_chooseColor {
    my $self = shift;
    return Tkx::tk___chooseColor(-parent => $self, @_);
}

sub c_chooseDirectory {
    my $self = shift;
    return Tkx::tk___chooseDirectory(-parent => $self, @_);
}

sub c_bell {
    my $self = shift;
    Tkx::bell(-displayof => $self, @_);
}

sub c_children {
    my $self = shift;
    croak("c_children must be called in list context")
        unless wantarray;
    return map { $self->_nclass->new($_) }
           Tkx::SplitList($self->g_winfo_children);
}

1;
