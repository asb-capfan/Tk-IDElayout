use 5.008;
use Cwd;
use Config;
use File::Find;
no  lib '.';
use ExtUtils::MakeMaker;
BEGIN {

    warn("### Note: 'Building Outside of Tk itself' Messages are Expected Here ####\n");

    $IsWin32 = ($^O eq 'MSWin32' || $Config{'ccflags'} =~ /-D_?WIN32_?/);

    $VERSION = '0.37_02';
    $win_arch = shift @ARGV if @ARGV and $ARGV[0] =~ /^(open32|pm|x|MSWin32)$/;
    require('fix_4_os2.pl'), OS2_massage() if $^O eq 'os2';

    # Currently 'x', 'pm', 'open32', 'MSWin32'
    $win_arch = ($IsWin32) ? 'MSWin32' : 'x' if not defined $win_arch;

    require './myConfig';

  # use lib ($Tk::MMutil::dir=getcwd);

} # /BEGIN

use Tk::MMutil;

# Path to the installed shared Tk library (needed on unix)
my $TkLibPath = ' ';

if ($IsWin32) {
    *MY::makeaperl = \&makeWin32perl;
    if ($Config{cc} =~ /^gcc/i) {
        @libs = ('');
    }
} else {
    # We need to link in the Tk Library on Unix (unless it is a Darwin/macOS
    # Mach-O bundle not meant for linking) to get TkpWmSetState and other symbols
    #    (These are exported in the TkintplatdeclsVptr in windows, but not on unix)
    $TkLibPath = Tk::MMutil::findINC('auto/Tk/Tk.'.$Config{dlext});
    if ($^O eq 'darwin') {
        # Check for MH_BUNDLE header fields (based on `struct mach_header` and
        # `struct mach_header_64` from <mach-o/loader.h>):
        #    - magic    (uint32_t at bytes 0 to 4)
        #    - filetype (uint32_t at bytes 12 to 15)
        my $MH_MAGIC    = 0xfeedface;
        my $MH_CIGAM    = 0xcefaedfe;
        my $MH_MAGIC_64 = 0xfeedfacf;
        my $MH_CIGAM_64 = 0xcffaedfe;
        my $MH_BUNDLE   = 0x8;
        open my $TkLibFH, '<:raw', $TkLibPath;
        my $header_size = read $TkLibFH, my $header, 16;
        die "Couldn't read header of $TkLibPath" unless $header_size == 16;
        close $TkLibFH;
        my ($magic, $filetype) = unpack('L x8 L', $header);
        #printf("Got magic == 0x\%x, filetype == 0x\%x\n", $magic, $filetype);
        $TkLibPath = ' ' if (
            ($magic == $MH_MAGIC or
             $magic == $MH_CIGAM or
             $magic == $MH_MAGIC_64 or
             $magic == $MH_CIGAM_64)
            and ($filetype == $MH_BUNDLE));
    }

    my $plibs = $Config{'libs'};
    my $libs  = "$xlib -lX11";   # Used to have -lpt in here as well.
    my @try   = qw(-lsocket -lnsl -lm);
    push(@try,'-lc') if $^O eq 'svr4';
    my $lib;
    # perl needs sockets and math library too
    # so only include these if they made it through perl's Configure
    foreach $lib (@try) {
        $libs .= " $lib" if ($plibs =~ /$lib\b/);
    }
    @libs = ("$libs");
}

my $dir = Tk::MMutil::find_subdir();
delete $dir->{'pTk'};

# Find path to existing pTk include files
my $ptkPath = Tk::MMutil::findINC('Tk/pTk/Lang.h');
$ptkPath =~ s/\/Lang\.h$//g;



my %pm;
find(sub {
    return unless /\.pm$/;
    my $source = $File::Find::name;
    (my $target = $source) =~ s{^lib/}{};
    $pm{$source} = '$(INST_LIB)/' . $target;
}, 'lib');

Tk::MMutil::TkExtMakefile(
    'VERSION'  => $VERSION,
    'XS_VERSION' => $VERSION,
    'MIN_PERL_VERSION' => '5.008',
    'EXE_FILES' => [],
    'PM' => \%pm,
    'XS' => { 'src/CaptureRelease.xs' => 'src/CaptureRelease.c' },
    'clean' => { FILES => 'CaptureRelease_def.old CaptureRelease.c CaptureRelease.xsc src/CaptureRelease.xsc' },
    'depend' => { 'CaptureRelease$(OBJ_EXT)' => 'src/WmCaptureRelease.h' },
    'NAME'     => 'Tk::CaptureRelease',
    'LICENSE'  => 'perl_5',
    'META_MERGE' => {
        'meta-spec' => { version => 2 },
        no_index => {
            'package' => [ 'Tk', 'Tk::CaptureRelease' ],
        },
        resources => {
            repository => {
                type => 'git',
                url => 'https://github.com/asb-capfan/Tk-IDElayout.git',
                web => 'https://github.com/asb-capfan/Tk-IDElayout',
            },
            bugtracker => {
                web => 'https://github.com/asb-capfan/Tk-IDElayout/issues',
            },
        },
    },
    'DIR'      => [reverse(sort(keys %$dir))],
    'DISTNAME' => "Tk-IDElayout",
    'DEFINE'   => $mydefine,
    'INC'    => "-I$ptkPath -Isrc",
    'LIBS'    => \@libs,
    'OBJECT'  => 'CaptureRelease$(OBJ_EXT) WmCaptureRelease$(OBJ_EXT)'. " $TkLibPath", # Tk Lib path will be the Tk library on Unix, blank for win32
    'CONFIGURE_REQUIRES' => {
        'ExtUtils::MakeMaker' => '6.52',
        'Tk::MMutil' => 0,
    },
    'PREREQ_PM' => {
        'Tk' => '804.027',
        'Tk::DynaTabFrame' => '0.23',
        'Graph' => '0.50',
    },
    @macro,
);


sub needs_Test {
    my $file = shift;
    local $_;
    unless (open(TFILE,"$file")) {
        warn "Cannot open $file:$!";
        return 1;
    }
    my $code = 0;
    while (<TFILE>) {
        last if ($code = /^\s*(use|require)\s+Test\b/);
    }
    close(TFILE);
    warn "Skipping test $file needs 'Test.pm':$_" if $code;
    return $code;
}

sub MY::test {
    my ($self,%attrib) = @_;
    my @tests = sort glob($self->catfile('t','*.t'));
    eval { require Test };
    if ($@) {
        @tests = grep(!needs_Test($_),@tests);
    }
    $attrib{'TESTS'} = join(' ',@tests);

    # Temporarily remove sub-dirs from $self as we 'know'
    # there are no tests down there
    my $dir  = delete $self->{'DIR'};
    my $str  = $self->MM::test(%attrib);
    # Put sub-dirs back
    $self->{'DIR'} = $dir;
    return $str;
}

sub MY::postamble {
    '


CaptureRelease$(OBJ_EXT) : src/CaptureRelease.c src/WmCaptureRelease.h
	$(CCCMD) $(CCCDLFLAGS) "-I$(PERL_INC)" $(PASTHRU_DEFINE) $(DEFINE) $(GCCOPT) src/CaptureRelease.c

src/CaptureRelease.c : src/CaptureRelease.xs $(XSUBPPDEPS)
	$(XSUBPPRUN) $(XSPROTOARG) $(XSUBPPARGS) $(XSUBPP_EXTRA_ARGS) src/CaptureRelease.xs > src/CaptureRelease.xsc
	$(MV) src/CaptureRelease.xsc src/CaptureRelease.c

WmCaptureRelease$(OBJ_EXT) : src/WmCaptureRelease.c src/WmCaptureRelease.h
	$(CCCMD) $(CCCDLFLAGS) "-I$(PERL_INC)" $(PASTHRU_DEFINE) $(DEFINE) $(GCCOPT) src/WmCaptureRelease.c

Makefile     : myConfig

perlmain.c : config Makefile

basic      : $(INST_DYNAMIC) pm_to_blib

MANIFEST : MANIFEST.SKIP $(FIRST_MAKEFILE)
	$(MAKE) manifest

';
}
