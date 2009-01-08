#!/bin/sh

# from 7.1 forward, squeezeos-boot.sh is the boot script name

# if an old Slideshow still exists in /usr/share, get rid of it
if [ -d /usr/share/jive/applets/Slideshow]; then
rm -rf /usr/share/jive/applets/Slideshow
fi

# copy Slideshow applet to squeezeplay subdir
cp -rf /media/*/Slideshow /usr/share/jive/applets/.
# copy popImages to images directory
cp -rf /media/*/popImages /usr/share/jive/applets/Slideshow/images

# make sure some default settings in core applets are set how we want them
cp -f /media/*/screenSettings.lua /usr/share/jive/applets/SqueezeboxJive/settings.lua
cp -f /media/*/setupWelcomeSettings.lua /usr/share/jive/applets/SetupWelcome/settings.lua
cp -f /media/*/screensaverSettings.lua /usr/share/jive/applets/ScreenSavers/settings.lua

# FIXME: copy a hacked SqueezeboxJiveApplet until code is in SlideshowApplet to remove the home key = power off listener through a service
cp -f /media/*/SqueezeboxJiveApplet.lua /usr/share/jive/applets/SqueezeboxJive/SqueezeboxJiveApplet.lua

