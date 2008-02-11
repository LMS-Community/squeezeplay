
--[[
=head1 NAME

jive.ui.Window - The window widget.

=head1 DESCRIPTION

The window widget, extends L<jive.ui.Widget>. This is a container for other widgets on the screen.

=head1 SYNOPSIS

 -- Create a new window with title "Jive" and title style "hometitle"
 local window = jive.ui.Window("window", "Jive", "hometitle")

 -- Show the window on the screen
 window:show()

 -- Hide the window from the screen
 window:hide()


=head1 STYLE

The Window includes the following style parameters in addition to the widgets basic parameters.

=over

B<bgImg> : the windows background image.

=head1 METHODS

=cut
--]]


-- stuff we use
local _assert, ipairs, require, tostring, type, unpack = _assert, ipairs, require, tostring, type, unpack

local math                    = require("math")
local debug                   = require("debug")
local oo                      = require("loop.simple")
local table                   = require("jive.utils.table")
local SimpleMenu              = require("jive.ui.SimpleMenu")
local Group                   = require("jive.ui.Group")
local Label                   = require("jive.ui.Label")
local Icon                    = require("jive.ui.Icon")
local Timer                   = require("jive.ui.Timer")
local Widget                  = require("jive.ui.Widget")
local Event                   = require("jive.ui.Event")
local Surface                 = require("jive.ui.Surface")

local log                     = require("jive.utils.log").logger("ui")

local max                     = math.max
local min                     = math.min

local EVENT_ALL               = jive.ui.EVENT_ALL
local EVENT_ACTION            = jive.ui.EVENT_ACTION
local EVENT_SCROLL            = jive.ui.EVENT_SCROLL
local EVENT_KEY_PRESS         = jive.ui.EVENT_KEY_PRESS
local EVENT_WINDOW_PUSH       = jive.ui.EVENT_WINDOW_PUSH
local EVENT_WINDOW_POP        = jive.ui.EVENT_WINDOW_POP
local EVENT_WINDOW_ACTIVE     = jive.ui.EVENT_WINDOW_ACTIVE
local EVENT_WINDOW_INACTIVE   = jive.ui.EVENT_WINDOW_INACTIVE
local EVENT_FOCUS_LOST        = jive.ui.EVENT_FOCUS_LOST
local EVENT_FOCUS_GAINED      = jive.ui.EVENT_FOCUS_GAINED
local EVENT_SHOW              = jive.ui.EVENT_SHOW
local EVENT_HIDE              = jive.ui.EVENT_HIDE
local EVENT_CONSUME           = jive.ui.EVENT_CONSUME
local EVENT_UNUSED            = jive.ui.EVENT_UNUSED

local FRAME_RATE              = jive.ui.FRAME_RATE
local LAYER_ALL               = jive.ui.LAYER_ALL
local LAYER_CONTENT           = jive.ui.LAYER_CONTENT
local LAYER_CONTENT_OFF_STAGE = jive.ui.LAYER_CONTENT_OFF_STAGE
local LAYER_CONTENT_ON_STAGE  = jive.ui.LAYER_CONTENT_ON_STAGE
local LAYER_FRAME             = jive.ui.LAYER_FRAME

local LAYOUT_NORTH            = jive.ui.LAYOUT_NORTH
local LAYOUT_EAST             = jive.ui.LAYOUT_EAST
local LAYOUT_SOUTH            = jive.ui.LAYOUT_SOUTH
local LAYOUT_WEST             = jive.ui.LAYOUT_WEST
local LAYOUT_CENTER           = jive.ui.LAYOUT_CENTER
local LAYOUT_NONE             = jive.ui.LAYOUT_NONE



-- our class
module(...)
oo.class(_M, Widget)


local Framework = require("jive.ui.Framework")


--[[

=head2 jive.ui.Window(style, title, titleStyle)

Constructs a new window widget. I<style> is the widgets style. The window can have an optional I<title>, and an optional titleStyle I<titleStyle>

=cut
--]]
function __init(self, style, title, titleStyle)
	_assert(type(style) == "string", "style parameter is " .. type(style) .. " expected string - " .. debug.traceback())

	local obj = oo.rawnew(self, Widget(style))

	obj.allowScreensaver = true
	obj.alwaysOnTop = false
	obj.autoHide = false
	obj.showFrameworkWidgets = true
	obj.transparent = false

	obj.widgets = {} -- child widgets
	obj.layoutRoot = true
	obj.focus = nil

	obj._DEFAULT_SHOW_TRANSITION = transitionPushLeft
	obj._DEFAULT_HIDE_TRANSITION = transitionPushRight

	if titleStyle then
		obj:setTitleWidget(Group(titleStyle, { text = Label("text", title), icon = Icon("icon") }))
	elseif title then
		obj:setTitle(title)
	end

	obj:addListener(EVENT_ALL,
			 function(event)
			 	return obj:_eventHandler(event)
			 end)
	
	return obj
end


--[[

=head2 jive.ui.Window:show(transition)

Show this window, adding it to the top of the window stack. The I<transition> is used to move the window on stage.

=cut
--]]
function show(self, transition)
	local stack = Framework.windowStack

	local idx = 1
	local topwindow = stack[idx]
	while topwindow and topwindow.alwaysOnTop do
		idx = idx + 1
		topwindow = stack[idx]
	end

	if topwindow == self then
		-- we're already on top
		return
	end

	-- remove the window if it is already in the stack
	local onstack = table.delete(stack, self)

	if not onstack then
		-- this window is being pushed to the stack
		self:dispatchNewEvent(EVENT_WINDOW_PUSH)
	end

	-- this window is now active
	self:dispatchNewEvent(EVENT_WINDOW_ACTIVE)

	-- this window and it's widgets are now visible
	self:dispatchNewEvent(EVENT_SHOW)

	-- insert the window in the window stack
	table.insert(stack, idx, self)

	if topwindow then
		-- push transitions
		transition = transition or self._DEFAULT_SHOW_TRANSITION
		Framework:_startTransition(_newTransition(transition, topwindow, self))

		if not self.transparent then
			-- the old window and widgets are no longer visible
			topwindow:dispatchNewEvent(EVENT_HIDE)

			-- the old window is inactive
			topwindow:dispatchNewEvent(EVENT_WINDOW_INACTIVE)
		end
	end

	-- hide windows with autoHide enabled
	while stack[idx + 1] ~= nil and stack[idx + 1].autoHide do
		stack[idx + 1]:hide()
	end

	Framework:reDraw(nil)
end


--[[

=head2 jive.ui.Window:showInstead(transition)

Shows this window as a replacement for the window at the top of the window stack. The I<transition> is used to move the window on stage.

=cut
--]]
function showInstead(self, transition)
	local last = Framework.windowStack[1]

	self:show(transition)
	last:hide()
end


--[[

=head2 jive.ui.Window:replace(toReplace, transition)

Replaces toReplace window with a new window object


=cut
--]]

function replace(self, toReplace, transition)
	local topWindow = 1
	for i in ipairs(Framework.windowStack) do
		if Framework.windowStack[i] == toReplace then
			if i == topWindow then
				self:showInstead(transition)
			else
				-- the old window may still be visible under
				-- a transparent window, if so hide it
				local oldwindow = Framework.windowStack[i]
				if oldwindow.visible then
					oldwindow:dispatchNewEvent(EVENT_HIDE)
				end

				Framework.windowStack[i] = self

				-- if the old window was visible, the new one
				-- is now 
				if oldwindow.visible then
					self:dispatchNewEvent(EVENT_SHOW)
				end
			end
		end
	end
end

--[[

=head2 jive.ui.Window:showBriefly(msecs, closure, pushTransition, popTransition)

Shows this window briefly for I<msecs> milliseconds. When the timeout occurs, or a key has been pressed then window is hidden and the I<closure> is called. The I<pushTransition> and I<popTransition> transitions are used to move the window on and off stage.

If the window has already been displayed with showBriefly then the timer is restarted with the new I<msecs> value.

=cut
--]]
function showBriefly(self, msecs, callback,
		     pushTransition,
		     popTransition)

	if self.brieflyTimer ~= nil then
		if msecs then
			self.brieflyTimer:setInterval(msecs)
		else
			self.brieflyTimer:restart()
		end

		return

	elseif msecs == nil then
		return
	end

	if callback then
		self:addListener(EVENT_WINDOW_POP, callback)
	end

	if self.brieflyHandler == nil then
		self.brieflyHandler =
			self:addListener(EVENT_KEY_PRESS | EVENT_SCROLL,
					 function(event)
						 self:hide(popTransition, "NONE")
						 return EVENT_CONSUME
					 end)
	end

	self.brieflyTimer = Timer(msecs,
				  function(timer)
					  self.brieflyTimer = nil
					  self:hide(popTransition, "NONE")
				  end,
				  true)
	self.brieflyTimer:start()

	self:show(pushTransition)
end


--[[

=head2 jive.ui.Window:hide(transition)

Hides this window. It it is currently at the top of the window stack then the I<transition> is used to move the window off stage.

=cut
--]]
function hide(self, transition)
	local stack = Framework.windowStack

	local wasVisible = self.visible

	-- remove the window from window stack
	table.delete(stack, self)

	-- find top window, ignoring always on top windows
	local idx = 1
	local topwindow = stack[idx]
	while topwindow and topwindow.alwaysOnTop do
		idx = idx + 1
		topwindow = stack[idx]
	end

	if wasVisible and topwindow then
		-- top window is now active
		topwindow:dispatchNewEvent(EVENT_WINDOW_ACTIVE)

		-- top window and widgets are now visible
		topwindow:dispatchNewEvent(EVENT_SHOW)
		topwindow:reDraw()

		-- push transitions
		transition = transition or self._DEFAULT_HIDE_TRANSITION
		Framework:_startTransition(_newTransition(transition, self, topwindow))
	end

	if self.visible then
		-- this window and widgets are now not visible
		self:dispatchNewEvent(EVENT_HIDE)

		-- this window is inactive
		self:dispatchNewEvent(EVENT_WINDOW_INACTIVE)
	end

	self:dispatchNewEvent(EVENT_WINDOW_POP)
end


--[[

=head2 jive.ui.Window:hideToTop(transition)

Hide from this window to the top if the window stack.

=cut
--]]
function hideToTop(self, transition)
	local stack = Framework.windowStack

	for i=1,#stack do
		if stack[i] == self then
			for j=i,1,-1 do
				stack[j]:hide(transition)
			end
		end
	end
end


--[[

=head2 jive.ui.Window:autoHide(enabled)

If autoHide is enabled then the window is automatically
hidden when another window is shown above it. This is useful
for hiding popup windows so they do not appear if the user
moves back.

==cut
--]]
function setAutoHide(self, enabled)
	self.autoHide = enabled and true or nil
end


--[[

=head2 jive.ui.Window:bumpLeft()

Makes the window bump left.

=cut
--]]
function bumpLeft(self)
	Framework:_startTransition(self:transitionBumpLeft(self))
end


--[[

=head2 jive.ui.Window:bumpRight()

Makes the window bump right.

=cut
--]]
function bumpRight(self)
	Framework:_startTransition(self:transitionBumpRight(self))
end


--[[

=head2 jive.ui.Window:hideAll()

Hides all windows, removing them from the window stack.

=cut
--]]
function hideAll(self)
	local stack = Framework.windowStack

	-- hide windows in reverse order
	for i=#stack, 1, -1 do
		stack[i]:hide()
	end

	-- FIXME window events
end


--[[

=head2 jive.ui.Window:setTitle(title)

Sets the windows title to I<title>.

=cut
--]]
function setTitle(self, title)
	if self.title then
		self.title:setWidgetValue("text", title)
	else
		self.title = Group("title", { text = Label("text", title), icon = Icon("icon") })
		self:_addWidget(self.title)
		self.title:_event(Event:new(EVENT_FOCUS_GAINED))
	end
end


--[[

=head2 jive.ui.Window:setTitle(style)

Sets the windows title style to I<style>.

=cut
--]]
function setTitleStyle(self, style)
	if self.title then
		self.title:setStyle(style)
	end
end


--[[

=head2 jive.ui.Window:setTitleWidget(titleWidget)

Sets the windows title to I<titleWidget>.

=cut
--]]
function setTitleWidget(self, titleWidget)
	_assert(oo.instanceof(titleWidget, Widget), "setTitleWidget(widget): widget is not an instance of Widget!")

	if self.title then
		self.title:_event(Event:new(EVENT_FOCUS_LOST))
		self:removeWidget(self.title)
	end

	self.title = titleWidget
	self:_addWidget(self.title)
	self.title:_event(Event:new(EVENT_FOCUS_GAINED))
end


--[[

=head2 jive.ui.Window:getWindow()

Returns I<self>.

=cut
--]]
function getWindow(self)
	return self
end


--[[

=head2 jive.ui.Window:lowerWindow(self)

Returns the window beneath this window in the window stack.

=cut
--]]
function getLowerWindow(self)
	for i = 1,#Framework.windowStack do
		if Framework.windowStack[i] == self then
			return Framework.windowStack[i + 1]
		end
	end
	return nil
end


--[[

=head2 jive.ui.Window:addWidget(widget)

Add the widget I<widget> to the window.

=cut
--]]
function addWidget(self, widget)
	_assert(oo.instanceof(widget, Widget), "addWidget(widget): widget is not an instance of Widget!")

	_addWidget(self, widget)

	-- FIXME last widget added always has focus
	self:focusWidget(widget)
end

function _addWidget(self, widget)
	self.widgets[#self.widgets + 1] = widget
	widget.parent = self
	widget:reSkin()

	if self:isVisible() then
		widget:dispatchNewEvent(EVENT_SHOW)
	end
end


--[[

=head2 jive.ui.Window:removeWidget(widget)

Remove the widget I<widget> from the window.

=cut
--]]
function removeWidget(self, widget)
	_assert(oo.instanceof(widget, Widget))

	if self:isVisible() then
		widget:dispatchNewEvent(EVENT_HIDE)
	end

	table.delete(self.widgets, widget)

	self:reLayout()
end


--[[

=head2 jive.ui.Window:focusWidget(widget)

Make the I<widget> have the focus. This widget will be forwarded
events from the window, and should animate (if applicable).

=cut
--]]
function focusWidget(self, widget)
	_assert(widget == nil or oo.instanceof(widget, Widget))
	_assert(widget == nil or table.contains(self.widgets, widget))

	if self.focus and self.focus ~= self.title then
		self.focus:_event(Event:new(EVENT_FOCUS_LOST))
	end

	self.focus = widget
	if self.focus then
		self.focus:_event(Event:new(EVENT_FOCUS_GAINED))
	end
end


function getAllowScreensaver(self)
	return self.allowScreensaver
end


function setAllowScreensaver(self, allowScreensaver)
	_assert(type(allowScreensaver) == "boolean" or type(allowScreensaver) == "function")

	self.allowScreensaver = allowScreensaver
	-- FIXME disable screensaver if active?
end


function canActivateScreensaver(self)
	if self.allowScreensaver == nil then
		return true
	elseif self.allowScreensaver == "function" then
		return self.allowScreensaver()
	else
		return self.allowScreensaver
	end
end


function getAlwaysOnTop(self)
	return self.alwaysOnTop
end


function setAlwaysOnTop(self, alwaysOnTop)
	_assert(type(alwaysOnTop) == "boolean")

	self.alwaysOnTop = alwaysOnTop
	-- FIXME modify window position if already shown?
end


function getShowFrameworkWidgets(self)
	return self.showFrameworkWidgets
end


function setShowFrameworkWidgets(self, showFrameworkWidgets)
	_assert(type(showFrameworkWidgets) == "boolean")

	self.showFrameworkWidgets = showFrameworkWidgets
	self:reLayout()
end


function getTransparent(self)
	return self.transparent
end


function setTransparent(self, transparent)
	_assert(type(transparent) == "boolean")

	self.transparent = transparent
	self:reLayout()
end


function __tostring(self)
	if self.title then
		return "Window(" .. tostring(self.title) .. ")"
	else
		return "Window()"
	end
end


-- Create a new transition. This wrapper is lets transitions to be used
-- underneath transparent windows (e.g. popups)
function _newTransition(transition, oldwindow, newwindow)
	local f = transition(oldwindow, newwindow)
	if not f then
		return f
	end

	local idx = 1
	local windows = {}

	local w = Framework.windowStack[idx]
	while w ~= oldwindow and w ~= newwindow and w.transparent do
		table.insert(windows, 1, w)

		idx = idx + 1
		w = Framework.windowStack[idx]
	end

	if #windows then
		return function(widget, surface)
			       f(widget, surface)

			       for i,w in ipairs(windows) do
				       w:draw(surface, LAYER_CONTENT)
			       end
		       end
	else
		return f
	end
end


--[[

=head2 jive.ui.Window:transitionNone()

Returns an empty window transition. i.e. the window is just displayed without any animations.

=cut
--]]
function transitionNone(self)
	return nil
end


--[[

=head2 jive.ui.Window:transitionBumpLeft()

Returns a bump left window transition.

=cut
--]]
function transitionBumpLeft(self)

	local frames = 2
	local screenWidth = Framework:getScreenSize()

	return function(widget, surface)
			local x = frames * 3

			self:draw(surface, LAYER_FRAME)
			surface:setOffset(x, 0)
			self:draw(surface, LAYER_CONTENT | LAYER_CONTENT_OFF_STAGE | LAYER_CONTENT_ON_STAGE)
			surface:setOffset(0, 0)

			frames = frames - 1
			if frames == 0 then
				Framework:_killTransition()
			end
		end
end


--[[

=head2 jive.ui.Window:transitionBumpRight()

Returns a bump right window transition.

=cut
--]]
function transitionBumpRight(self)

	local frames = 2
	local screenWidth = Framework:getScreenSize()

	return function(widget, surface)
			local x = frames * 3

			self:draw(surface, LAYER_FRAME)
			surface:setOffset(-x, 0)
			self:draw(surface, LAYER_CONTENT | LAYER_CONTENT_OFF_STAGE | LAYER_CONTENT_ON_STAGE)
			surface:setOffset(0, 0)

			frames = frames - 1
			if frames == 0 then
				Framework:_killTransition()
			end
		end
end


--[[

=head2 jive.ui.Window:transitionPushLeft(newWindow)

Returns a push left window transition.

=cut
--]]
function transitionPushLeft(oldWindow, newWindow)
	_assert(oo.instanceof(oldWindow, Widget))
	_assert(oo.instanceof(newWindow, Widget))

	local frames = FRAME_RATE / 2 -- 0.5 sec
	local screenWidth = Framework:getScreenSize()
	local scale = (frames * frames * frames) / screenWidth

	return function(widget, surface)
			local x = screenWidth - ((frames * frames * frames) / scale)

			surface:setOffset(0, 0)
			newWindow:draw(surface, LAYER_FRAME)

			surface:setOffset(-x, 0)
			oldWindow:draw(surface, LAYER_CONTENT | LAYER_CONTENT_OFF_STAGE)

			surface:setOffset(screenWidth - x, 0)
			newWindow:draw(surface, LAYER_CONTENT | LAYER_CONTENT_ON_STAGE)

			surface:setOffset(0, 0)

			frames = frames - 1
			if frames == 0 then
				Framework:_killTransition()
			end
		end
end


--[[

=head2 jive.ui.Window:transitionPushRight(newWindow)

Returns a push right window transition.

=cut
--]]
function transitionPushRight(oldWindow, newWindow)
	_assert(oo.instanceof(oldWindow, Widget))
	_assert(oo.instanceof(newWindow, Widget))

	local frames = FRAME_RATE / 2 -- 0.5 sec
	local screenWidth = Framework:getScreenSize()
	local scale = (frames * frames * frames) / screenWidth

	return function(widget, surface)
			local x = screenWidth - ((frames * frames * frames) / scale)

			surface:setOffset(0, 0)
			newWindow:draw(surface, LAYER_FRAME)

			surface:setOffset(x, 0)
			oldWindow:draw(surface, LAYER_CONTENT | LAYER_CONTENT_OFF_STAGE)

			surface:setOffset(x - screenWidth, 0)
			newWindow:draw(surface, LAYER_CONTENT | LAYER_CONTENT_ON_STAGE)

			surface:setOffset(0, 0)

			frames = frames - 1
			if frames == 0 then
				Framework:_killTransition()
			end
		end
end


--[[

=head2 jive.ui.Window:transitionFadeIn(newWindow)

Returns a fade in window transition.

=cut
--]]
function transitionFadeIn(oldWindow, newWindow)
	_assert(oo.instanceof(oldWindow, Widget))
	_assert(oo.instanceof(newWindow, Widget))

	local frames = FRAME_RATE / 2 -- 0.5 sec
	local scale = 255 / frames

	local bgImage = Framework:getBackground()

	local sw, sh = Framework:getScreenSize()
	local srf = Surface:newRGB(sw, sh)

	-- assume old window is not updating
	bgImage:blit(srf, 0, 0, sw, sh)
	oldWindow:draw(srf, LAYER_ALL)

	return function(widget, surface)
			local x = frames * scale

			newWindow:draw(surface, LAYER_ALL)
			srf:blitAlpha(surface, 0, 0, x)

			frames = frames - 1
			if frames == 0 then
				Framework:_killTransition()
			end
		end
end


--[[

=head2 jive.ui.Window:transitionPushPopupUp(newWindow)

Returns a push up window transition for use with popup windows.

=cut
--]]
function transitionPushPopupUp(oldWindow, newWindow)
	_assert(oo.instanceof(oldWindow, Widget))
	_assert(oo.instanceof(newWindow, Widget))

	local _, screenHeight = Framework:getScreenSize()

	local frames = math.ceil(FRAME_RATE / 6)
	local _,_,_,windowHeight = newWindow:getBounds()
	local scale = (frames * frames * frames) / windowHeight

	return function(widget, surface)
			local y = ((frames * frames * frames) / scale)

			surface:setOffset(0, 0)
			oldWindow:draw(surface, LAYER_ALL)

			surface:setOffset(0, y)
			newWindow:draw(surface, LAYER_CONTENT | LAYER_CONTENT_OFF_STAGE)

			surface:setOffset(0, 0)

			frames = frames - 1
			if frames == 0 then
				Framework:_killTransition()
			end
		end
end


--[[

=head2 jive.ui.Window:transitionPushPopupDown(newWindow)

Returns a push down window transition for use with popup windows.

=cut
--]]
function transitionPushPopupDown(oldWindow, newWindow)
	_assert(oo.instanceof(oldWindow, Widget))
	_assert(oo.instanceof(newWindow, Widget))

	local _, screenHeight = Framework:getScreenSize()

	local frames = math.ceil(FRAME_RATE / 6)
	local _,_,_,windowHeight = oldWindow:getBounds()
	local scale = (frames * frames * frames) / windowHeight

	return function(widget, surface)
			local y = ((frames * frames * frames) / scale)

			surface:setOffset(0, 0)
			newWindow:draw(surface, LAYER_ALL)

			surface:setOffset(0, windowHeight - y)
			oldWindow:draw(surface, LAYER_CONTENT | LAYER_CONTENT_OFF_STAGE)

			surface:setOffset(0, 0)

			frames = frames - 1
			if frames == 0 then
				Framework:_killTransition()
			end
		end
end


--[[

=head2 jive.ui.Window:noLayout()

Layout function that does not modify the window layout

=cut
--]]
function noLayout(self)
	-- maximum window size is bounded by screen
	local sw, sh = Framework:getScreenSize()

	-- prefered window size set in style
	local _wx, _wy, _ww, _wh = self:getPreferredBounds()
	local wlb,wtb,wrb,wbb = self:getBorder()
	ww = (_ww or sw) - wlb - wrb
	wh = (_wh or sh) - wtb - wbb

	self:setBounds(wx, wy, ww, wh)
end


--[[

=head2 jive.ui.Window:borderLayout(window)

Layout function similar to the Java Border Layout.

=cut
--]]
function borderLayout(self, fitWindow)
	-- maximum window size is bounded by screen
	local sw, sh = Framework:getScreenSize()

	-- prefered window size set in style
	local _wx, _wy, _ww, _wh = self:getPreferredBounds()
	local wlb,wtb,wrb,wbb = self:getBorder()
	ww = (_ww or sw) - wlb - wrb
	wh = (_wh or sh) - wtb - wbb

	-- utility function to limit bounds to window size
	local maxBounds = function(x, y, w, h)
				  w = min(ww, w)
				  h = min(wh, h)
				  return x, y, w, h
			  end

	-- find prefered widget sizes
	local maxN, maxE, maxS, maxW, maxX, maxY = 0, 0, 0, 0, 0, 0
	self:iterate(
		function(widget)
			local x,y,w,h = widget:getPreferredBounds()
			local lb,tb,rb,bb = widget:getBorder()
			local position = widget:styleInt("position") or LAYOUT_CENTER

			--log:debug("x=", x, " y=", y, " w=", w, " h=", h)

			if position == LAYOUT_NORTH then
				h = h + tb + bb or tb + bb
				maxN = max(h, maxN)

				if w then
					w = w + lb + rb
					w = min(w, sw - lb - rb)
					maxX = max(w, maxX)
				end

			elseif position == LAYOUT_SOUTH then
				h = h + tb + bb or tb + bb
				maxS = max(h, maxS)

				if w then
					w = w + lb + rb
					w = min(w, sw - lb - rb)
					maxX = max(w, maxX)
				end

			elseif position == LAYOUT_EAST then
				w = w + lb + rb or lb + rb
				w = min(w, sw - lb - rb)
				maxE = max(w, maxE)

			elseif position == LAYOUT_WEST then
				w = w + lb + rb or lb + rb
				w = min(w, sw - lb - rb)
				maxW = max(w, maxW)

			elseif position == LAYOUT_CENTER then
				if w then
					w = w + lb + rb
					w = min(w, sw - lb - rb)
					maxX = max(w, maxX)
				end
				if h then
					h = h + tb + bb
					maxY = max(h, maxY)
				end

			end
		end
	)

	--log:debug(" maxN=", maxN, " maxE=", maxE, " maxS=", maxS, " maxW=", maxW, " maxX=", maxX, " maxY=", maxY)

	-- adjust window bounds to fit content
	if fitWindow then
		if _wh == nil and maxY > 0 then
			wh = wtb + maxN + maxY + maxS + wbb
		end
		if _ww == nil and maxX > 0 then
			ww = wlb + maxE + maxX + maxW + wrb
		end
	end
	wx = (_wx or (sw - ww) / 2)
	wy = (_wy or (sh - wh) / 2)


	-- set widget bounds
	local cy = 0
	self:iterate(
		function(widget)
			local x,y,w,h = widget:getPreferredBounds()
			local lb,tb,rb,bb = widget:getBorder()
			local position = widget:styleInt("position") or LAYOUT_CENTER

			rb = rb + lb
			bb = bb + tb

			if position == LAYOUT_NORTH then
				x = x or 0
				y = y or 0
				widget:setBounds(maxBounds(wx + x + lb, wy + y + tb, ww - rb, h))

			elseif position == LAYOUT_SOUTH then
				x = x or 0
				y = y or (wh - maxS)
				widget:setBounds(maxBounds(wx + x + lb, wy + y + tb, ww - rb, h))

			elseif position == LAYOUT_EAST then
				x = x or (ww - maxE)
				y = y or 0
				widget:setBounds(maxBounds(wx + x + lb, wy + y + tb, w, wh - bb))

			elseif position == LAYOUT_WEST then
				x = x or 0
				y = y or 0
				widget:setBounds(maxBounds(wx + x + lb, wy + y + tb, w, wh - bb))

			elseif position == LAYOUT_CENTER then
				-- FIXME why does w-rb work, but h-bb lays out incorrectly?
				h = h or (wh - maxN - maxS)
				h = min(wh - maxN - maxS, h)
				w = w or (ww - maxW - maxE)
				w = min(ww - maxW - maxE, w) - rb

				widget:setBounds(maxBounds(wx + maxW + lb, wy + maxN + tb + cy, w, h))
				cy = cy + h + bb

			elseif position == LAYOUT_NONE then
				widget:setBounds(maxBounds(wx + x, wy + y, w, h))
			end
		end
	)

	-- set window bounds
	self:setBounds(wx, wy, ww, wh)
end



--[[ C optimized:

jive.ui.Window:pack()
jive.ui.Window:draw()
jive.ui.Window:_eventHandler()

--]]

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

