
local print = print

-- board specific driver
local fab4_bsp               = require("fab4_bsp")

local oo                     = require("loop.simple")

local Framework              = require("jive.ui.Framework")

local debug                  = require("jive.utils.debug")
local log                    = require("jive.utils.log").logger("applets.setup")


module(..., Framework.constants)
oo.class(_M, Applet)


function init(self)
	 log:warn("FAB4 INIT")

	 Framework:addListener(EVENT_MOUSE_ALL,
		function(event)
			--log:warn(event:tostring())
			print(event:tostring())
		end)
end
