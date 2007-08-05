
--[[
=head1 NAME

jive.Applet - The applet base class.

=head1 DESCRIPTION

jive.Applet is the base class for all Jive applets. In Jive,
applets are very flexible in the methods they implement; this
class implements a very simple framework to manage localization,
settings and memory management.

=head1 FUNCTIONS

=cut
--]]


local oo = require("loop.base")

local AppletManager = require("jive.AppletManager")


module(..., oo.class)


--[[

=head2 jive.Applet:init()

Called to initialize the Applet.

In the object __init method the applet settings and localized strings
are not available.

=cut
--]]
function init(self)
end


--[[

=head2 jive.Applet:free()

This is called when the Applet will be freed. It must make sure all
data is unreferenced to allow for garbage collection. The method
should return true if the applet can be freed, or false if it should
be left loaded into memory. The default return value in jive.Applet is
true.

=cut
--]]
function free(self)
	return true
end


--[[

=head2 jive.Applet:setSettings(settings)

Sets the applet settings to I<settings>.

=cut
--]]
function setSettings(self, settings)
	self._settings = settings
end


--[[

=head2 jive.Applet:getSettings()

Returns a table with the applet settings

=cut
--]]
function getSettings(self)
	return self._settings
end


-- storeSettings
-- used by jive.AppletManager to persist the applet settings
function storeSettings(self)
	AppletManager._storeSettings(self._entry)
end


--[[

=head2 jive.Applet:string(token)

Returns a localised version of token

=cut
--]]
function string(self, token, ...)
	return self._stringsTable:str(token, ...)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

