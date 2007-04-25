
--[[
=head1 NAME

applets.Test.TestApplet - User Interface Tests

=head1 DESCRIPTION

This applets is used to test and demonstrate the jive.ui.* stuff.

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 
TestApplet overrides the following methods:

=cut
--]]


-- stuff we use
local tostring = tostring

local io                     = require("io")
local oo                     = require("loop.simple")

local Applet                 = require("jive.Applet")
local Checkbox               = require("jive.ui.Checkbox")
local Choice                 = require("jive.ui.Choice")
local Framework              = require("jive.ui.Framework")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local Menu                   = require("jive.ui.Menu")
local RadioButton            = require("jive.ui.RadioButton")
local RadioGroup             = require("jive.ui.RadioGroup")
local Surface                = require("jive.ui.Surface")
local Textarea               = require("jive.ui.Textarea")
local Window                 = require("jive.ui.Window")

local log                    = require("jive.utils.log").addCategory("test", jive.utils.log.DEBUG)

local EVENT_KEY_PRESS        = jive.ui.EVENT_KEY_PRESS
local EVENT_CONSUME          = jive.ui.EVENT_CONSUME


module(...)
oo.class(_M, Applet)


--[[

=head2 applets.Test.TestApplet:displayName()

Overridden to return the string "Test Applet".

=cut
--]]
function displayName(self)
	return "Test Applet"
end


function menu(self, menuItem)

	local group = RadioGroup()

	-- Menu
	return (Window:newMenuWindow(self:displayName(), menuItem:getValue(),
		{
			{ 
				"Choice", 
				Choice(
						"choice", 
						{ "Off", "Low", "Medium", "High" },
						function(obj, selectedIndex)
							log:info(
								"Choice updated: ", 
								tostring(selectedIndex), 
								" - ",
								tostring(obj:getSelected())
							)
						end	
					)
			},
			{
				"RadioButton 1", 
				RadioButton(
					"radio", 
					group, 
					function()
						log:info("radio button 1 selected")
					end,
					true
				),
			},
			{
				"RadioButton 2", 
				RadioButton(
					"radio", 
					group, 
					function()
						log:info("radio button 2 selected")
					end
				),
			},
			{
				"RadioButton 3", 
				RadioButton(
					"radio", 
					group, 
					function()
						log:info("radio button 3 selected")
					end
				),
			},
			{
				"Checkbox", 
				Checkbox(
					"checkbox",
					function(object, isSelected)
						log:info("checkbox updated: " .. tostring(isSelected))
					end,
					true
				)
			},
			{ "Menu", nil,
				function(event, menuItem)
					self:menuWindow(menuItem):show()
					return EVENT_CONSUME
				end },
			{ "Text UTF8", nil,
				function(event, menuItem)
					self:textWindow(menuItem, "applets/Test/test.txt"):show()
					return EVENT_CONSUME
				end },
			{ "Image JPG", nil,
				function(event, menuItem)
					self:imageWindow(menuItem, "applets/Test/test.jpg"):show()
					return EVENT_CONSUME
				end },
			{ "Image PNG", nil,
				function(event, menuItem)
					self:imageWindow(menuItem, "applets/Test/test.png"):show()
					return EVENT_CONSUME
				end },
			{ "Image GIF", nil,
				function(event, menuItem)
					self:imageWindow(menuItem, "applets/Test/test.gif"):show()
					return EVENT_CONSUME
				end },
		}))
end


function menuWindow(self, menuItem)

	local window = Window(self:displayName(), menuItem:getValue())

	local menu = Menu("menu")
	for i=1,100 do
		local item = Label("label", "Artist " .. i)
		menu:addItem(item)
	end
	window:addWidget(menu)

	return window
end


function textWindow(self, menuItem, filename)

	local window = Window(self:displayName(), menuItem:getValue())

	filename = Framework:findFile(filename)
	local fh = io.open(filename, "rb")
	if fh == nil then
		-- FIXME error dialog
		window:addWidget(Textarea("textarea", "Cannot load text " .. filename))
		return window
	end

	local text = fh:read("*all")
	fh:close()

	local textarea = Textarea("textarea", text)

	window:addWidget(textarea)

	return window
end


function imageWindow(self, menuItem, filename)

	local window = Window(self:displayName())

	local image = Surface:loadImage(filename)
	if image == nil then
		-- FIXME error dialog
		window:addWidget(Textarea("textarea", "Cannot load image " .. filename))
		return window
	end

	-- size the image to fit the window
	local sw,sh = window:getSize()
	local w,h = image:getSize()
	if w > sw or h > sh then
		local fw = sw / w
		local fh = sh / h
		if fw > fh then
			image = image:zoom(fh, fh)
		else
			image = image:zoom(fw, fw)
		end
	end
	log:debug("w = " .. w .. " h = " .. h)
	
	window:addWidget(Icon("image", image))
	window:addListener(EVENT_KEY_PRESS,
		function(event)
			window:hide()
			return EVENT_CONSUME
		end
	)

	return window
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

