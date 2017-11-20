#!/bin/sh

autoreconf -f -i
exit $?

echo -n "Libtoolize..."
libtoolize --force --copy
echo "Done."
echo -n "Aclocal..."
aclocal
echo "Done."
echo -n "Autoheader..."
autoheader
echo "Done."
echo -n "Automake..."
automake --add-missing --copy
echo "Done."
echo -n "Autoconf..."
autoconf
echo "Done."
#./configure $*
echo "Now you can do ./configure, make, make install."
