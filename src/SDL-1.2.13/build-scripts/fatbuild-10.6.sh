#!/bin/sh
#
# Build a fat binary on Mac OS X, thanks Ryan!
prefix=$PREFIX
# Number of CPUs (for make -j)
NCPU=`sysctl -n hw.ncpu`
NJOB=$NCPU
#NJOB=`expr $NCPU + 1`

# Generic, cross-platform CFLAGS you always want go here.
CFLAGS="-O3 -g -pipe"

# Locate Xcode SDK path
SDK_PATH=/Developer/SDKs
if [ ! -d $SDK_PATH ]; then
    echo "Couldn't find SDK path"
    exit 1
fi

# Intel configure flags (10.4 runtime compatibility)
# We dynamically load X11, so using the system X11 headers is fine.
CONFIG_X86="--build=`uname -p`-apple-darwin --host=i386-apple-darwin \
--x-includes=/usr/X11R6/include --x-libraries=/usr/X11R6/lib"

# Intel compiler flags
CC_X86="gcc-4.2 -arch i386"
CXX_X86="g++-4.2 -arch i386"
CFLAGS_X86="-mmacosx-version-min=10.5"
CPPFLAGS_X86="-DMAC_OS_X_VERSION_MIN_REQUIRED=1050 \
-nostdinc \
-F$SDK_PATH/MacOSX10.5.sdk/System/Library/Frameworks \
-I$SDK_PATH/MacOSX10.5.sdk/usr/lib/gcc/i686-apple-darwin10/4.2.1/include \
-isystem $SDK_PATH/MacOSX10.5.sdk/usr/include"

# Intel linker flags
LFLAGS_X86="-arch i386 -mmacosx-version-min=10.5 \
-L$SDK_PATH/MacOSX10.5.sdk/usr/lib/gcc/i686-apple-darwin10/4.2.1 \
-Wl,-syslibroot,$SDK_PATH/MacOSX10.5.sdk"

CONFIG_X86_64="--build=`uname -p`-apple-darwin --host=i386-apple-darwin \
--x-includes=/usr/X11R6/include --x-libraries=/usr/X11R6/lib"

# Intel compiler flags
CC_X86_64="gcc-4.2 -arch x86_64"
CXX_X86_64="g++-4.2 -arch x86_64"
CFLAGS_X86_64="-mmacosx-version-min=10.5"
CPPFLAGS_X86_64="-DMAC_OS_X_VERSION_MIN_REQUIRED=1050 \
-nostdinc \
-F$SDK_PATH/MacOSX10.5.sdk/System/Library/Frameworks \
-I$SDK_PATH/MacOSX10.5.sdk/usr/lib/gcc/i686-apple-darwin10/4.2.1/include \
-isystem $SDK_PATH/MacOSX10.5.sdk/usr/include"

# Intel linker flags
LFLAGS_X86_64="-arch x86_64 -mmacosx-version-min=10.5 \
-L$SDK_PATH/MacOSX10.5.sdk/usr/lib/gcc/i686-apple-darwin10/4.2.1 \
-Wl,-syslibroot,$SDK_PATH/MacOSX10.5.sdk"

#
# Find the configure script
#
srcdir=`dirname $0`/..
auxdir=$srcdir/build-scripts
cd $srcdir

#
# Figure out which phase to build:
# all,
# configure, configure-x86_64, configure-x86,
# make, make-x86_64, make-x86, merge
# install
# clean
if test x"$1" = x; then
    phase=all
else
    phase="$1"
fi
case $phase in
    all)
        configure_x86_64="yes"
        configure_x86="yes"
        make_x86_64="yes"
        make_x86="yes"
        merge="yes"
        ;;
    configure)
        configure_x86_64="yes"
        configure_x86="yes"
        ;;
    configure-x86_64)
        configure_x86_64="yes"
        ;;
    configure-x86)
        configure_x86="yes"
        ;;
    make)
        make_x86_64="yes"
        make_x86="yes"
        merge="yes"
        ;;
    make-x86_64)
        make_x86_64="yes"
        ;;
    make-x86)
        make_x86="yes"
        ;;
    merge)
        merge="yes"
        ;;
    install)
        install_bin="yes"
        install_hdrs="yes"
        install_lib="yes"
        install_data="yes"
        install_man="yes"
        ;;
    install-bin)
        install_bin="yes"
        ;;
    install-hdrs)
        install_hdrs="yes"
        ;;
    install-lib)
        install_lib="yes"
        ;;
    install-data)
        install_data="yes"
        ;;
    install-man)
        install_man="yes"
        ;;
    clean)
        clean_x86_64="yes"
        clean_x86="yes"
        ;;
    clean-x86_64)
        clean_x86_64="yes"
        ;;
    clean-x86)
        clean_x86="yes"
        ;;
    *)
        echo "Usage: $0 [all|configure[-x86_64|-x86]|make[-x86_64|-x86]|merge|install|clean]"
        exit 1
        ;;
esac
case `uname -p` in
    x86_64)
        native_path=x86_64
        ;;
    *86)
        native_path=x86
        ;;
    *)
        echo "Couldn't figure out native architecture path"
        exit 1
        ;;
esac

#
# Create the build directories
#
for dir in build build/x86_64 build/x86; do
    if test -d $dir; then
        :
    else
        mkdir $dir || exit 1
    fi
done

#
# Build the PowerPC binary
#
if test x$configure_x86_64 = xyes; then
    (cd build/x86_64 && \
     sh ../../configure $CONFIGURE_FLAGS_EXTRA --prefix=$PREFIX $CONFIG_X86_64 CC="$CC_X86_64" CXX="$CXX_X86_64" CFLAGS="$CFLAGS $CFLAGS_X86_64" CPPFLAGS="$CPPFLAGS_X86_64" LDFLAGS="$LFLAGS_X86_64") || exit 2
fi
if test x$make_x86_64 = xyes; then
    (cd build/x86_64 && ls include && make -j$NJOB) || exit 3
fi

#
# Build the Intel binary
#
if test x$configure_x86 = xyes; then
    (cd build/x86 && \
     sh ../../configure $CONFIGURE_FLAGS_EXTRA --prefix=$PREFIX $CONFIG_X86 CC="$CC_X86" CXX="$CXX_X86" CFLAGS="$CFLAGS $CFLAGS_X86" CPPFLAGS="$CPPFLAGS_X86" LDFLAGS="$LFLAGS_X86") || exit 2
fi
if test x$make_x86 = xyes; then
    (cd build/x86 && make -j$NJOB) || exit 3
fi

#
# Combine into fat binary
#
if test x$merge = xyes; then
    output=.libs
    sh $auxdir/mkinstalldirs build/$output
    cd build
    target=`find . -mindepth 3 -type f -name '*.dylib' | head -1 | sed 's|.*/||'`
    (lipo -create -o $output/$target `find . -mindepth 3 -type f -name "*.dylib"` &&
     ln -sf $target $output/libSDL-1.2.0.dylib &&
     ln -sf $target $output/libSDL.dylib &&
     lipo -create -o $output/libSDL.a */build/.libs/libSDL.a &&
     cp $native_path/build/.libs/libSDL.la $output &&
     cp $native_path/build/.libs/libSDL.lai $output &&
     cp $native_path/build/libSDL.la . &&
     lipo -create -o libSDLmain.a */build/libSDLmain.a &&
     echo "Build complete!" &&
     echo "Files can be found in the build directory.") || exit 4
    cd ..
fi

#
# Install
#
do_install()
{
    echo $*
    $* || exit 5
}
if test x$prefix = x; then
    prefix=/usr/local
fi
if test x$exec_prefix = x; then
    exec_prefix=$prefix
fi
if test x$bindir = x; then
    bindir=$exec_prefix/bin
fi
if test x$libdir = x; then
    libdir=$exec_prefix/lib
fi
if test x$includedir = x; then
    includedir=$prefix/include
fi
if test x$datadir = x; then
    datadir=$prefix/share
fi
if test x$mandir = x; then
    mandir=$prefix/man
fi
if test x$install_bin = xyes; then
    do_install sh $auxdir/mkinstalldirs $bindir
    do_install /usr/bin/install -c -m 755 build/$native_path/sdl-config $bindir/sdl-config
fi
if test x$install_hdrs = xyes; then
    do_install sh $auxdir/mkinstalldirs $includedir/SDL
    for src in $srcdir/include/*.h; do \
        file=`echo $src | sed -e 's|^.*/||'`; \
        do_install /usr/bin/install -c -m 644 $src $includedir/SDL/$file; \
    done
    do_install /usr/bin/install -c -m 644 $srcdir/include/SDL_config_macosx.h $includedir/SDL/SDL_config.h
fi
if test x$install_lib = xyes; then
    do_install sh $auxdir/mkinstalldirs $libdir
    do_install sh build/$native_path/libtool --mode=install /usr/bin/install -c  build/libSDL.la $libdir/libSDL.la
    do_install /usr/bin/install -c -m 644 build/libSDLmain.a $libdir/libSDLmain.a
    do_install ranlib $libdir/libSDLmain.a
fi
if test x$install_data = xyes; then
    do_install sh $auxdir/mkinstalldirs $datadir/aclocal
    do_install /usr/bin/install -c -m 644 $srcdir/sdl.m4 $datadir/aclocal/sdl.m4
fi
if test x$install_man = xyes; then
    do_install sh $auxdir/mkinstalldirs $mandir/man3
    for src in $srcdir/docs/man3/*.3; do \
        file=`echo $src | sed -e 's|^.*/||'`; \
        do_install /usr/bin/install -c -m 644 $src $mandir/man3/$file; \
    done
fi

#
# Clean up
#
do_clean()
{
    echo $*
    $* || exit 6
}
if test x$clean_x86 = xyes; then
    do_clean rm -r build/x86
fi
if test x$clean_x86_64 = xyes; then
    do_clean rm -r build/x86_64
fi

