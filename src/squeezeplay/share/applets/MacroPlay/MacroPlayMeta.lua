
--[[
=head1 NAME

applets.AutoFWUpdate.AutoFWUpdateMeta - AutoFWUpdate meta-info

=head1 DESCRIPTION

See L<applets.AutoFWUpdate.AutoFWUpdateApplet>.

=head1 FUNCTIONS

See L<jive.AppletMeta> for a description of standard applet meta functions.

=cut
--]]


local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local Timer         = require("jive.ui.Timer")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function defaultSettings(meta)
end


function registerApplet(meta)
	local applet = appletManager:loadApplet('MacroPlay')

	if not applet.config.macros then
		appletManager:freeApplet('MacroPlay')
		return
	end

	if applet.config.auto then
		applet:autoplayShow()
	end

	if applet.config.autorun then
		applet:autorun()
	end

	-- menu item to start
	jiveMain:addItem(meta:menuItem('macroPlay', 'home', 'MACRO_PLAY', function(applet, ...) applet:settingsShow(...) end))
end
