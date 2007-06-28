
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
local setmetatable, tostring = setmetatable, tostring

local io                     = require("io")
local oo                     = require("loop.simple")
local string                 = require("string")
local table                  = require("jive.utils.table")

local Applet                 = require("jive.Applet")
local Checkbox               = require("jive.ui.Checkbox")
local Choice                 = require("jive.ui.Choice")
local Framework              = require("jive.ui.Framework")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local Popup                  = require("jive.ui.Popup")
local RadioButton            = require("jive.ui.RadioButton")
local RadioGroup             = require("jive.ui.RadioGroup")
local SimpleMenu             = require("jive.ui.SimpleMenu")
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
				text = "Choice", 
				icon = Choice(
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
				text = "RadioButton 1", 
				icon = RadioButton(
					"radio", 
					group, 
					function()
						log:info("radio button 1 selected")
					end,
					true
				),
			},
			{
				text = "RadioButton 2", 
				icon = RadioButton(
					"radio", 
					group, 
					function()
						log:info("radio button 2 selected")
					end
				),
			},
			{
				text = "RadioButton 3", 
				icon = RadioButton(
					"radio", 
					group, 
					function()
						log:info("radio button 3 selected")
					end
				),
			},
			{
				text = "Checkbox", 
				icon = Checkbox(
					"checkbox",
					function(object, isSelected)
						log:info("checkbox updated: " .. tostring(isSelected))
					end,
					true
				)
			},
			{ text = "Menu",
				callback = function(event, menuItem)
					self:menuWindow(menuItem):show()
				end },
			{ text = "Text UTF8",
				callback = function(event, menuItem)
					self:textWindow(menuItem, "applets/Test/test.txt"):show()
				end },
			{ text = "Slider",
				callback = function(event, menuItem)
					self:sliderWindow(menuItem):show()
				end },
			{ text = "Text input",
				callback = function(event, menuItem)
					self:textinputWindow(menuItem):show()
				end },
			{ text = "Hex input",
				callback = function(event, menuItem)
					self:hexinputWindow(menuItem):show()
				end },
			{ text = "Popup",
				callback = function(event, menuItem)
					self:popupWindow(menuItem):show()
				end },
			{ text = "Image JPG",
				callback = function(event, menuItem)
					self:imageWindow(menuItem, "applets/Test/test.jpg"):show()
				end },
			{ text = "Image PNG",
				callback = function(event, menuItem)
					self:imageWindow(menuItem, "applets/Test/test.png"):show()
				end },
			{ text = "Image GIF",
				callback = function(event, menuItem)
					self:imageWindow(menuItem, "applets/Test/test.gif"):show()
				end },
		})

	local window = Window(self:displayName(), menuItem.text)
	window:addWidget(menu)

	return window
end


function menuWindow(self, menuItem)
	local window = Window(self:displayName(), menuItem.text)
	local menu = SimpleMenu("menu")
	window:addWidget(menu)

	local items = {}
	for i=1,2000 do
		items[#items + 1] = { text = "Artist " .. i }
	end

	menu:setItems(items)

	return window
end


function textWindow(self, menuItem, filename)

	local window = Window(self:displayName(), menuItem.text)

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

	local window = Window(self:displayName(), menuItem.text)

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

	local window = Window(self:displayName(), menuItem.text)

	local input = Textinput("textinput", "A test string",
				function(_, value)
					if #value < 4 then
						return false
					end

					log:warn("Input " .. value)
					window:hide(Window.transitionPushLeft)
					return true
				end)

	local help = Textarea("help", "A basic text input widget. Graphical improvements will come later.")

	window:addWidget(help)
	window:addWidget(input)

	return window
end


function hexinputWindow(self, menuItem)

	-- create an object to hold the hex value. the methods are used
	-- by the text input widget.
	local v = {}
	setmetatable(v, {
			     __tostring =
				     function(e)
					     return table.concat(e, " ")
				     end,

			     __index = {
				     setValue =
					     function(value, str)
						     local i = 1
						     for dd in string.gmatch(str, "%x%x") do
							     value[i] = dd
							     i = i + 1
						     end
						     
					     end,

				     getValue =
					     function(value)
						     return table.concat(value)
					     end,

				     getChars = 
					     function(value, cursor)
						     return "0123456789ABCDEF"
					     end,

				     isEntered =
					     function(value, cursor)
						     return cursor == (#value * 3) - 1
					     end
			     }
		     })

	-- set the initial value
	v:setValue("000000000000")

	local window = Window(self:displayName(), menuItem.text)

	local input = Textinput("textinput", v,
				function(_, value)
					log:warn("Input " .. value:getValue())
					window:hide(Window.transitionPushLeft)
					return true
				end)

	local help = Textarea("help", "Input of HEX numbers.")

	window:addWidget(help)
	window:addWidget(input)

	return window
end


function popupWindow(self, menuItem)

	local popup = Popup("popup", menuItem.text)

	local text = Textarea("textarea", "This is a popup window.\n\nPressing any button should close this window.")
	popup:addWidget(text)

	return popup
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
	local sw,sh = Framework:getScreenSize()
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

