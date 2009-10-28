#!/bin/sh
#
# Build Universal binaries on Mac OS X, thanks Ryan!
#
# Usage: ./configure CC="sh gcc-fat.sh" && make && rm -rf ppc x86
# PowerPC compiler flags (10.3 runtime compatibility)

# Intel compiler flags (10.5 runtime compatibility)
GCC_COMPILE_X86="gcc-4.0 -arch i386 -mmacosx-version-min=10.5 \
-DMAC_OS_X_VERSION_MIN_REQUIRED=1050 \
-nostdinc \
-F/Developer/SDKs/MacOSX10.5.sdk/System/Library/Frameworks \
-I/Developer/SDKs/MacOSX10.5.sdk/usr/lib/gcc/i686-apple-darwin10/4.2.1/include \
-isystem /Developer/SDKs/MacOSX10.5.sdk/usr/include"

GCC_LINK_X86="\
-L/Developer/SDKs/MacOSX10.5.sdk/usr/lib/gcc/i686-apple-darwin10/4.2.1 \
-Wl,-syslibroot,/Developer/SDKs/MacOSX10.5.sdk"

GCC_COMPILE_X86_64="gcc-4.0 -arch x86_64 -mmacosx-version-min=10.5 \
-DMAC_OS_X_VERSION_MIN_REQUIRED=1050 \
-nostdinc \
-F/Developer/SDKs/MacOSX10.5.sdk/System/Library/Frameworks \
-I/Developer/SDKs/MacOSX10.5.sdk/usr/lib/gcc/i686-apple-darwin10/4.2.1/include \
-isystem /Developer/SDKs/MacOSX10.5.sdk/usr/include"

GCC_LINK_X86_64="\
-L/Developer/SDKs/MacOSX10.5.sdk/usr/lib/gcc/i686-apple-darwin10/4.2.1 \
-Wl,-syslibroot,/Developer/SDKs/MacOSX10.5.sdk"

# Output both PowerPC and Intel object files
args="$*"
compile=yes
link=yes
while test x$1 != x; do
    case $1 in
        --version) exec gcc $1;;
        -v) exec gcc $1;;
        -V) exec gcc $1;;
        -print-prog-name=*) exec gcc $1;;
        -print-search-dirs) exec gcc $1;;
        -E) GCC_COMPILE_X86_64="$GCC_COMPILE_X86_64 -E"
            GCC_COMPILE_X86="$GCC_COMPILE_X86 -E"
            compile=no; link=no;;
        -c) link=no;;
        -o) output=$2;;
        *.c|*.cc|*.cpp|*.S) source=$1;;
    esac
    shift
done
if test x$link = xyes; then
    GCC_COMPILE_X86_64="$GCC_COMPILE_X86_64 $GCC_LINK_X86_64"
    GCC_COMPILE_X86="$GCC_COMPILE_X86 $GCC_LINK_X86"
fi
if test x"$output" = x; then
    if test x$link = xyes; then
        output=a.out
    elif test x$compile = xyes; then
        output=`echo $source | sed -e 's|.*/||' -e 's|\(.*\)\.[^\.]*|\1|'`.o
    fi
fi

if test x"$output" != x; then
    dir=x86_64/`dirname $output`
    if test -d $dir; then
        :
    else
        mkdir -p $dir
    fi
fi
set -- $args
while test x$1 != x; do
    if test -f "x86_64/$1" && test "$1" != "$output"; then
        x86_64_args="$x86_64_args x86_64/$1"
    else
        x86_64_args="$x86_64_args $1"
    fi
    shift
done

#echo "X86_64\n" 
#echo $GCC_COMPILE_X86_64 $x86_64_args 

$GCC_COMPILE_X86_64 $x86_64_args || exit $?
if test x"$output" != x; then
    cp $output x86_64/$output
fi

if test x"$output" != x; then
    dir=x86/`dirname $output`
    if test -d $dir; then
        :
    else
        mkdir -p $dir
    fi
fi
set -- $args
while test x$1 != x; do
    if test -f "x86/$1" && test "$1" != "$output"; then
        x86_args="$x86_args x86/$1"
    else
        x86_args="$x86_args $1"
    fi
    shift
done

#echo "X86\n"
#echo $GCC_COMPILE_X86 $x86_args

$GCC_COMPILE_X86 $x86_args || exit $?
if test x"$output" != x; then
    cp $output x86/$output
fi

if test x"$output" != x; then
    lipo -create -o $output x86_64/$output x86/$output
fi
