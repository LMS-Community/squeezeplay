## Makefile.am -- Process this file with automake to produce Makefile.in


# Check lua syntax
#dcs check_lua:
#	@rm -f badsyntax
#	@find . -name "*.lua" -and \( -exec luac -p '{}' \; -or -print \) > badsyntax
#	@test \! -s badsyntax
#	@rm -f badsyntax


AM_CFLAGS = -Wall -Werror -D_GNU_SOURCE

lib_LTLIBRARIES = jiveBSP.la jiveWireless.la jiveWatchdog.la

#jiveBSP_la_DEPENDENCIES = check_lua
jiveBSP_la_LDFLAGS = -module -no-version
jiveBSP_la_SOURCES = \
	src/jive_bsp.c

jiveWireless_la_LDFLAGS = -module -no-version
jiveWireless_la_SOURCES = \
	src/jive_wireless.c \
	src/wpa_ctrl.c

jiveWatchdog_la_LDFLAGS = -module -no-version
jiveWatchdog_la_SOURCES = \
	src/jive_watchdog.c

jive_netdir = $(datadir)/jive/jive/net
dist_jive_net_DATA = \
	share/jive/net/Wireless.lua

applets_squeezeboxjivedir = $(datadir)/jive/applets/SqueezeboxJive
dist_applets_squeezeboxjive_DATA = \
	share/applets/SqueezeboxJive/SqueezeboxJiveApplet.lua \
	share/applets/SqueezeboxJive/SqueezeboxJiveMeta.lua \
	share/applets/SqueezeboxJive/strings.txt


applets_setupWirelessdir = $(datadir)/jive/applets/SetupWireless
dist_applets_setupWireless_DATA = \
	share/applets/SetupWireless/SetupWirelessApplet.lua \
	share/applets/SetupWireless/SetupWirelessMeta.lua \
	share/applets/SetupWireless/strings.txt


applets_setupSetupFirmwareUpgradedir = $(datadir)/jive/applets/SetupFirmwareUpgrade
dist_applets_setupSetupFirmwareUpgrade_DATA = \
	share/applets/SetupFirmwareUpgrade/SetupFirmwareUpgradeApplet.lua \
	share/applets/SetupFirmwareUpgrade/SetupFirmwareUpgradeMeta.lua \
	share/applets/SetupFirmwareUpgrade/Upgrade.lua \
	share/applets/SetupFirmwareUpgrade/strings.txt


applets_aboutJivedir = $(datadir)/jive/applets/AboutJive
dist_applets_aboutJive_DATA = \
	share/applets/AboutJive/AboutJiveApplet.lua \
	share/applets/AboutJive/AboutJiveMeta.lua \
	share/applets/AboutJive/strings.txt


applets_testMotiondir = $(datadir)/jive/applets/TestMotion
dist_applets_testMotion_DATA = \
	share/applets/TestMotion/TestMotionApplet.lua \
	share/applets/TestMotion/TestMotionMeta.lua \
	share/applets/TestMotion/strings.txt


applets_testDisplaydir = $(datadir)/jive/applets/TestDisplay
dist_applets_testDisplay_DATA = \
	share/applets/TestDisplay/TestDisplayApplet.lua \
	share/applets/TestDisplay/TestDisplayMeta.lua \
	share/applets/TestDisplay/strings.txt \ 
	share/applets/TestDisplay/circle.jpg


applets_testKeypaddir = $(datadir)/jive/applets/TestKeypad
dist_applets_testKeypad_DATA = \
	share/applets/TestKeypad/TestKeypadApplet.lua \
	share/applets/TestKeypad/TestKeypadMeta.lua \
	share/applets/TestKeypad/strings.txt \
	share/applets/TestKeypad/Keypad.png


applets_testIRdir = $(datadir)/jive/applets/TestIR
dist_applets_testIR_DATA = \
	share/applets/TestIR/TestIRApplet.lua \
	share/applets/TestIR/TestIRMeta.lua \
	share/applets/TestIR/strings.txt \
	share/applets/TestIR/TestIR.png


applets_setupSqueezeboxdir = $(datadir)/jive/applets/SetupSqueezebox
dist_applets_setupSqueezebox_DATA = \
	share/applets/SetupSqueezebox/SetupSqueezeboxApplet.lua \
	share/applets/SetupSqueezebox/SetupSqueezeboxMeta.lua \
	share/applets/SetupSqueezebox/udap.lua \
	share/applets/SetupSqueezebox/strings.txt


applets_SetupFactoryResetdir = $(datadir)/jive/applets/SetupFactoryReset
dist_applets_SetupFactoryReset_DATA = \
	share/applets/SetupFactoryReset/SetupFactoryResetApplet.lua \
	share/applets/SetupFactoryReset/SetupFactoryResetMeta.lua \
	share/applets/SetupFactoryReset/strings.txt


applets_SetupSSHdir = $(datadir)/jive/applets/SetupSSH
dist_applets_SetupSSH_DATA = \
	share/applets/SetupSSH/SetupSSHApplet.lua \
	share/applets/SetupSSH/SetupSSHMeta.lua \
	share/applets/SetupSSH/strings.txt


applets_SetupWelcomedir = $(datadir)/jive/applets/SetupWelcome
dist_applets_SetupWelcome_DATA = \
	share/applets/SetupWelcome/SetupWelcomeApplet.lua \
	share/applets/SetupWelcome/SetupWelcomeMeta.lua \
	share/applets/SetupWelcome/strings.txt
