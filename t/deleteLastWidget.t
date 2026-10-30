use strict;
use warnings;
use Test::More;
use Graph::Directed;
use FindBin;
require "$FindBin::Bin/../IDElayout.pm";

{
    package LayoutProbe;
    our @ISA = ('Tk::IDElayout');
    sub cget { $_[0]{$_[1]} }
    sub Subwidget { $_[0]{mainPW} }
    sub adjustGeom { $_[0]{resized}++ }
    sub DESTROY {}
}
{
    package WidgetProbe;
    sub new { bless {}, shift }
    sub forget { $_[0]{forgotten} = $_[1] }
    sub packForget { $_[0]{unpacked}++ }
    sub pack { $_[0]{packed}++ }
}

for my $resize (0, 1) {
    my $graph = Graph::Directed->new;
    $graph->add_edge('P1', $_) for qw(Tab1 Tab2);
    $graph->set_vertex_attribute('P1', 'attr', {childOrder => ['Tab1', 'Tab2']});
    my %widgets = map {$_ => WidgetProbe->new} qw(P1 Tab1 Tab2);
    my ($first, $last) = @widgets{qw(Tab1 Tab2)};
    my $layout = bless {
        '-frameGraph' => $graph, '-widgets' => \%widgets,
        '-ResizeOnReconfig' => $resize, mainPW => WidgetProbe->new,
    }, 'LayoutProbe';

    is($layout->deleteWidget('Tab1'), $first, 'remove first container');
    is_deeply([ $graph->vertices ], ['Tab2'], 'remaining container becomes root');
    ok($last->{packed}, 'remaining container is packed directly');
    is($layout->deleteWidget('Tab2'), $last, 'remove last container without error');
    ok($last->{unpacked}, 'last container is unpacked');
    is_deeply([ $graph->vertices ], [], 'graph is empty');
    is_deeply(\%widgets, {}, 'widget registry is empty');
    is($layout->{resized} || 0, 2 * $resize, 'resize option is respected');
    eval { $layout->deleteWidget('Tab2') };
    like($@, qr/Can't find PanedWindow/, 'duplicate removal still reports an error');
}
done_testing;
