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

local ipairs = ipairs

local oo                  = require("loop.simple")

local Applet              = require("jive.Applet")
local Group               = require("jive.ui.Group")
local Framework           = require("jive.ui.Framework")
local Icon                = require("jive.ui.Icon")
local Label               = require("jive.ui.Label")
local Choice              = require("jive.ui.Choice")
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
	local window = Window("window", "Skin Tests")

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
	local window = Window("help", "Help")
	window:setAllowScreensaver(false)

	local textarea = Textarea("text", "This is a help window.")
	window:addWidget(textarea)
	self:tieAndShowWindow(window)
end



-- REFERENCE WINDOW STYLES ARE BELOW



--[[
Window:   "setuplist"
Menu:     "menu"
Item:     "item", "itemChecked"
Textarea: "helptext"
--]]
function setup_window(self, item)
	local data = _itemData(item)

	local window = Window("setuplist", _itemName(item), "setup")
	_windowActions(self, item, window)

	local selected = nil

	local menu = SimpleMenu("menu")
	for i,text in ipairs(data[1]) do
		menu:addItem({
			text = text,
			sound = "WINDOWSHOW",
			callback = function(event, item)
				if selected then
					selected.style = "item"
					menu:updatedItem(selected)
				end
				item.style = "itemChecked"
				menu:updatedItem(item)

				selected = item
			end,
		})		
	end

	window:addWidget(menu)
	window:addWidget(Textarea("helptext", data[2]))

	window:focusWidget(menu)

	self:tieWindow(window)
	return window
end


--[[
Window:   "onebutton"
Textarea: "text"
Menu:     "menu"
Item:     "item"
--]]
function setup_onebutton(self, item)
	local data = _itemData(item)

	local window = Window("onebutton", _itemName(item), "setup")
	_windowActions(self, item, window)

	local textarea = Textarea("text", data[1])

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
Window:   "buttonlist"
Textarea: "text"
Menu:     "menu"
Item:     "item"
--]]
function setup_button(self, item)
	local data = _itemData(item)

	local window = Window("buttonlist", _itemName(item), "setup")
	_windowActions(self, item, window)

	window:addActionListener("help", self, dummy_help)
	window:setButtonAction("rbutton", "help")

	local textarea = Textarea("text", data[1])

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
Window:   "help"
Textarea: "text"
--]]
function setup_help(self, item)
	local data = _itemData(item)

	local window = Window("help", _itemName(item), "setup")
	_windowActions(self, item, window)

	local textarea = Textarea("text", data[1])

	window:addWidget(textarea)

	self:tieWindow(window)
	return window
end


--[[
Popup:   "waiting"
Label:    "text", "subtext"
Icon:     X
--]]
function setup_waiting(self, item)
	local data = _itemData(item)

	local popup = Popup("waiting")
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
function setup_input(self, item)
	local data = _itemData(item)

	local window = Window("input", _itemName(item), "setup")
	_windowActions(self, item, window)

	-- normal short cuts don't work with text entry
	window:addActionListener("back", nil, function()
		_windowPrev(self, item)
	end)

	local textinput = Textinput("textinput", data[1],
		function(_, value)
			_windowNext(self, item)
		end)

	window:addWidget(textinput)
	window:addWidget(Keyboard("keyboard", data[2]))

	window:focusWidget(textinput)

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
Popup:    "update"
Label:    "text"
Slider:   "progress"
Icon:     X
--]]
function setup_update(self, item)
	local data = _itemData(item)

	local popup = Popup("update")
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
Window:   "textlist"
Menu:     "menu"
Item:     "itemPlay", "itemAdd", "item" (styles: selected, pressed, locked)
--]]
function window_trackinfo(self, item)
	local data = _itemData(item)

	local window = Window("textlist", _itemName(item), "home")
	_windowActions(self, item, window)

	local menu = SimpleMenu("menu")
	for i, text in ipairs(data) do
		log:warn(text)
		local itemStyle = ''
		self.checkMe = true
		if i == 1 then
			itemStyle = 'Play'
			self.checkMe = false
		elseif i == 2 then
			itemStyle = 'Add'
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

				item.style = "itemChecked"
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
			style = 'item' .. itemStyle,
			callback = callback,
		})
	end
	
	window:addWidget(menu)

	self:tieWindow(window)
	return window
end


--[[
Window:   "textlist"
Menu:     "menu"
Item:     "itemChoice", "item", "itemChecked", (styles: selected, pressed, locked)
--]]
function setup_textlist(self, item)
	local data = _itemData(item)

	local window = Window("textlist", _itemName(item), "home")
	_windowActions(self, item, window)

	-- FIXME: choice items do not work
	local menu = SimpleMenu("menu")
	local choice = Choice("icon", { 'on', 'off' },
		function(object, selectedIndex)
			log:warn('choice is: ', tostring(selectedIndex))
		end,
		1
	)
	menu:addItem({
		text  = 'Sample Choice Item',
		style = 'itemChoice',
		icon  = choice,
	})
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

				item.style = "itemChecked"
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
Window:   "playlist"
Menu:     "menu"
Item:     "item", "itemChecked", (styles: selected, pressed, locked)
--]]
function window_playlist(self, item)
	local data = _itemData(item)

	local window = Window("playlist", _itemName(item), "artists")
	_windowActions(self, item, window)

	local menu = SimpleMenu("menu")
	for i,subdata in ipairs(data) do
		menu:addItem({
			text = subdata[1],
			callback = function(event, item)
				if selected == item then
					menu:lock()
					return
				end

				if selected then
					selected.style = "item"
					menu:updatedItem(selected)
				end

				item.style = "itemChecked"
				menu:updatedItem(item)

				selected = item
			end
		})
	end

	-- add an item for itemNoArrow and itemCheckedNoArrow
	menu:addItem({
			text = "Test of itemNoArrow",
			style = 'itemNoArrow',
	})
	menu:addItem({
			text = "Test of itemCheckedNoArrow",
			style = 'itemCheckedNoArrow',
	})

	window:addWidget(menu)

	self:tieWindow(window)
	return window
end


--[[
Window:   "iconlist"
Menu:     "menu"
Item:     "item", "itemChecked", (styles: selected, pressed, locked)
--]]
function window_iconlist(self, item)
	local data = _itemData(item)

	local window = Window("iconlist", _itemName(item), "artists")
	_windowActions(self, item, window)

	local menu = SimpleMenu("menu")
	for i,subdata in ipairs(data) do
		menu:addItem({
			text = subdata[1],
			callback = function(event, item)
				if selected == item then
					menu:lock()
					return
				end

				if selected then
					selected.style = "item"
					menu:updatedItem(selected)
				end

				item.style = "itemChecked"
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
Window:   "tracklist" (with "icon" in menu bar for thumbnail)
Menu:     "menu"
1st Item: "itemplay"
Item:     "item"
--]]
function window_tracklist(self, item)
	local data = _itemData(item)

	local window = Window("tracklist", _itemName(item))
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

				item.style = "itemChecked"
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
Popup:   "toast"
Label:   "text"
--]]
function window_toast(self, item)
	local data = _itemData(item)

	local popup = Popup("toast")
	_windowActions(self, item, popup)

	local text = Label("text", "Your toast is done")

	-- XXXX add other widgets

	popup:addWidget(text)

	self:tieWindow(popup)
	return popup
end

--[[
Popup:   "icontoast"
Group:	 "xxxx"
  Label:   "text"
  Icon:    "icon"
--]]
function window_icontoast(self, item)
	local data = _itemData(item)

	local popup = Popup("icontoast")
	_windowActions(self, item, popup)

	local group = Group("xxxx", {
		text = Textarea("text", "Your toast is done"),
		icon = Icon('icon'),
		-- XXXX add other widgets
	})

	popup:addWidget(group)

	self:tieWindow(popup)
	return popup
end



-- REFERENCE WINDOW STYLES ARE ABOVE




-- the reference windows, and test data
windows = {
	{ "information", "Information Window", window_information, },

	{ "setuplist", "Languages", setup_window, },
	{ "onebutton", "Welcome to Setup", setup_onebutton, },
	{ "buttonlist", "Choose Region", setup_button, },
	{ "help", "Help Connection Type", setup_help, },
	{ "waiting", "Connecting to", setup_waiting, },
	{ "input_wpa", "Wireless Password", setup_input, },
	{ "error", "Error", setup_error, },
	{ "update", "Software Update", setup_update, },
	{ "trackinfo", "Track Info", window_trackinfo, },
	{ "tracklist", "Track List", window_tracklist, },
	{ "playlist", "Playlist", window_playlist, },
	{ "textlist", "Text List", setup_textlist, },
	{ "iconlist", "Icon List", window_iconlist, },
	{ "information", "Information Window", window_information, },
	{ "toast", "Popup Toast", window_toast, },
	{ "icontoast", "Popup Toast w/art", window_icontoast, },
}


testData = {
	setuplist = {
		{ "Deutsch", "Suomi", "English", "Dansk", "Itailiano", "Français", "Norsk", "Sevnska", "Español" },
		"Some help text",
	},
	onebutton = {
		"Let's begin by getting\nyou connected to your network.",
		"Continue"
	},
	buttonlist = {
		"Is text allowed in this window?",
		{ { "North America", "region_US" },
		  { "All Other Regions" , "region_XX" },
		},
	},
	help = {
		"This is some help text, in a help window. It could be very long, and may need a scrollbar.\nThe quick brown fox jumped over the lazy dog.\nForsaking monastic tradition, twelve jovial friars gave up their vocation for a questionable existence on the flying trapeze.\nSix javelins thrown by the quick savages whizzed forty paces beyond the mark.\nJaded zombies acted quaintly but kept driving their oxen forward.",
	},
	information = {
		"The Yamazaki \n 18 Year in four haikus\n (this is one of them)\n \n Yamazaki HAI!\n Suntory Distillery\n Good Nose; Strong Finish\n \n They say that the Scots\n are the only ones blessed with\n skill to make scotch. No.\n \n But let your palate\n be the judge and not my words\n Now! Please to enjoy!\n" 
	},
	waiting = {
		"Connecting to\nwireless network...", "all your base", "iconConnecting",
	},
	input_wpa = {
		Textinput.textValue("", 8, 20), 'qwerty',
	},
	error = {
		"DHCP Address Cannot be Found",
		{ "Try to Detect Automatically",
		  "Manually Enter IP Address",
		},
	},
	update = {
		"Installing\nSoftware Update...", "iconSoftwareUpdate",
	},
	textlist = {
		 "Now Playing", "Music Library", "Internet Radio", "Music Services", "Favorites", "Extras", "Settings", "Choose Player", "Turn Off Player"
	},
	trackinfo = {
		"Play this song",
		"Add this song",
		"Artist: Sun Kil Moon",
		"Album: April",
		"Genre: No Genre",
		"Year: 2008",
		"Comment",
	},
	iconlist = {
		{ "Something" }, 
		{ "Something Else" },
		{ "More Somethings" },
		{ "Another Something" },
		{ "How many somethings does it take to screw in a light bulb" },
	},
	tracklist = {
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
}
