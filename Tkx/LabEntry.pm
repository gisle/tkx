package Tkx::LabEntry;

use base qw(Tkx::widget Tkx::MegaConfig);

__PACKAGE__->_Mega("ytk_LabEntry");
__PACKAGE__->_Config(
    -label  => [[".lab" => "-text"]],
);

sub _Populate {
    my($class, $widget, $path, %opt) = @_;

    my $self = $class->new($path)->_parent->c_frame(-name => $path);
    $self->_class($class);

    $self->c_label(-name => "lab", -text => delete $opt{-label})->g_pack(-side => "left");
    $self->c_entry(-name => "e", %opt)->g_pack(-side => "left", -fill => "both", -expand => 1);

    $self;
}

sub _mpath {
    my $self = shift;
    "$self.e";
}

1;
