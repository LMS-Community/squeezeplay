
--[[

Info Browser Meta

--]]


local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 1, 1
end


function registerApplet(meta)
	jiveMain:addItem(
		meta:menuItem('appletInfoBrowser', 'extras', meta:string('INFOBROWSER'), function(applet, ...) applet:menu(...) end, 10)
	)
end
