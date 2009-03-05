local pairs         = pairs
local oo            = require("loop.simple")
local AppletMeta    = require("jive.AppletMeta")
local log           = require("jive.utils.log").addCategory("customizeHome", jive.utils.log.DEBUG)

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 1, 1
end

function defaultSettings(self)
        return {
        }
end

function registerApplet(self)

	-- register custom nodes for ids stored in settings.lua in a HomeMenu table customNodes
	local currentSettings = self:getSettings()
	for id, node in pairs(currentSettings) do
		jiveMain:setCustomNode(id, node)
	end

	jiveMain:addItem(self:menuItem('appletCustomizeHome', 'settings', "CUSTOMIZE_HOME", function(applet, ...) applet:menu(...) end))

	jiveMain:addItem(self:menuItem('appletCustomizeHome', 'home', "APP_GUIDE", function(applet, ...) applet:appGuide(...) end))

end
