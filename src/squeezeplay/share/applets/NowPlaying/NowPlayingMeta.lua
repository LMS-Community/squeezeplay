local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 1, 1
end

function defaultSettings(self)
	return {
		scrollText = true,
		scrollTextOnce = false,
	}
end

function registerApplet(self)

	jiveMain:addItem(
		self:menuItem(
			'appletNowPlayingScrollMode', 
			'screenSettingsNowPlaying', 
			'SCREENSAVER_SCROLLMODE', 
			function(applet, ...) 
				applet:settingsShow(...) 
			end
		)
	)
	self:registerService('goNowPlaying')
	self:registerService("hideNowPlaying")

end


function configureApplet(self)

	appletManager:callService("addScreenSaver",
		self:string("SCREENSAVER_NOWPLAYING"), 
		"NowPlaying", 
		"openScreensaver", 
		_,
		_,
		10,
		nil,
		nil,
		nil,
		{"whenOff"}
	)

	-- NowPlaying is a resident applet
	appletManager:loadApplet("NowPlaying")

end

