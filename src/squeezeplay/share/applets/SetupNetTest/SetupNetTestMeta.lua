
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

	meta.menu = meta:menuItem('appletSetupNetTest', 'advancedSettings', meta:string('SETUPNETTEST'), function(applet, ...) applet:open(...) end, 100)

	jiveMain:loadSkin("SetupNetTest", "skin")
end


function notify_playerCurrent(meta, player)
	if player == nil or player.slimServer:isSqueezeNetwork() then
		jiveMain:removeItem(meta.menu)
	else
		jiveMain:addItem(meta.menu)
	end
end