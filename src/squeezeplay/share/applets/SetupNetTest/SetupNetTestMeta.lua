
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

function registerApplet(self)
	jnt:subscribe(self)
	self.menu = self:menuItem('appletSetupNetTest', 'hidden', self:string("SETUPNETTEST"), function(applet, ...) applet:open(...) end, 100)
	-- to begin with, we place this in the 'hidden' node
	jiveMain:addItem(self.menu)
end

function notify_serverConnected(self, server)
	self:_checkServer()
end

function notify_serverDisconnected(self, server)
	self:_checkServer()
end

function _checkServer(self)
	for _, server in appletManager:callService("iterateSqueezeCenters") do
		if server:isConnected() and not server:isSqueezeNetwork() then
			-- found a local server - show menu entry
			jiveMain:setCustomNode('appletSetupNetTest', 'advancedSettings')
			return
		end
	end
	-- hide menu entry
	jiveMain:removeItemFromNode(self.menu, 'advancedSettings')
end
