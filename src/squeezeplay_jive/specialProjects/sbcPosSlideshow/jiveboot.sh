#!/bin/sh

rm -rf /usr/share/jive/applets/Slideshow
cp -rf /mnt/mmc/Slideshow /usr/share/jive/applets/.
cp -rf /mnt/mmc/popImages /usr/share/jive/applets/Slideshow/images
cp -f /mnt/mmc/screenSettings.lua /usr/share/jive/applets/SqueezeboxJive/settings.lua
cp -f /mnt/mmc/setupWelcomeSettings.lua /usr/share/jive/applets/SetupWelcome/settings.lua
cp -f /mnt/mmc/screensaverSettings.lua /usr/share/jive/applets/ScreenSavers/settings.lua
cp -f /mnt/mmc/SqueezeboxJiveApplet.lua /usr/share/jive/applets/SqueezeboxJive/SqueezeboxJiveApplet.lua

