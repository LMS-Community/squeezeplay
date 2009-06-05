--[[

Shortcuts applet

--]]


local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")
local Framework     = require("jive.ui.Framework")
local debug               = require("jive.utils.debug")

local appletManager = appletManager
local jiveMain      = jiveMain


module(..., Framework.constants)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end

function defaultSettings(meta)
	return {
		actionActionMappings = {
			["title_left_press"]  = "back",
			["title_left_hold"]  = "go_home",
			["title_right_press"]  = "go_now_playing",
			["title_right_hold"]  = "go_playlist",
		},
		gestureActionMappings = {
			[GESTURE_L_R] = "go_home",
			[GESTURE_R_L] = "go_now_playing",
		},
	}
end


function registerApplet(meta)
	jiveMain:addItem(meta:menuItem('shortcuts', 'screenSettings', "SHORTCUTS_TITLE", function(applet, ...) applet:menu(...) end, 3))

	Framework:applyInputToActionOverrides(meta:getSettings())

end



--[[

=head1 LICENSE

This source code is public domain. It is intended for you to use as a starting
point to create your own applet.

=cut
--]]
