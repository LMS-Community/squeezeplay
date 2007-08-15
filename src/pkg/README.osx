Building on OS X
================

This was tested on 10.4 PPC, using gcc 3.3.
Also on 10.4 Intel, using gcc 4.0.1

The gcc default is 4. Check it with
$ sudo gcc_select

To change the version of gcc used, do
$ sudo gcc_select 3.3

To build in ../../build-osx:
$ make -f Makefile.osx


## Requirements:

* Developer tools (Xcode, at least version 2.4.1, from http://www.apple.com/developer)
* Libraries (see below for list)
* MacPorts (to install the libs) (http://www.macports.org/)
* Subversion (to checkout the Jive code)
	* you can install subversion via MacPorts with
		$ sudo port install subversion
	 (will also install apr, ncurses, readline, sqlite, apr_util, openssl, and neon)
	* alternatively, you can go to http://downloads.open.collab.net/binaries.html and install subversion via an OSX binary
* Checkout the Jive code with
	$ svn co http://svn.slimdevices.com/repos/jive/trunk
	or, for developers that want to do checkins (auth required)
	$ svn co https://svn.slimdevices.com/repos/jive/trunk

## Libraries:

* tiff
* libpng
* jpeg
* expat
* gettext

Once darwin ports is installed, do to install each lib:
$ sudo port install tiff libpng jpeg expat gettext

## OSXLIBS

This is set in Makefile.osx to /opt/local, the MacPorts default. Change
it to /sw if you prefer Fink.
