#!/bin/sh

# note: jiveboot.sh is deprecated in deference to squeezeos-boot.sh from 7.1 forward
rm -rf /usr/share/jive/applets/Slideshow
cp -rf /media/*/Slideshow /usr/share/jive/applets/.
cp -rf /media/*/popImages /usr/share/jive/applets/Slideshow/images
cp -f /media/*/screenSettings.lua /usr/share/jive/applets/SqueezeboxJive/settings.lua
cp -f /media/*/setupWelcomeSettings.lua /usr/share/jive/applets/SetupWelcome/settings.lua
cp -f /media/*/screensaverSettings.lua /usr/share/jive/applets/ScreenSavers/settings.lua
cp -f /media/*/SqueezeboxJiveApplet.lua /usr/share/jive/applets/SqueezeboxJive/SqueezeboxJiveApplet.lua

