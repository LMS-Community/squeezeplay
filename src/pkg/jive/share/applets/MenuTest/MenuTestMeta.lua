
--[[

MenuTest

--]]


local oo            = require("loop.simple")

local jiveMain      = jiveMain
local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 1, 1
end


function registerApplet(meta)
	local extrasMenu = jiveMain:subMenu(meta:string('EXTRAS'), 500)

	extrasMenu:addItem(meta:menuItem("Menu Test", function(applet, ...) applet:menu(...) end), 900)
end

