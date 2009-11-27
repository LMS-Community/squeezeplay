
local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")
local System        = require("jive.System")

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
	if _supportedMachines[System:getMachine()] then
		jiveMain:addItem(meta:menuItem('SpectrumMeterTest', 'advancedSettingsBetaFeatures', "TEST_SPECTRUMMETER", function(applet, ...) applet:SpectrumMeterTest(...) end, _, { noCustom = 1 }))
	end
end


--[[

=head1 LICENSE

Copyright 2009 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

