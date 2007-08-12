
--[[
=head1 NAME

jive.AppletMeta - The applet meta base class.

=head1 DESCRIPTION

This is a base class for the applet meta, a small class that is
loaded at boot to perform (a) versioning verification and (b)
hook the applet into the menu system or whatever so that it can 
be accessed and loaded on demand.

=head1 FUNCTIONS

=cut
--]]


local oo = require("loop.base")

local appletManager = appletManager

module(..., oo.class)


--[[

=head2 self:jiveVersion()

Should return the min and max version of Jive supported by the applet.
Jive does not load applets incompatible with itself. Required.

=cut
--]]
function jiveVersion(self)
	error("jiveVersion() required")
end


--[[

=head2 self:registerApplet()

Should register the applet as a screensaver, or add it to a menu,
or otherwise do something that makes the applet accessible or useful.
If the meta determines the applet cannot run in the current environment,
it should simply not register the applet in anything. Required.

=cut
--]]
function registerApplet(self)
	error("registerApplet() required")
end


--[[

=head2 self:defaultSettings()

Returns a table with the default settings for this applet, or nil
if not settings are used.

=cut
--]]
function defaultSettings(self)
	return nil
end


--[[

=head2 self:getSettings()

Returns the settings for this applet.

=cut
--]]
function getSettings(self)
	return self._settings
end


--[[

=head2 self:menuItem(label, closure)

Convience method that returns a MenuItem to be used in the SimpleMenu
to open an applet. I<label> is a localized string token, and closure
is the function executed when the MenuItem is selected. 

=cut
--]]
function menuItem(self, label, closure)
	return {
		text = self:string(label),
		callback = function(event, menuItem)
				local applet = appletManager:loadApplet(self._entry.appletName)
				closure(applet, menuItem)
			   end
	}
end


function string(self, token, ...)
	return self._stringsTable:str(token, ...)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

