local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")
local jul           = require("jive.utils.log")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 0.1, 0.1
end

function defaultSettings(self)
	return {
		clocktype = "analog:simple",
		digital_italic = true,
		digitalsimple_preset = "White",
		digitalstyled_preset = "White"
	}
end

function registerApplet(self)

	-- Bounce implements a screensaver
	local ssMgr = appletManager:loadApplet("ScreenSavers")
	if ssMgr ~= nil then
		ssMgr:addScreenSaver(
			self:string("SCREENSAVER_CLOCK"), 
			"Clock", 
			"openScreensaver",
			self:string("SCREENSAVER_CLOCK_SETTINGS"), 
			"openSettings"
		)

		jiveMain:loadSkin("Clock", "skin")
	end
end

