--[[

Wire Frame Applet

--]]

local string, pairs, ipairs, tostring = string, pairs, ipairs, tostring

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
local Timeinput           = require("jive.ui.Timeinput")
local Window              = require("jive.ui.Window")
local datetime            = require("jive.utils.datetime")
local jiveMain            = jiveMain

local debug               = require("jive.utils.debug")


module(..., Framework.constants)
oo.class(_M, Applet)

-- define a table of items to be rendered
-- edit this to whatever you want to render
function details(self)

	local data = {
		sync1 = {
			enabled     = true,
			windowStyle = 'text_list',
			titleText   = 'Synchronization',
			helpText    = 'This is some test help text to show that this works',
			items       = {
				{ text = 'Player A', radio = 1},
				{ text = 'Player B', radio = 1},
				{ text = 'Player C', radio = 1},
				{ text = 'Player D', radio = 1},
			},
		},
		sync2 = {
			enabled = true,
			windowStyle = 'text_list',
			titleText  = 'Synchronization',
			items = {
				{ text = 'Player A', checkbox = 1},
				{ text = 'Player B', checkbox = 1, checked = true},
				{ text = 'Player C', checkbox = 1},
				{ text = 'Player D', checkbox = 1},
			},
		},
		sync3 = {
			enabled = true,
			windowStyle = 'text_list',
			titleText  = 'Synchronization',
			items = {
				{ text = 'Player A', choice = 1, choices = { 'foo', 'bar', 'wtf' }, whichChoice = 3 },
				{ text = 'Player B'},
				{ text = 'Player C'},
				{ text = 'Player D'},
			},
		},
	}
	return data
end


function showMenu(self)
	self.data = self:details()

	local window = Window('text_list', 'Wire Frames')
	local menu   = SimpleMenu('menu')
	for k, v in pairs(self.data) do
		menu:addItem({
			text = k,
			callback = function()
				self:showWireFrame(k)
			end,
		})
	end
	menu:setComparator(SimpleMenu.itemComparatorAlpha)
	window:addWidget(menu)
	window:show()
	return window
end


function showWireFrame(self, key)

	local data = self.data[key]

	local window = Window(data.windowStyle or 'text_list', data.titleText)
	self.menu   = SimpleMenu('menu')

	for i, item in ipairs(data.items) do
		if item.radio then
			if not self.group then
				self.group = RadioGroup()
			end
			self:addRadioItem(item)
		elseif item.checkbox then
			self:addCheckboxItem(item)
		elseif item.choice then
			self:addChoiceItem(item)
		else
			self:addItem(item)
		end
	end
	if data.helpText then
		self:addHelpText(data.helpText)
	end

	window:addWidget(self.menu)
	window:show()
end


function addHelpText(self, helpText)

	local headerText = Textarea('help_text', helpText)
	self.menu:setHeaderWidget(headerText)
end

function addItem(self, item)
	self.menu:addItem(
		{
			text = item.text,
			style = item.style or 'item',
		}
	)
end

function addRadioItem(self, item)
	self.menu:addItem(
		{	
                        text = item.text,
                        style = 'item_choice',
                        sound = "WINDOWSHOW",
                        check = RadioButton("radio",
                                self.group,
                                function()
                                        log:warn('whoop there it is')
                                end,
				item.checked or false
                        ),
		}
	)
end

function addCheckboxItem(self, item)
	self.menu:addItem(
		{	
                        text = item.text,
                        style = 'item_choice',
                        sound = "WINDOWSHOW",
                        check = Checkbox("checkbox",
                                function()
                                        log:warn('whoop there it is')
                                end,
				item.checked or false
                        ),
		}
	)
	
end


function addChoiceItem(self, item)
	self.menu:addItem(
		{	
                        text = item.text,
                        style = 'item_choice',
                        sound = "WINDOWSHOW",
                        check = Choice("choice",
				item.choices,
                                function()
                                        log:warn('whoop there it is')
                                end,
				item.whichChoice or 1
                        ),
		}
	)
end


