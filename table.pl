use strict;
use warnings;
use Tkx;

Tkx::package_require("Tktable");

my $mw = Tkx::widget->new(".");
my %hash;
tie %hash, 'Tcl::Var', Tkx::i::interp(), "myarray";
%hash = ( # data to display
  '0,0' => 'Goodby',
  '1,1' => 'cruel',
  '2,2' => 'world',
);
my $t = $mw->new_table(
    -rows => 5,
    -cols => 3,
    -cache => 1,
    -variable => "myarray",
);
$t->g_pack(-fill => 'both', -expand => 1);
Tkx::MainLoop();
use Data::Dump; dd \%hash;
