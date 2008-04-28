local _assert, pairs, string, tostring, type = _assert, pairs, string, tostring, type
local getmetatable = getmetatable

local oo                     = require("loop.base")

local debug                  = require("jive.utils.debug")
local log                    = require("jive.utils.log").logger("ui")


local EVENT_MOUSE_ALL        = jive.ui.EVENT_MOUSE_ALL
local EVENT_MOUSE_PRESS      = jive.ui.EVENT_MOUSE_PRESS

local EVENT_CONSUME          = jive.ui.EVENT_CONSUME
local EVENT_UNUSED           = jive.ui.EVENT_UNUSED


module(...)
oo.class(_M, oo.class)


function __init(self, widget, action)
	_assert(widget)

	widget:addListener(EVENT_MOUSE_ALL,
		function(event)
			local type = event:getType()

			if type == EVENT_MOUSE_PRESS then
				return action()
			end

			return EVENT_CONSUME
		end)

	return widget
end
