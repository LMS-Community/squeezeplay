local _assert, pairs, string, tostring, type, math = _assert, pairs, string, tostring, type, math
local getmetatable = getmetatable

local oo                     = require("loop.base")
local Timer                  = require("jive.ui.Timer")

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


local BUFFER_DISTANCE = 30

local HOLD_TIMEOUT = 1000

module(...)
oo.class(_M, oo.class)


function __init(self, widget, action, holdAction)
	_assert(widget)

	--A mouse sequence is a full down,activity,up sequence - false during down,activity and true on up
	widget.mouseSequenceComplete = true

	-- holdAction will be called if the mouse is down and not dragged for HOLD_TIMEOUT millis.
	if holdAction then
		widget.holdTimer = Timer(HOLD_TIMEOUT,
			function ()
				widget:setStyleModifier(nil)
				widget:reDraw()

				widget.mouseSequenceComplete = true
				holdAction()
			end,
			true)
	end

	widget:addListener(EVENT_MOUSE_ALL,
		function(event)
			local type = event:getType()

			if type == EVENT_MOUSE_DOWN then
				--uncomment when pressed changes are merged
				widget:setStyleModifier("pressed")
				if widget.holdTimer then
					widget.holdTimer:restart()
				end
				widget.mouseSequenceComplete = false

				widget:reDraw()
				return EVENT_CONSUME
			end

			if type == EVENT_MOUSE_UP then
				if widget.holdTimer then
					widget.holdTimer:stop()
				end

				widget:setStyleModifier(nil)
				widget:reDraw()

				if not widget.mouseSequenceComplete then
					widget.mouseSequenceComplete = true
					if mouseInsideBufferDistance(widget, event) then
						if action then
							return action()
						end
					end
				end
				--else nothing (i.e. cancel)
				return EVENT_CONSUME
			end

			if type == EVENT_MOUSE_DRAG then
				--eliminating hold after a drag is similar to typical desktop behavior, plus it's
				 -- very tricky to have hold triggered after a drag, when "hold outside of the bounds" is factored in
				if widget.holdTimer then
					widget.holdTimer:stop()
				end

				if not widget.mouseSequenceComplete then
					if mouseInsideBufferDistance(widget, event) then
						--uncomment when pressed changes are merged
						widget:setStyleModifier("pressed")
						widget:reDraw()
					else
						--dragging outside of buffer distance, change pressed style to normal
						widget:setStyleModifier(nil)
						widget:reDraw()
					end
				end

				return EVENT_CONSUME
			end

			-- press and hold consumed - only ever respond to the up (or hold timer), since they manages the response now

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