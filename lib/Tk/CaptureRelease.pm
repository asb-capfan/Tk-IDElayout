package Tk::CaptureRelease;

use 5.008;

our ($VERSION) = ('0.37_02');

use Tk;
require DynaLoader;

use base  qw(DynaLoader);

bootstrap Tk::CaptureRelease;

package Tk;
use Tk::Submethods ( '_wm' => [qw(capture release)] );
package Tk::CaptureRelease;

{ 
	# Alias our _wmCapture to wmCapture and _wmRelease to wmRelease
	#   This will replace the ones in the stock Tk that are missing (on win32) or dont work (on unix)

	no warnings;  # Warnings are expected here, so we turn them off
	*Tk::Widget::wmRelease = \&Tk::_wmRelease;
	*Tk::Widget::wmCapture = \&Tk::_wmCapture;
}

1;

=head1 NAME

Tk::CaptureRelease - Release Tk frames as tool windows and capture them again

=head1 SYNOPSIS

    use strict;
    use warnings;
    use Tk;
    use Tk::CaptureRelease;

    my $mw = MainWindow->new;
    my $released = 0;
    my $content = $mw->Frame;
    $content->Label(-text => 'This frame can become a separate window')->pack;
    $content->pack(-expand => 1, -fill => 'both');
    $mw->Button(-text => 'Release', -command => sub {
        return if $released;
        $content->packForget;
        $content->wmRelease;
        $content->MainWindow::title('Released frame');
        $content->MainWindow::deiconify;
        $released = 1;
    })->pack;
    $mw->Button(-text => 'Capture', -command => sub {
        return unless $released;
        $content->wmCapture;
        $content->pack(-in => $mw, -expand => 1, -fill => 'both');
        $released = 0;
    })->pack;
    MainLoop;

=head1 DESCRIPTION

Loading this module installs C<wmRelease> and C<wmCapture> methods on
L<Tk::Widget>. The native extension provides the window-management operations
used by L<Tk::IDEtabFrame> to detach and reattach tab contents.

Put the content in a separate L<Tk::Frame> before releasing it. The IDE
widgets use such frames as containers for the actual application widgets.
The extension must be compiled before this module can be loaded.

=head1 METHODS

=head2 wmRelease

    $frame->packForget;
    $frame->wmRelease;
    $frame->MainWindow::deiconify;

Release a frame as a top-level window. Remove its existing geometry management
first. The released object retains its Perl widget class, so the examples
explicitly invoke C<MainWindow> methods for top-level operations.

=head2 wmCapture

    $frame->wmCapture;
    $frame->pack(-in => $parent, -expand => 1, -fill => 'both');

Capture a released frame as a child window again. Reapply geometry management
after capture. These operations do not destroy the frame or its contents.

=head1 SEE ALSO

L<Tk::IDEtabFrame>, L<Tk::IDElayout>, C<eg/capture-release.pl>.

=cut
