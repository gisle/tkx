package Tkx::LabEntry;

use base qw(Tkx::widget Tkx::MegaConfig);

__PACKAGE__->_Mega("tkx_LabEntry");
__PACKAGE__->_Config(
    -label  => [[".lab" => "-text"]],
);

sub _Populate {
    my($class, $widget, $path, %opt) = @_;

    my $self = $class->new($path)->_parent->new_frame(-name => $path);
    $self->_class($class);

    $self->new_label(-name => "lab", -text => delete $opt{-label})->g_pack(-side => "left");
    $self->new_entry(-name => "e", %opt)->g_pack(-side => "left", -fill => "both", -expand => 1);

    $self;
}

sub _mpath {
    my $self = shift;
    "$self.e";
}

1;

=head1 NAME

Tkx::LabEntry - Labeled entry widget

=head1 SYNOPSIS

  use Tkx;
  use Tkx::LabEntry;

  my $mw = Tkx::widget->new(".");

  my $e = $mw->new_tkx_LabEntry(-label => "Name");
  $e->g_pack;

  my $b = $mw->new_button(
      -text => "Done",
      -command => sub {
          print $e->get, "\n";
          $mw->g_destroy;
      },
  );
  $b->g_pack;

  Tkx::MainLoop();

=head1 DESCRIPTION

The C<Tkx::LabEntry> module implements a trivial composite widget
(mega widget).  Its main purpose is to demonstrate how to use the
C<Tkx::MegaConfig> baseclass.

Once the C<Tkx::LabEntry> module has been loaded, then its widgets
can be constructed in the normal way using the C<tkx_LabEntry> name.
Besides having a label (whose text can be accessed with the C<-label>
configuration option), these widgets behave exactly like an C<entry>
would.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

Copyright 2005 ActiveState.  All rights reserved.

=head1 SEE ALSO

The source code of Tkx::LabEntry.

L<Tkx::MegaConfig>, L<Tkx>
