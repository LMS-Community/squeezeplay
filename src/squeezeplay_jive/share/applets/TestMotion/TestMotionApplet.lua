
-- stuff we use
local assert, getmetatable, ipairs, pcall, setmetatable, tonumber, tostring = assert, getmetatable, ipairs, pcall, setmetatable, tonumber, tostring

local oo                     = require("loop.simple")

local math                   = require("math")
local string                 = require("string")
local table                  = require("jive.utils.table")
local io                     = require("io")

local Applet                 = require("jive.Applet")
local Framework              = require("jive.ui.Framework")
local Label                  = require("jive.ui.Label")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Slider                 = require("jive.ui.Slider")
local Textarea               = require("jive.ui.Textarea")
local Timer                  = require("jive.ui.Timer")
local Window                 = require("jive.ui.Window")


module(..., Framework.constants)
oo.class(_M, Applet)


function settingsShow(self)
	local window = Window("text_list", self:string("TEST_MOTION"), 'settingstitle')
--"Test Motion")

	self.valX = Slider("slider", 0, 127, 0)
	self.valY = Slider("slider", 0, 127, 0)
	self.valZ = Slider("slider", 0, 127, 0)

	self.maxX = Slider("slider", 0, 127, 0)
	self.maxY = Slider("slider", 0, 127, 0)
	self.maxZ = Slider("slider", 0, 127, 0)

	window:addWidget(Label("text", self:string("TEST_MOTION_VALUE")))
	window:addWidget(self.valX)
	window:addWidget(self.valY)
	window:addWidget(self.valZ)

	window:addWidget(Label("text", self:string("TEST_MOTION_MAX")))
	window:addWidget(self.maxX)
	window:addWidget(self.maxY)
	window:addWidget(self.maxZ)

	window:focusWidget(nil)

	local timer = Timer(1000,
			    function()
				    self.valX:setValue(0)
				    self.valY:setValue(0)
				    self.valZ:setValue(0)
			    end)
	timer:start()

	local mx, my, mz = 0, 0, 0
	window:addListener(EVENT_MOTION,
			   function(event)
				   timer:restart()

				   local x, y, z = event:getMotion()

				   self.valX:setValue(math.abs(x))
				   self.valY:setValue(math.abs(y))
				   self.valZ:setValue(math.abs(z))

				   mx = math.max(mx, math.abs(x))
				   my = math.max(my, math.abs(y))
				   mz = math.max(mz, math.abs(z))

				   self.maxX:setValue(mx)
				   self.maxY:setValue(my)
				   self.maxZ:setValue(mz)
			   end)

	window:addListener(EVENT_KEY_PRESS,
			   function(event)
				   local key = event:getKeycode()
				   if key == KEY_BACK then
					   window:playSound("WINDOWHIDE")
					   window:hide()
				   elseif key == KEY_GO then
					   window:playSound("SELECT")
					   mx, my, mz = 0, 0, 0
					   self.maxX:setValue(mx)
					   self.maxY:setValue(my)
					   self.maxZ:setValue(mz)
				   end
			   end)

	self:tieAndShowWindow(window)
	return window
end



--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
