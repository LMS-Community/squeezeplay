
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
	local extrasMenu = jiveMain:subMenu(meta:string('EXTRAS'), 500)

	extrasMenu:addItem(meta:menuItem(meta:string('INFOBROWSER'), function(applet, ...) applet:menu(...) end), 900)
end
