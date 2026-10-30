#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../blib/arch", "$FindBin::Bin/../blib/lib", "$FindBin::Bin/../lib";
use Tk;
use Tk::IDElayout;
use Tk::IDEtabFrame;
require "$FindBin::Bin/lib/testTextEdit.pl";

my $mw = MainWindow->new;
$mw->title('Tk::IDElayout - draggable tabs');
$mw->geometry('800x600');
my $config = Tk::IDElayout->defaultIDEtabFrameConfig;
my %widgets;
for my $name (qw(Tab1 Tab2)) {
    my $tabs = $mw->IDEtabFrame(@$config);
    $widgets{$name} = $tabs;
    my @files = $name eq 'Tab1'
        ? qw(IDElayout.pm IDEtabFrame.pm)
        : qw(IDEpanedwindow.pm CaptureRelease.pm);
    for my $file (@files) {
        my $tab = $tabs->add(-caption => $file, -label => $file);
        createTextWindow($mw, $file)->pack(
            -in => $tab, -expand => 1, -fill => 'both');
    }
}
$mw->Label(-text => 'Drag tabs between panes, to a pane edge, or outside the window.')->pack;
$mw->IDElayout(
    -widgets => \%widgets,
    -frameStructure => {
        nodes => [
            {name => 'P1', type => 'panedWindow', dir => 'V',
             childOrder => ['Tab1', 'Tab2'], expandfactors => [1, 1]},
            {name => 'Tab1', type => 'widget'},
            {name => 'Tab2', type => 'widget'},
        ],
        edges => [['P1', 'Tab1'], ['P1', 'Tab2']],
    },
)->pack(-expand => 1, -fill => 'both');
MainLoop;
