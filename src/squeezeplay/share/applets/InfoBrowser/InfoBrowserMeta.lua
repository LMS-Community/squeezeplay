
--[[

Info Browser Meta

--]]


local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local jiveMain      = jiveMain

local jnt           = jnt

module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 1, 1
end


function registerApplet(meta)
	jnt:subscribe(meta)
	meta.menu = meta:menuItem('appletInfoBrowser', 'extras', meta:string('INFOBROWSER'), function(applet, ...) applet:menu(...) end, 10)
end


-- only show on the menu if a player is attached
-- this allows SN to use the player id to select which information feeds to show
function notify_playerCurrent(meta, player)
	if player == nil then
		jiveMain:removeItem(meta.menu)
	else
		jiveMain:addItem(meta.menu)
	end
end
