package yTk::LabEntry;

use base 'yTk::widget';
__PACKAGE__->_Mega("ytk_LabEntry");

sub _Populate {
    my($class, $widget, $path, %opt) = @_;

    my $self = $class->new($path)->_parent->n_frame(-name => $path);

    $self->n_label(-name => "lab", -text => delete $opt{-label})->e_pack(-side => "left");
    $self->n_entry(-name => "e", %opt)->e_pack(-side => "left", -fill => "both", -expand => 1);

    $self->_class($class);
    $self;
}

sub _i {
    my $self = shift;
    "$self.e";
}

sub i_configure {
    my($self, %opt) = @_;
    if (exists $opt{-label}) {
	$self->_kid("lab")->i_configure(-text => delete $opt{-label});
    }
    return $self->SUPER::i_configure(%opt) if %opt;
}

sub i_cget {
    my($self, $opt) = @_;
    if ($opt eq "-label") {
	return $self->_kid("lab")->i_cget("-text");
    }
    return $self->SUPER::i_cget($opt);
}

1;
