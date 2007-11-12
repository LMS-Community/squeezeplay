local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")
local jul           = require("jive.utils.log")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 1, 1
end

function defaultSettings(self)
	return {
		digitalsimple_preset = "White",
		digitalstyled_preset = "White"
	}
end

function registerApplet(self)

	-- Bounce implements a screensaver
	local ssMgr = appletManager:loadApplet("ScreenSavers")
	if ssMgr ~= nil then
		ssMgr:addScreenSaver(
			self:string("SCREENSAVER_CLOCK_STYLE_ANALOG"), 
			"Clock", 
			"openAnalogClock", _, _, 20
		)

		ssMgr:addScreenSaver(
			self:string("SCREENSAVER_CLOCK_STYLE_DIGITALSTYLED"), 
			"Clock", 
			"openStyledClock", _, _, 24
		)

		ssMgr:addScreenSaver(
			self:string("SCREENSAVER_CLOCK_STYLE_DIGITALDETAILED"), 
			"Clock", 
			"openDetailedClock", _, _, 26
		)

		jiveMain:loadSkin("Clock", "skin")
	end
end

