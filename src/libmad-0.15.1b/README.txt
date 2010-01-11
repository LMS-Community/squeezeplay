Due to licensing concerns, libmad is no longer included in the SqueezePlay repository. 
On windows, you will need to download it manually as described below: 


Platform notes:

*Windows:
To compile Squeezeplay with libmad, download libmad-0.15.1b from:
ftp://ftp.mars.org/pub/mpeg/libmad-0.15.1b.tar.gz

Unzip it under squeezeplay/src/generated, so that you have the following:
squeezeplay/src/generated/libmad-0.15.1b/

Copy squeezeplay\src\generated\libmad-0.15.1b\msvc++\config.h to
squeezeplay\src\generated\libmad-0.15.1b\config.h

Then the Visual Studio build should work successfully.



*Mac OS X:
Makefile.osx will automatically download and patch (for universal binary support) libmad when needed. No manual 