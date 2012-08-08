
--[[
=head1 NAME

applets.SetupLanguage.SetupLanguageMeta - SetupLanguage meta-info

=head1 DESCRIPTION

See L<applets.SetupLanguage.SetupLanguageApplet>.

=head1 FUNCTIONS

See L<jive.AppletMeta> for a description of standard applet meta functions.

=cut
--]]


local oo            = require("loop.simple")
local locale	    = require("jive.utils.locale")

local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function defaultSettings(meta)
	return {
		[ "locale" ] = "EN"
	}
end


function registerApplet(meta)
	local currentLanguage = meta:getSettings().locale

	if currentLanguage == "RU" then
		currentLanguage = "EN"
		meta:getSettings().locale = currentLanguage
		meta:storeSettings()
	end

	-- set the current locale from the applet settings
	locale:setLocale(currentLanguage)
	meta:registerService("setupShowSetupLanguage")

	-- add ourselves to the main menu
	-- setupLanguage is the function that gets called from SetupLanguageApplet.lua when the menu item is selected
	jiveMain:addItem(meta:menuItem('appletSetupLanguage', 'settings', "LANGUAGE", function(applet, ...) applet:settingsShow(...) end, 50, nil, 'hm_settingsLanguage'))
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
