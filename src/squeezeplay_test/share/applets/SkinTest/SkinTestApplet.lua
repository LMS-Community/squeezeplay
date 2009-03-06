--[[

Skin test applet.

Each window style is represented once in this applet. Every good rule needs
an exception, so multiple keyboards are included :).

To make it easier to test the following shortcuts can be used:
	jump_fwd (b) - move to next screen
	jump_rew (z) - move to previous screen
	pause (c) - take screenshot


The objective is to keep the reference code as simple as possible!

--]]

local string, ipairs, tostring = string, ipairs, tostring

local oo                  = require("loop.simple")

local Applet              = require("jive.Applet")
local Group               = require("jive.ui.Group")
local Event               = require("jive.ui.Event")
local Framework           = require("jive.ui.Framework")
local Icon                = require("jive.ui.Icon")
local Button              = require("jive.ui.Button")
local Label               = require("jive.ui.Label")
local Choice              = require("jive.ui.Choice")
local Checkbox            = require("jive.ui.Checkbox")
local RadioButton         = require("jive.ui.RadioButton")
local RadioGroup          = require("jive.ui.RadioGroup")
local Popup               = require("jive.ui.Popup")
local Keyboard            = require("jive.ui.Keyboard")
local SimpleMenu          = require("jive.ui.SimpleMenu")
local Slider              = require("jive.ui.Slider")
local Surface             = require("jive.ui.Surface")
local Textarea            = require("jive.ui.Textarea")
local Textinput           = require("jive.ui.Textinput")
local Window              = require("jive.ui.Window")

local debug               = require("jive.utils.debug")
local log                 = require("jive.utils.log").addCategory("test", jive.utils.log.DEBUG)


module(..., Framework.constants)
oo.class(_M, Applet)


local windows -- defined at end
local testData -- defined at end


function _itemName(item)
	return item[2] .. " (" .. item[1] .. ")"
end


function _itemData(item)
	return testData[item[1]]
end


-- move to the next text window
function _windowNext(self, item)
	local next

	for i,anitem in ipairs(windows) do
		if item == anitem then
			next = i + 1
		end
	end

	if next > #windows then
		next = 1
	end

	windows[next][3](self, windows[next]):showInstead()
end


-- move to the next previous window
function _windowPrev(self, item)
	local prev

	for i,anitem in ipairs(windows) do
		if item == anitem then
			prev = i - 1
		end
	end

	if prev < 1 then
		prev = #windows
	end

	windows[prev][3](self, windows[prev]):showInstead()
end


-- add test actions to window
function _windowActions(self, item, window)
	window:addActionListener("jump_fwd",
		nil,
		function()
			_windowNext(self, item)
		end)

	window:addActionListener("jump_rew",
		nil,
		function()
			_windowPrev(self, item)
		end)

	window:addActionListener("pause",
		nil,
		function()
			local sw, sh = Framework:getScreenSize()
			local img = Surface:newRGB(sw, sh)

			Framework:draw(img)

			log:info("Saving ", item[1] .. ".bmp")
			img:saveBMP(item[1] .. ".bmp")
		end)
end


-- top level menu
function menu(self)
	local window = Window("text_list", "Skin Tests")

	local menu = SimpleMenu("menu")

	for i,item in ipairs(windows) do
		menu:addItem({
			text = _itemName(item),
			sound = "WINDOWSHOW",
			callback = function()
				item[3](self, item):show()
			end,
		})
	end

	window:addWidget(menu)
	self:tieAndShowWindow(window)
end


-- this is a dummy help window
function dummy_help(self)
	local window = Window("help_info", "Help")
	window:setAllowScreensaver(false)

	local textarea = Textarea("text", "This is a help window.")
	window:addWidget(textarea)
	self:tieAndShowWindow(window)
end



-- REFERENCE WINDOW STYLES ARE BELOW



--[[
Window:   "text_list"
Textarea: "help_text"
Menu:     "menu"
Item:     "item"
--]]
function setup_text_list_one(self, item)
	local data = _itemData(item)

	local window = Window("text_list", _itemName(item), "setup")
	_windowActions(self, item, window)

	local textarea = Textarea("help_text", data[1])

	local menu = SimpleMenu("menu")
	menu:addItem({
		text = data[2]
	})

	window:addWidget(textarea)
	window:addWidget(menu)

	self:tieWindow(window)
	return window
end


--[[
Window:   "text_list"
Textarea: "help_text"
Menu:     "menu"
Item:     "item"
--]]
function setup_text_list_two(self, item)
	local data = _itemData(item)

	local window = Window("text_list", _itemName(item), "setup")
	_windowActions(self, item, window)

	window:addActionListener("help", self, dummy_help)
	window:setButtonAction("rbutton", "help")

	local textarea = Textarea("help_text", data[1])

	local menu = SimpleMenu("menu")
	for i,subdata in ipairs(data[2]) do
		menu:addItem({
			text = subdata[1],
			iconStyle = subdata[2],
		})
	end

	window:addWidget(textarea)
	window:addWidget(menu)

	self:tieWindow(window)
	return window
end


--[[
Window:   "help_info"
Textarea: "text"
--]]
function setup_help_info(self, item)
	local data = _itemData(item)

	local window = Window("help_info", _itemName(item), "setup")
	_windowActions(self, item, window)

	local textarea = Textarea("text", data[1])

	window:addWidget(textarea)

	self:tieWindow(window)
	return window
end


--[[
Popup:   "waiting_popup"
Label:    "text", "subtext"
Icon:     X
--]]
function setup_waiting_popup(self, item)
	local data = _itemData(item)

	local popup = Popup("waiting_popup")
	_windowActions(self, item, popup)

	local label = Label("text", data[1])
	local sublabel = Label("subtext", data[2])
	local icon = Icon(data[3])

	popup:addWidget(label)
	popup:addWidget(icon)
	popup:addWidget(sublabel)

	self:tieWindow(popup)
	return popup
end


--[[
Window:    "input"
Textinput: "textinput"
Keyboard:  "keyboard"
--]]
function setup_input_hex(self, item)
	local data = _itemData(item)

	local window = Window("input", _itemName(item), "setup")
	_windowActions(self, item, window)

	-- normal short cuts don't work with text entry
	window:addActionListener("back", nil, function()
		_windowPrev(self, item)
	end)

	local textinput = Textinput(
		"textinput", 
		data[1],
		function(_, value)
			_windowNext(self, item)
		end
	)
	local backspace = Button(
		Icon('button_keyboard_back'),
		function()
			local e = Event:new(EVENT_CHAR_PRESS, string.byte("\b"))
			Framework:dispatchEvent(nil, e)
			return EVENT_CONSUME
		end
	)
	local group = Group('keyboard_textinput', { textinput = textinput, backspace = backspace } )

	window:addWidget(group)
	window:addWidget(Keyboard("keyboard", data[2]))
	window:focusWidget(group)

	return window
end


--[[
Window:    "input"
Textinput: "textinput"
Keyboard:  "keyboard"
--]]
function setup_input(self, item)
	local data = _itemData(item)

	local window = Window("input", _itemName(item), "setup")
	_windowActions(self, item, window)

	-- normal short cuts don't work with text entry
	window:addActionListener("back", nil, function()
		_windowPrev(self, item)
	end)

	local textinput = Textinput(
		"textinput", 
		data[1],
		function(_, value)
			_windowNext(self, item)
		end
	)
	local backspace = Button(
		Icon('button_keyboard_back'),
		function()
			local e = Event:new(EVENT_CHAR_PRESS, string.byte("\b"))
			Framework:dispatchEvent(nil, e)
			return EVENT_CONSUME
		end
	)
	local group = Group('keyboard_textinput', { textinput = textinput, backspace = backspace } )

	window:addWidget(group)
	window:addWidget(Keyboard("keyboard", data[2]))
	window:focusWidget(group)

	return window
end


--[[
Window:    "error"
Textarea:  "text"
Menu:      "menu"
Item:      "item"
--]]
function setup_error(self, item)
	local data = _itemData(item)

	local window = Window("error", _itemName(item), "setup")
	_windowActions(self, item, window)

	local textarea = Textarea("text", data[1])

	local menu = SimpleMenu("menu")
	for i,data in ipairs(data[2]) do
		menu:addItem({
			text = data,
		})
	end

	window:addWidget(textarea)
	window:addWidget(menu)

	self:tieWindow(window)
	return window
end


--[[
Popup:    "update_popup"
Label:    "text"
Slider:   "progress"
Icon:     X
--]]
function setup_update_popup(self, item)
	local data = _itemData(item)

	local popup = Popup("update_popup")
	_windowActions(self, item, popup)

	local label = Label("text", data[1])
	local cent = Label("subtext", "")
	local icon = Icon(data[2])
	local progress = Slider("progress", 1, 100, 1)

	local count = 1
	popup:addTimer(500, function()
		if count < 100 then
			count = count + 1
		end
		cent:setValue(count .. "%")
		progress:setRange(1, 100, count)
	end)

	popup:addWidget(label)
	popup:addWidget(icon)
	popup:addWidget(cent)
	popup:addWidget(progress)

	self:tieWindow(popup)
	return popup
end


--[[
Window:   "text_list"
Textarea: "help_text" (optional)
Menu:     "menu"
Item:     "item_play", "item_add", "item" (styles: selected, pressed, locked)
--]]
function window_track_info(self, item)
	local data = _itemData(item)

	local window = Window("text_list", _itemName(item), "home")
	_windowActions(self, item, window)

	local menu = SimpleMenu("menu")
	for i, text in ipairs(data) do
		log:warn(text)
		local itemStyle = 'item'
		self.checkMe = true
		if i == 1 then
			itemStyle = 'item_play'
			self.checkMe = false
		elseif i == 2 then
			itemStyle = 'item_add'
			self.checkMe = false
		end
		local callback 
		if self.checkMe then
			callback = function(event, item)
				if selected == item then
					menu:lock()
					return
				end

				if selected then
					selected.style = "item"
					menu:updatedItem(selected)
				end

				item.style = "item_checked"
				menu:updatedItem(item)

				selected = item
			end
		else
			callback = function(event, item)
				if selected == item then
					menu:lock()
					return
				end

				if selected then
					selected.style = "item"
					menu:updatedItem(selected)
				end

				selected = item
			end
		end
		menu:addItem({
			text = text,
			sound = "WINDOWSHOW",
			style = itemStyle,
			callback = callback,
		})
	end
	
	window:addWidget(menu)

	self:tieWindow(window)
	return window
end


--[[
Window:   "text_list"
Menu:     "menu"
Item:     "item_choice", "item", "item_checked", (styles: selected, pressed, locked)
--]]
function setup_text_list(self, item)
	local data = _itemData(item)

	local window = Window("text_list", _itemName(item), "home")
	_windowActions(self, item, window)

	-- FIXME: choice items do not work
	local menu = SimpleMenu("menu")
	local choice = Choice("choice", { 'on', 'off' },
		function(object, selectedIndex)
			log:warn('choice is: ', tostring(selectedIndex))
		end,
		1
	)
	local checkbox = Checkbox(
                        "checkbox",
                        function(_, checkboxFlag)
                                if (checkboxFlag) then
                                        log:warn("ON: ", checkboxFlag)
                                else
                                        log:warn("OFF: ", checkboxFlag)
                                end
                        end,
                        checkboxFlag == 1
	)
	local group = RadioGroup()
	local radios = {
		RadioButton(
			"radio",
			group,
			function()
				log:warn("radio button selected")
			end,
			true
		),
		RadioButton(
			"radio",
			group,
			function()
				log:warn("radio button 2 selected")
			end,
			false
		)
	}
	menu:addItem({
		text  = 'Sample Choice Item',
		style = 'item_choice',
		check  = choice,
	})
	menu:addItem({
		text  = 'Sample Checkbox',
		style = 'item_choice',
		check  = checkbox,
	})
	menu:addItem({
		text  = 'Sample Radio 1',
		style = 'item_choice',
		check  = radios[1],
	})
	menu:addItem({
		text  = 'Sample Radio 2',
		style = 'item_choice',
		check  = radios[2],
	})
	for i, text in ipairs(data[2]) do
		log:warn(text)
		menu:addItem({
			text = text,
			sound = "WINDOWSHOW",
			callback = function(event, item)
				if selected == item then
					menu:lock()
					return
				end

				if selected then
					selected.style = "item"
					menu:updatedItem(selected)
				end

				item.style = "item_checked"
				menu:updatedItem(item)

				selected = item
			end
		})
	end

	window:addWidget(Label("help_text", data[1]))	
	window:addWidget(menu)

	self:tieWindow(window)
	return window
end

--[[
Window:   "playlist"
Menu:     "menu"
Item:     "item", "item_checked", (styles: selected, pressed, locked)
--]]
function window_playlist(self, item)
	local data = _itemData(item)

	local window = Window("play_list", _itemName(item), "artists")
	_windowActions(self, item, window)

	local menu = SimpleMenu("menu")
	for i,subdata in ipairs(data) do
		menu:addItem({
			text = subdata[1],
			icon = Icon('icon_no_artwork'),
			callback = function(event, item)
				if selected == item then
					menu:lock()
					return
				end

				if selected then
					selected.style = "item"
					menu:updatedItem(selected)
				end

				item.style = "item_checked"
				menu:updatedItem(item)

				selected = item
			end
		})
	end

	-- add an item for item_no_arrow and item_checked_no_arrow
	menu:addItem({
			text = "Test of no artwork",
	})
	menu:addItem({
			text  = "Clear Playlist",
	})
	menu:addItem({
			text  = "Save Playlist",
	})

	window:addWidget(menu)

	self:tieWindow(window)
	return window
end


--[[
Window:   "icon_list"
Menu:     "menu"
Item:     "item", "item_checked", (styles: selected, pressed, locked)
--]]
function window_icon_list(self, item)
	local data = _itemData(item)

	local window = Window("icon_list", _itemName(item), "artists")
	_windowActions(self, item, window)

	local menu = SimpleMenu("menu")
	menu:addItem({
		text = "this is an item without an icon\njust don't add an icon in the menu item and there won't be one"
	})
	for i,subdata in ipairs(data) do
		menu:addItem({
			text = subdata[1],
			icon = Icon('icon_no_artwork'),
			callback = function(event, item)
				if selected == item then
					menu:lock()
					return
				end

				if selected then
					selected.style = "item"
					menu:updatedItem(selected)
				end

				item.style = "item_checked"
				menu:updatedItem(item)

				selected = item
			end
		})
	end

	window:addWidget(menu)

	self:tieWindow(window)
	return window
end


--[[
Window:   "information"
Textarea: "text"
--]]
function window_information(self, item)
	local data = _itemData(item)

	local window = Window("information", _itemName(item))
	_windowActions(self, item, window)

	local textarea = Textarea("text", data[1])

	window:addWidget(textarea)

	self:tieWindow(window)
	return window
end


--[[
Window:   "track_list" (with "icon" in menu bar for thumbnail)
Menu:     "menu"
1st Item: "itemplay"
Item:     "item"
--]]
function window_track_list(self, item)
	local data = _itemData(item)

	local window = Window("track_list", _itemName(item))
	_windowActions(self, item, window)

	window:setIconWidget("icon", Icon("icon"))

	local menu = SimpleMenu("menu")
	for i, text in ipairs(data) do
		log:warn(text)
		menu:addItem({
			text = text,
			sound = "WINDOWSHOW",
			callback = function(event, item)
				if selected == item then
					menu:lock()
					return
				end

				if selected then
					selected.style = "item"
					menu:updatedItem(selected)
				end

				item.style = "item_checked"
				menu:updatedItem(item)

				selected = item
			end
		})
	end
	
	window:addWidget(menu)

	self:tieWindow(window)
	return window
end


--[[
Popup:   "toast_popup"
Group:	 "group"
  Label:   "text"
--]]
function window_toast_popup(self, item)
	local data = _itemData(item)

	local popup = Popup("toast_popup")
	_windowActions(self, item, popup)

	local group = Group("group", {
		text = Label("text", data[1])
	})

	popup:addWidget(group)

	self:tieWindow(popup)
	return popup
end

--[[
Popup:   "toast_popup"
Group:	 "group"
  Label:   "text"
  Icon:    "icon"
--]]
function window_toast_popup_withicon(self, item)
	local data = _itemData(item)

	local popup = Popup("toast_popup")
	_windowActions(self, item, popup)

	local group = Group("group", {
		text = Textarea("text", data[1]),
		icon = Icon(data[2]),
	})

	popup:addWidget(group)

	self:tieWindow(popup)
	return popup
end

--[[
Popup:   "toast_popup"
Group:	 "group"
  Label:   "text"
  Icon:    "icon"
--]]
function window_slider_popup(self, item)
	local data = _itemData(item)

	local popup = Popup("slider_popup")
	_windowActions(self, item, popup)

	local title = Label("text", data[1])
	local slider = Slider("volume_slider", -1, 100, 50)

	popup:addWidget(title)
	popup:addWidget(Group("slider_group", {
		min = Icon("button_volume_min"),
		slider = slider,
		max = Icon("button_volume_max")
	}))

	return popup
end


-- REFERENCE WINDOW STYLES ARE ABOVE




-- the reference windows, and test data
windows = {
	{ "text_list", "Text List", setup_text_list, },
	{ "text_list_one", "Welcome to Setup", setup_text_list_one, },
	{ "text_list_two", "Choose Region", setup_text_list_two, },
	{ "input_hex", "WEP Password", setup_input_hex, },
	{ "help_info", "Help Connection Type", setup_help_info, },
	{ "waiting_popup", "Connecting to", setup_waiting_popup, },
	{ "input_wpa", "Wireless Password", setup_input, },
	{ "error", "Error", setup_error, },
	{ "update_popup", "Software Update", setup_update_popup, },
	{ "track_info", "Track Info", window_track_info, },
	{ "track_list", "Track List", window_track_list, },
	{ "playlist", "Playlist", window_playlist, },
	{ "icon_list", "Icon List", window_icon_list, },
	{ "information", "Information Window", window_information, },
	{ "toast_popup", "Popup Toast", window_toast_popup, },
	{ "toast_popup_withicon", "Popup Toast w/art", window_toast_popup_withicon, },
	{ "slider_popup", "Volume", window_slider_popup, },
}


testData = {
	text_list = {
		"Screen copy, if any goes here",
		{ "Now Playing", "Music Library", "Internet Radio", "Music Services", "Favorites", "Extras", "Settings", "Choose Player", "Turn Off Player" }
	},
	text_list_one = {
		"Let's begin by getting\nyou connected to your network.",
		"Continue"
	},
	text_list_two = {
		"Is text allowed in this window?",
		{ { "North America", "region_US" },
		  { "All Other Regions" , "region_XX" },
		},
	},
	help_info = {
		"This is some help text, in a help window. It could be very long, and may need a scrollbar.\nThe quick brown fox jumped over the lazy dog.\nForsaking monastic tradition, twelve jovial friars gave up their vocation for a questionable existence on the flying trapeze.\nSix javelins thrown by the quick savages whizzed forty paces beyond the mark.\nJaded zombies acted quaintly but kept driving their oxen forward.",
	},
	information = {
		"The Yamazaki \n18 Year in four haikus\n(this is one of them)\n \nYamazaki HAI!\nSuntory Distillery\nGood Nose; Strong Finish\n \nThey say that the Scots\nare the only ones blessed with\nskill to make scotch. No.\n \nBut let your palate\nbe the judge and not my words\nNow! Please to enjoy!" 
	},
	waiting_popup = {
		"Connecting to\nwireless network...", "all your base", "icon_connecting",
	},
	input_wpa = {
		Textinput.textValue("", 8, 20), 'qwerty',
	},
	input_hex = {
		Textinput.textValue("", 8, 20), 'hex',
	},
	error = {
		"DHCP Address Cannot be Found",
		{ "Try to Detect Automatically",
		  "Manually Enter IP Address",
		},
	},
	update_popup = {
		"Installing\nSoftware Update...", "icon_software_update",
	},
	track_info = {
		"Play this song",
		"Add this song",
		"Artist: Sun Kil Moon",
		"Album: April",
		"Genre: No Genre",
		"Year: 2008",
		"Comment",
	},
	icon_list = {
		{ "Something" }, 
		{ "Something Else" },
		{ "More Somethings" },
		{ "Another Something" },
		{ "How many somethings does it take to screw in a light bulb" },
	},
	track_list = {
		 "1. Something", 
		 "2. Something Else",
		 "3. More Somethings",
		 "4. Another Something",
		 "5. How many somethings does it take to screw in a light bulb",
		 "Add to Favorites",
	},
	playlist = {
		{ "Something\nThe Somethings\nGreatest Hits" }, 
		{ "In Our Bedroom After The War\nStars\nIn Our Bedroom After The War" },
		{ "3121\nPrince\nSome Very Long Album Title That Goes off Screen" },
		{ "Something\nThe Somethings\nGreatest Hits" }, 
		{ "In Our Bedroom After The War\nStars\nIn Our Bedroom After The War" },
		{ "3121\nPrince\nSome Very Long Album Title That Goes off Screen" },
	},
	toast_popup = {
		"Your toast_popup is done",
	},
	toast_popup_withicon = {
		"United States. A country of central and northwest North America with coastlines on the Atlantic and Pacific oceans.",
		"region_US",
	},
	slider_popup = {
		"Volume",
	}
}
