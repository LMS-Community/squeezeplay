local _assert, pairs, string, tostring, type, math = _assert, pairs, string, tostring, type, math
local getmetatable = getmetatable

local oo                     = require("loop.base")

local debug                  = require("jive.utils.debug")
local log                    = require("jive.utils.log").logger("ui")


local EVENT_MOUSE_ALL        = jive.ui.EVENT_MOUSE_ALL
local EVENT_MOUSE_PRESS      = jive.ui.EVENT_MOUSE_PRESS
local EVENT_MOUSE_DOWN       = jive.ui.EVENT_MOUSE_DOWN
local EVENT_MOUSE_DRAG       = jive.ui.EVENT_MOUSE_DRAG
local EVENT_MOUSE_UP         = jive.ui.EVENT_MOUSE_UP
local EVENT_FOCUS_LOST       = jive.ui.EVENT_FOCUS_LOST

local EVENT_CONSUME          = jive.ui.EVENT_CONSUME
local EVENT_UNUSED           = jive.ui.EVENT_UNUSED


local BUFFER_DISTANCE = 75

module(...)
oo.class(_M, oo.class)


function __init(self, widget, action)
	_assert(widget)

	widget:addListener(EVENT_MOUSE_ALL,
		function(event)
			local type = event:getType()

			if type == EVENT_MOUSE_DOWN then
				--uncomment when pressed changes are merged
--				widget:setStyleModifier("pressed")
				widget:reDraw()
				return EVENT_CONSUME
			end

			if type == EVENT_MOUSE_UP then
				widget:setStyleModifier(nil)
				widget:reDraw()

				if mouseInsideBufferDistance(widget, event) then
					return action()
				end
				--else nothing (i.e. cancel)
				return EVENT_CONSUME
			end

			if type == EVENT_MOUSE_DRAG then

				if mouseInsideBufferDistance(widget, event) then
					--uncomment when pressed changes are merged
--					widget:setStyleModifier("pressed")
					widget:reDraw()
				else
					widget:setStyleModifier(nil)
					widget:reDraw()
				end

				return EVENT_CONSUME
			end

			if type == EVENT_MOUSE_PRESS then
				return action()
			end

			--todo handle hold - will probably need a passed in holdAction or pass back the state to action()

			return EVENT_CONSUME
		end)

	return widget
end


function mouseInsideBufferDistance(widget, event)
	local mouseX, mouseY = event:getMouse()

	local widgetX, widgetY, widgetW, widgetH = widget:getBounds()

	--shortest line distances
	local distanceX, distanceY

	if mouseX < widgetX then
		distanceX = widgetX - mouseX
	elseif mouseX > widgetX + widgetW then
		distanceX =  mouseX - (widgetX + widgetW)
	else
		distanceX = 0
	end

	if mouseY < widgetY then
		distanceY = widgetY - mouseY
	elseif mouseY > widgetY + widgetH then
		distanceY =  mouseY - (widgetY + widgetH)
	else
		distanceY = 0
	end

	if distanceX == 0 and distanceY == 0 then
		--inside mouse bounds
		return true
	end

	--shortest distance to button bounds
	local distance = math.sqrt( math.pow(distanceX ,2) + math.pow(distanceY ,2) )

	return distance < BUFFER_DISTANCE
end