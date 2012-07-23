
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

	-- add the item to 'hidden' or playerCurrent notification below will never be called
	meta.menu = meta:menuItem('appletInfoBrowser', 'hidden', meta:string('INFOBROWSER'), function(applet, ...) applet:menu(...) end, 10)
	jiveMain:addItem(meta.menu)

end

function notify_playerDelete(meta, player)
	jiveMain:removeItemFromNode(meta.menu, 'extras')
end

-- only show on the menu if a player is attached
-- this allows SN to use the player id to select which information feeds to show
function notify_playerCurrent(meta, player)
	if player == nil then
		jiveMain:removeItemFromNode(meta.menu, 'extras')
	else
		jiveMain:setCustomNode('appletInfoBrowser', 'extras')
	end
end
