
--[[
=head1 NAME

applets.SelectSkin.SelectSkinMeta - Select SqueezePlay skin

=head1 DESCRIPTION

See L<applets.SelectSkin.SelectSkinApplet>.

=head1 FUNCTIONS

See L<jive.AppletMeta> for a description of standard applet meta functions.

=cut
--]]


local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function defaultSettings(meta)
	return {}
end


function registerApplet(meta)
	jiveMain:addItem(meta:menuItem('appletSelectSkin', 'screenSettings', 'SELECT_SKIN', function(applet, ...) applet:selectSkinEntryPoint(...) end))
	meta:registerService("getSelectedSkinNameForType")
	
end


function configureApplet(meta)
	if (not meta:getSettings().skin) then
		meta:getSettings().skin = jiveMain:getDefaultSkin()
	end

	local skin = meta:getSettings().skin
	jiveMain:setSelectedSkin(skin)

	local skins = 0
	for s in jiveMain:skinIterator() do
		skins = skins + 1
	end

	if skins <= 1 then
		jiveMain:removeItemById('appletSelectSkin')
	end
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

