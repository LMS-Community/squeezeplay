--[[

UI Experiments applet

--]]


local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")
local System        = require("jive.System")
local debug               = require("jive.utils.debug")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)

local _supportedMachines = {
	["fab4"] = 1,
	["squeezeplay"] = 1,
}

function jiveVersion(meta)
	return 1, 1
end


function registerApplet(meta)
--	jiveMain:addItem(meta:menuItem('uiExperiments', 'home', "UI Experiments", function(applet, ...) applet:menu(...) end, .5))
	if _supportedMachines[System:getMachine()] then
		jiveMain:addItem(meta:menuItem('uiExperiments', 'advancedSettingsBetaFeatures', "UI Experiments", function(applet, ...) applet:menu(...) end, 100))
	end

end


--[[

=head1 LICENSE

This source code is public domain. It is intended for you to use as a starting
point to create your own applet.

=cut
--]]
