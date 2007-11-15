
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
local setmetatable, tonumber, tostring = setmetatable, tonumber, tostring

local io                     = require("io")
local oo                     = require("loop.simple")
local math                   = require("math")
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
local Timer                  = require("jive.ui.Timer")

local log                    = require("jive.utils.log").addCategory("test", jive.utils.log.DEBUG)

local EVENT_KEY_PRESS        = jive.ui.EVENT_KEY_PRESS
local EVENT_CONSUME          = jive.ui.EVENT_CONSUME


module(...)
oo.class(_M, Applet)


function menu(self, menuItem)

	log:info("menu")

	local group = RadioGroup()

	-- Menu	
	local menu = SimpleMenu("menu",
		{
			{ text = "Text input",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:textinputWindow(menuItem)
				end
			},
			{ 
				text = "Choice, and some more text so that this item scrolls.", 
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
				text = "RadioButton 1, and some more text so that this item scrolls", 
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
						log:info("checkbox updated: ", isSelected)
					end,
					true
				)
			},
			{ text = "Menu",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:menuWindow(menuItem)
				end },
			{ text = "Sorted Menu",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:sortedMenuWindow(menuItem)
				end },
			{ text = "Text UTF8",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:textWindow(menuItem, "applets/Test/test.txt")
				end },
			{ text = "Connecting Popup",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:connectingPopup(menuItem)
				end },
			{ text = "Slider",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:sliderWindow(menuItem)
				end },
			{ text = "Hex input",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:hexinputWindow(menuItem)
				end },
			{ text = "Time input",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:timeinputWindow(menuItem)
				end },
			{ text = "IP input",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:ipinputWindow(menuItem)
				end },
			{ text = "Image JPG",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
						   local t = Timer(0, function()
									      log:warn("timer fired")
									      self:imageWindow(menuItem, "applets/Test/test.jpg")
								      end, true)
						   t:start()
				end },
			{ text = "Image PNG",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:imageWindow(menuItem, "applets/Test/test.png")
				end },
			{ text = "Image GIF",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:imageWindow(menuItem, "applets/Test/test.gif")
				end },
		})

	local window = Window("window", "This is a really long title to test the bounding box")
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function sortedMenuWindow(self, menuItem)
	local window = Window("window", menuItem.text)
	local menu = SimpleMenu("menu")
	menu:setComparator(menu.itemComparatorAlpha)

	local item = { text = "United States" }
	menu:addItem(item)
	menu:setSelectedItem(item)

	menu:addItem({ text = "Australia" })
	menu:addItem({ text = "France" })
	menu:addItem({ text = "Japan" })
	menu:addItem({ text = "Taiwan" })
	menu:addItem({ text = "Europe" })
	menu:addItem({ text = "Canada" })
	menu:addItem({ text = "China" })


	local interval = 1000
	local foo = Timer(interval,
			  function(self)
				  interval = interval + 1000
				  log:warn("self=", self, " interval=", interval)
				  self:setInterval(interval)
			  end)
	foo:start()

	window:addWidget(menu)
	self:tieAndShowWindow(window)
	return window
end


function menuWindow(self, menuItem)
	local window = Window("window", menuItem.text)
	local menu = SimpleMenu("menu")
	window:addWidget(menu)

	local items = {}
	for i=1,2000 do
		items[#items + 1] = { text = "Artist " .. i }
	end

	menu:setItems(items)

	self:tieAndShowWindow(window)
	return window
end


function textWindow(self, menuItem, filename)

	local window = Window("window", menuItem.text)

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

	self:tieAndShowWindow(window)
	return window
end


function sliderWindow(self, menuItem)

	local window = Window("window", menuItem.text)

	local slider = Slider("slider", 1, 20, 5,
		function(slider, value, done)
			log:warn("slider value is ", value, " ", done)

			if done then
				window:playSound("WINDOWSHOW")
				window:hide(Window.transitionPushLeft)
			end
		end)

	local help = Textarea("help", "We can add some help text here.\n\nThis screen is for testing the slider.")

	window:addWidget(help)
	window:addWidget(slider)

	self:tieAndShowWindow(window)
	return window
end


function textinputWindow(self, menuItem)

	local window = Window("window", menuItem.text)

--	local v = Textinput.textValue("A test string which is so long it goes past the end of the window", 8)
	local v = Textinput.textValue("", 8, 10)
	local input = Textinput("textinput", v,
				function(_, value)
					log:warn("Input ", value)
					window:hide(Window.transitionPushLeft)
					return true
				end)

	window:addWidget(Textarea("softHelp", "A basic text input widget. Graphical improvements will come later."))
	window:addWidget(Label("softButton1", "Insert"))
	window:addWidget(Label("softButton2", "Delete"))

	window:addWidget(input)

	self:tieAndShowWindow(window)
	return window
end


function timeinputWindow(self, menuItem)
	local window = Window("window", menuItem.text)

	local v = Textinput.timeValue("00:00")
	local input = Textinput("textinput", v,
				function(_, value)
					log:warn("Input " .. value:getValue())
					window:hide(Window.transitionPushLeft)
					return true
				end)

	local help = Textarea("help", "Input of Time (24h)")

	window:addWidget(help)
	window:addWidget(input)

	self:tieAndShowWindow(window)
	return window
end

function hexinputWindow(self, menuItem)
	local window = Window("window", menuItem.text)

	local v = Textinput.hexValue("000000000000")
	local input = Textinput("textinput", v,
				function(_, value)
					log:warn("Input " .. value:getValue())
					window:hide(Window.transitionPushLeft)
					return true
				end)

	local help = Textarea("help", "Input of HEX numbers.")

	window:addWidget(help)
	window:addWidget(input)

	self:tieAndShowWindow(window)
	return window
end


function ipinputWindow(self, menuItem)
	local window = Window("window", menuItem.text)

	local v = Textinput.ipAddressValue("0.0.0.0")
	local input = Textinput("textinput", v,
				function(_, value)
					log:warn("Input " .. value:getValue())
					window:hide(Window.transitionPushLeft)
					return true
				end)

	local help = Textarea("help", "Input of IP addresses.")

	window:addWidget(help)
	window:addWidget(input)

	self:tieAndShowWindow(window)
	return window
end


function connectingPopup(self, menuItem)

	local popup = Popup("popupIcon")

	local icon = Icon("iconConnecting")
	local label = Label("text", "")

	popup:addWidget(icon)
	popup:addWidget(label)


	local state = 1
	popup:addTimer(4000, function()
				       if state == 1 then
					       label:setValue("\na long test string!")
				       elseif state == 2 then
					       label:setValue("\na very very very long test string!")
				       elseif state == 3 then
					       icon:setStyle("iconConnected")
					       label:setValue("Connected to\na test string!")
				       else
					       popup:hide()
				       end
				       state = state + 1
			       end)

	self:tieAndShowWindow(popup)
	return popup
end


function imageWindow(self, menuItem, filename)

	local window = Window("window")

	local image = Surface:loadImage(filename)
	if image == nil then
		-- FIXME error dialog
		window:addWidget(Textarea("textarea", "Cannot load image " .. filename))
		return window
	end

	-- size the image to fit the window
	local sw,sh = Framework:getScreenSize()
	log:warn("window size ", sw, " ", sh)
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

	self:tieAndShowWindow(window)
	return window
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

