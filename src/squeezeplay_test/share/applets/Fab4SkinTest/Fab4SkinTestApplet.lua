
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
local System                 = require("jive.System")
local Checkbox               = require("jive.ui.Checkbox")
local Choice                 = require("jive.ui.Choice")
local Framework              = require("jive.ui.Framework")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local Popup                  = require("jive.ui.Popup")
local Group                  = require("jive.ui.Group")
local Button                 = require("jive.ui.Button")
local RadioButton            = require("jive.ui.RadioButton")
local RadioGroup             = require("jive.ui.RadioGroup")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Slider                 = require("jive.ui.Slider")
local Surface                = require("jive.ui.Surface")
local Textarea               = require("jive.ui.Textarea")
local Textinput              = require("jive.ui.Textinput")
local Window                 = require("jive.ui.Window")
local Timer                  = require("jive.ui.Timer")
local Keyboard               = require("jive.ui.Keyboard")

local log                    = require("jive.utils.log").addCategory("test", jive.utils.log.DEBUG)
local appletManager = appletManager


module(..., Framework.constants)
oo.class(_M, Applet)


function menu(self, menuItem)

	log:info("menu")

	local group = RadioGroup()

	-- Menu	
	local menu = SimpleMenu("menu",
		{
			{ text = "Connecting Popup",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:connectingPopup(menuItem)
			end 
			},
			{ text = "Wired/Wireless",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:networkChoiceWindow(menuItem)
				end 
			},
			{ text = "Regions",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:regionWindow(menuItem)
				end 
			},
			{ text = "One Button Menu",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:buttonWindow(menuItem, 'onebutton')
				end 
			},
			{ text = "Album Menu",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:albumMenuWindow(menuItem)
				end 
			},
			{ text = "Button Menu",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:menuWindow(menuItem, 'button', 'buttonicon')
				end 
			},
			{ text = "Keyboard UPPERCASE input",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:keyboardWindow(menuItem, 'qwerty')
				end
			},
			{ text = "Keyboard lowercase input",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:keyboardWindow(menuItem, 'qwertyLower')
				end
			},
			{ text = "Keyboard hex input",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:keyboardWindow(menuItem, 'hex')
				end
			},
			{ text = "Keyboard numeric input",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:keyboardWindow(menuItem, 'numeric')
				end
			},
			{ text = "Keyboard special char input",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:keyboardWindow(menuItem, 'chars')
				end
			},
			{ text = "Text input",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:textinputWindow(menuItem)
				end
			},
			{ text = "Timer stress",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:timerTestWindow(menuItem)
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
			{ text = 'Locked Screen Popup',
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:lockedScreen(menuItem)
				end
			},
			{ text = "Downloading Software",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:downloadingSoftware(menuItem)
			end },
			{ text = "'Ignore all Input' Popup",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:ignoreAllInputPopup(menuItem)
				end },
		{ text = "Error",
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:errorWindow(menuItem)
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

	local window = Window("window", "Test") -- is a really long title to test the bounding box")
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

function buttonWindow(self, menuItem, style)
	local window = Window(style, menuItem.text)
	local menu = SimpleMenu('menu')
	window:addWidget(Textarea('text', "Let's begin by getting\nyou connected to your network."))
	window:addWidget(menu)

	local item = { text = "continue", style = 'buttonitem'  }

	menu:addItem(item)

	self:tieAndShowWindow(window)
	return window
end


function regionWindow(self, menuItem)
	local window = Window("button", menuItem.text, 'helptitle')
	local menu = SimpleMenu('menu')
	window:addWidget(menu)

	local item = { text = "North America", style = 'wifiNA'  }
	local item2 = { text = "All Other Regions", style = 'wifiOther'  }

	menu:addItem(item)
	menu:addItem(item2)

	self:tieAndShowWindow(window)
	return window
end


function networkChoiceWindow(self, menuItem)
	local window = Window("button", menuItem.text, 'helptitle')
	local menu = SimpleMenu('menu')
	window:addWidget(menu)

	local item = { text = "Wireless", style = 'wireless'  }
	local item2 = { text = "Wired", style = 'wired'  }

	local helpButton = Button(Icon('rbutton'), function() log:warn('BAH!') end )
	window:getTitleWidget():setWidget('rbutton', helpButton)
	menu:addItem(item)
	menu:addItem(item2)

	self:tieAndShowWindow(window)
	return window
end


function albumMenuWindow(self, menuItem)
	local window = Window("window", menuItem.text)
	local menu = SimpleMenu('albummenu')
	window:addWidget(menu)

	local item = { text = "Test of Albumitem Style", style = 'albumitem'  }
	local item2 = { text = "Test of AlbumitemChecked Style", style = 'albumchecked' }
	local item3 = { text = "Test of AlbumitemNoAction Style", style = 'albumitemNoAction' }

	menu:addItem(item)
	menu:addItem(item2)
	menu:addItem(item3)

	self:tieAndShowWindow(window)
	return window
end



function menuWindow(self, menuItem, style, itemStyle)
	if not style then
		style = 'window'
		itemStyle = 'item'
	else
		if itemStyle then
			itemStyle = itemStyle .. "item"
		else
			itemStyle = style .. "item"
		end
	end
	local window = Window(style, menuItem.text)
	local menu = SimpleMenu('menu')
	window:addWidget(menu)

	local items = {}
	for i=1,2000 do
		items[#items + 1] = { text = "Artist " .. i, style = itemStyle  }
	end

	menu:setItems(items)

	self:tieAndShowWindow(window)
	return window
end


function textWindow(self, menuItem, filename)

	local window = Window("window", menuItem.text)

	filename = System:findFile(filename)
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


function errorWindow(self)
	local window = Popup("errorWindow", "Error Message")
	window:setAllowScreensaver(false)

	local textarea = Textarea("textarea", "A description of the error. This may be several lines long.")

	local menu = SimpleMenu("menu",
				{
					{
						text = "Go back",
						sound = "WINDOWHIDE",
						callback = function()
								   window:hide()
							   end
					},
					{
						text = "Corrective action",
						sound = "WINDOWHIDE",
						callback = function()
								   window:hide()
							   end
					},
				})


	window:addWidget(textarea)
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end

function keyboardWindow(self, menuItem, style)

	local window = Window("window", menuItem.text)

	local v = Textinput.textValue("", 8, 20)

	local textinput = Textinput("textinput", v,
		function(_, value)
			log:warn("Input ", value)

			window:playSound("WINDOWSHOW")
			window:hide(Window.transitionPushLeft)
			return true
		end)

	window:addWidget(textinput)
	window:addWidget(Keyboard('keyboard', style))
	window:focusWidget(textinput)

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

					window:playSound("WINDOWSHOW")
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

					window:playSound("WINDOWSHOW")
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

					window:playSound("WINDOWSHOW")
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

					window:playSound("WINDOWSHOW")
					window:hide(Window.transitionPushLeft)
					return true
				end)

	local help = Textarea("help", "Input of IP addresses.")

	window:addWidget(help)
	window:addWidget(input)

	self:tieAndShowWindow(window)
	return window
end


function lockedScreen(self, menuItem)
	local popup = Popup("popupIcon")

        popup:setAllowScreensaver(false)
        popup:setAlwaysOnTop(true)
        popup:setAutoHide(false)

        popup:addWidget(Icon("iconLocked"))
        popup:addWidget(Label("text", "Locked"))
	popup:addWidget(Textarea("lockedHelp", 'To unlock press the ADD and PLAY buttons at the same time.'))

	popup:addTimer(10000, function()
			       popup:hide()
			       end)

	self:tieAndShowWindow(popup)
	return popup
end

function downloadingSoftware(self, menuItem)

	local popup = Popup("popupIcon")

	popup:setTransparent(false)

	--FIXME, this window does not layout correctly (Bug 5412)
	local icon = Icon("iconConnecting")
	local text = Label("text", "\nDownloading Firmware")
	local label = Label("text", "0%")

	popup:addWidget(label)
	popup:addWidget(icon)
	popup:addWidget(text)


	local state = 1
	popup:addTimer(1000, function()
				       if state == 1 then
					       label:setValue("5%")
				       elseif state == 2 then
					       label:setValue("10%")
				       elseif state == 3 then
					       label:setValue("27%")
				       elseif state == 4 then
					       label:setValue("43%")
				       elseif state == 5 then
					       label:setValue("52%")
				       elseif state == 6 then
					       label:setValue("74%")
				       elseif state == 7 then
					       icon:setStyle("iconConnected")
					       label:setValue("100%")
						text:setValue("\nDownloading Complete!")
				       else
					       popup:hide()
				       end
				       state = state + 1
			       end)

	self:tieAndShowWindow(popup)
	return popup
end

local function localBackAction(self, event)
	log:warn("In localBackAction: ", event:tostring())
	return self:upAction()
end

function ignoreAllInputPopup(self, menuItem)

	local popup = Popup("popupIcon")

	local icon = Icon("iconConnecting")
	local label = Label("text", "All input is ignored, except:\n'disconnect_player', 'back', 'go'")

	popup:addWidget(icon)
	popup:addWidget(label)

	-- disable input, but still allow disconnect_player
	popup:ignoreAllInputExcept({"disconnect_player", "back"})

	--try some local listeners (comment out to see global handling - back should still work
	popup:addActionListener("back", popup, localBackAction)
	popup:addActionListener("go", popup, localBackAction)

	self:tieAndShowWindow(popup)
	return popup
end

function connectingPopup(self, menuItem)

	local popup = Popup("popupIcon")

	local icon = Icon("icon")
	local label = Label("text", "Finding available\nwireless networks...")
	local label2 = Label("text2", "found: 1")

	popup:addWidget(label)
	popup:addWidget(icon)
	popup:addWidget(label2)


	local state = 1
	popup:addTimer(4000, function()
				       if state == 1 then
					       label:setValue("a long test string!")
					       label2:setValue("Found: 3")
				       elseif state == 2 then
					       label:setValue("a very very very long test string!")
					       label2:setValue("Found: 5")
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

	-- by default close popup on keypress
	window:hideOnAllButtonInput()

	self:tieAndShowWindow(window)
	return window
end


function timerTestWindow(self, instead)
	local popup = Popup("popupIcon")
	local icon = Icon("iconConnecting")
	local label = Label("text", "Timer test 1")

	popup:addWidget(icon)
	popup:addWidget(label)

	popup:addTimer(2000,
		function()
			self:timerTestWindow2()
		end)	

	if instead then
		popup:showInstead(Window.transitionFadeIn)
	else
		popup:show()
	end
end


function timerTestWindow2(self)
	local window = Popup("popupIcon")
	local icon = Icon("iconConnected")
	local label = Label("text", "Timer test 2")

	window:addWidget(icon)
	window:addWidget(label)

	window:addTimer(1000,
		function()
			self:timerTestWindow(true)
		end)	

	window:showInstead(Window.transitionFadeIn)
end


--[[

=head1 LICENSE

This source code is public domain. It is intended for you to use as a starting
point to create your own applet.

=cut
--]]

