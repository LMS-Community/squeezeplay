
--[[
=head1 NAME

applets.KeyLock.KeyLockApplet - Key lock, press Play and Pause to lock the screen

=head1 DESCRIPTION

This applet implements using a key combination to lock the Jive screen.

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 
KeyLockApplet overrides the following methods:

=cut
--]]


-- stuff we use
local oo               = require("loop.simple")

local Applet           = require("jive.Applet")
local Framework        = require("jive.ui.Framework")
local Window           = require("jive.ui.Window")
local Label            = require("jive.ui.Label")


local EVENT_KEY_PRESS  = jive.ui.EVENT_KEY_PRESS
local EVENT_KEY_DOWN   = jive.ui.EVENT_KEY_DOWN
local EVENT_SCROLL     = jive.ui.EVENT_SCROLL
local EVENT_CONSUME    = jive.ui.EVENT_CONSUME
local EVENT_UNUSED     = jive.ui.EVENT_UNUSED
local KEY_PLAY         = jive.ui.KEY_PLAY
local KEY_PAUSE        = jive.ui.KEY_PAUSE


module(...)
oo.class(_M, Applet)


-- FIXME ui framework should perform double key press detection

local function _locked(self)
	if not self.locked then
		if self.window then
			self.window:hide()
			self.window = nil
		end

		return EVENT_UNUSED
	end

	if self.window then
		return EVENT_CONSUME
	end


	-- locked popup
	self.window = Window(self:displayName())

	local label = Label("text", "Locked!")
	self.window:addWidget(label)

	self.window:showBriefly(5000,
		function()
			self.window = nil
		end
	)

	return EVENT_CONSUME
end


local function _keyDown(self, event)
	return _locked(self)
end


local function _keyPress(self, event)
	if event:getKeycode() == (KEY_PLAY | KEY_PAUSE) then
		self.locked = not self.locked
	end

	return _locked(self)
end


local function _scroll(self, event)
	return _locked(self)
end


function __init(self, ...)

	-- init superclass
	local obj = oo.rawnew(self, Applet(...))
	
	obj.locked = false
	
	Framework:addListener(EVENT_KEY_DOWN,
		function(...)
			return _keyDown(obj, ...)
		end
	)
	
	Framework:addListener(EVENT_KEY_PRESS,
		function(...)
			return _keyPress(obj, ...)
		end
	)
	
	Framework:addListener(EVENT_SCROLL,
		function(...)
			return _scroll(obj, ...)
		end
	)
	
	return obj
end


--[[

=head2 applets.KeyLock.KeyLockApplet:free()

Overridden to return always false, this ensure the applet is
permanently loaded.

=cut
--]]
function free(self)
	-- we cannot be unloaded
	return false
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

