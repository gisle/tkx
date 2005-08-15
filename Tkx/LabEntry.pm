package yTk::LabEntry;

use base qw(yTk::widget yTk::MegaConfig);

__PACKAGE__->_Mega("ytk_LabEntry");
__PACKAGE__->_Config(
    -label  => [[".lab" => "-text"]],
);

sub _Populate {
    my($class, $widget, $path, %opt) = @_;

    my $self = $class->new($path)->_parent->n_frame(-name => $path);
    $self->_class($class);

    $self->n_label(-name => "lab", -text => delete $opt{-label})->e_pack(-side => "left");
    $self->n_entry(-name => "e", %opt)->e_pack(-side => "left", -fill => "both", -expand => 1);

    $self;
}

sub _ipath {
    my $self = shift;
    "$self.e";
}

1;
