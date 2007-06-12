
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
local SimpleMenu             = require("jive.ui.SimpleMenu")
local RadioButton            = require("jive.ui.RadioButton")
local RadioGroup             = require("jive.ui.RadioGroup")
local Slider                 = require("jive.ui.Slider")
local Surface                = require("jive.ui.Surface")
local Textarea               = require("jive.ui.Textarea")
local Textinput              = require("jive.ui.Textinput")
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

	log:info("menu")

	local group = RadioGroup()

	-- Menu	
	local menu = SimpleMenu("menu",
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
				end },
			{ "Text UTF8", nil,
				function(event, menuItem)
					self:textWindow(menuItem, "applets/Test/test.txt"):show()
				end },
			{ "Slider", nil,
				function(event, menuItem)
					self:sliderWindow(menuItem):show()
				end },
			{ "Text input", nil,
				function(event, menuItem)
					self:textinputWindow(menuItem):show()
				end },
			{ "Image JPG", nil,
				function(event, menuItem)
					self:imageWindow(menuItem, "applets/Test/test.jpg"):show()
				end },
			{ "Image PNG", nil,
				function(event, menuItem)
					self:imageWindow(menuItem, "applets/Test/test.png"):show()
				end },
			{ "Image GIF", nil,
				function(event, menuItem)
					self:imageWindow(menuItem, "applets/Test/test.gif"):show()
				end },
		})

	local window = Window(self:displayName(), menuItem[1])
	window:addWidget(menu)

	return window
end


function menuWindow(self, menuItem)
	local window = Window(self:displayName(), menuItem[1])
	local menu = SimpleMenu("menu")
	window:addWidget(menu)

	local items = {}
	for i=1,2000 do
		items[#items + 1] = { "Artist " .. i }
	end

	menu:setItems(items)

	return window
end


function textWindow(self, menuItem, filename)

	local window = Window(self:displayName(), menuItem[1])

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


function sliderWindow(self, menuItem)

	local window = Window(self:displayName(), menuItem[1])

	local slider = Slider("slider", 1, 20, 5,
		function(slider, value)
			log:warn("slider value is " .. value)
		end)

	local help = Textarea("help", "We can add some help text here.\n\nThis screen is for testing the slider.")

	window:addWidget(help)
	window:addWidget(slider)

	return window
end


function textinputWindow(self, menuItem)

	local window = Window(self:displayName(), menuItem[1])

	local input = Textinput("textinput", "A test string",
				function(_, value)
					log:warn("Input " .. value)
					window:hide(Window.transitionPushLeft)
				end)

	local help = Textarea("help", "A basic text input widget. Graphical improvements will come later.")

	window:addWidget(help)
	window:addWidget(input)

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
	log:warn("window size " .. tostring(sw) .. " " .. tostring(sh))
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

