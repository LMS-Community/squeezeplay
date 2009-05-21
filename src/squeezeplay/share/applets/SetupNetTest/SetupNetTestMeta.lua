
--[[

SetupNetTest Meta

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

	meta.menu = meta:menuItem('appletSetupNetTest', 'hidden', meta:string('SETUPNETTEST'), function(applet, ...) applet:open(...) end, 100)
	-- add the menu item to homeMenu but 'hidden', or else the playerCurrent notification method below quits happening (not sure why this is the case, but it is)
	-- item will be made visible by moving it to advancedSettings in the playerCurrent notification below
	jiveMain:addItem(meta.menu)
end

-- hide menu item when player goes away
function notify_playerDelete(meta, player)
	jiveMain:removeItemFromNode(meta.menu, 'advancedSettings')
end

function notify_playerCurrent(meta, player)
	-- don't show this item if the player object: 
	--   a. doesn't exist
	--   b. isn't connected to a server (now possible)
	--   c. connected to SN
	if player == nil or not player:getSlimServer() or ( player:getSlimServer() and player:getSlimServer():isSqueezeNetwork() ) then
		jiveMain:removeItemFromNode(meta.menu, 'advancedSettings')
	else
		jiveMain:setCustomNode('appletSetupNetTest', 'advancedSettings')
	end
end

