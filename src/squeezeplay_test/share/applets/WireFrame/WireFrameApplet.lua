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
		RadioModel = {
			enabled     = true,
			windowStyle = 'text_list',
			titleText   = 'Synchronize',
			helpText    = 'Synchronize Player A to:',
			items       = {
				--{ text = 'Player A', radio = 1},
				{ text = 'Player B', radio = 1},
				{ text = 'Player C', radio = 1},
				{ text = 'Player D', radio = 1},
			},
		},
		CheckboxModel = {
			enabled = true,
			windowStyle = 'text_list',
			titleText  = 'Synchronize',
			helpText    = 'Synchronize Player A with:',
			items = {
				--{ text = 'Player A', checkbox = 1, checked = true},
				{ text = 'Player B', checkbox = 1, checked = true},
				{ text = 'Player C', checkbox = 1},
				{ text = 'Player D', checkbox = 1},
			},
		},
		GroupModel = {
			enabled     = true,
			windowStyle = 'text_list',
			titleText   = 'Multi-Room Audio',
			helpText    = 'Attach Player A to:', 
			items = {
				{ text = 'Group 1', radio = 1},
				{ text = 'Group 2', radio = 1},
				{ text = 'Group 3', radio = 1},
				{ text = 'Group Settings', },
			},
		},
		AdvancedSettings1 = {
			enabled     = true,
			windowStyle = 'text_list',
			titleText   = 'Multi-Room Audio',
			helpText    = 'Select a multi-room audio group to manage:',
			items = {
				{ text = 'Group 1'},
				{ text = 'Group 2'},
				{ text = 'Group 3'},
				{ text = 'Add Another Group' },
			},
		},
		AdvancedSettings2 = {
			enabled     = true,
			windowStyle = 'text_list',
			titleText   = 'Group 1',
			items = {
				{ text = 'Rename Group 1' },
				{ text = 'Edit Attached Players', },
				{ text = 'Group 1 Volume Behavior', },
				{ text = 'Delete Group 1' },
				{ text = 'TBD...' },
			},
		},
		lineIn = {
			special = 'lineIn',
			windowStyle = 'nowplaying_small_art',
			iconStyle = 'icon_linein',
			--iconStyle = 'icon_apple',
			titleText = 'Line In',
		},
		EditAttachedPlayer = {
			enabled = true,
			--windowStyle = 'text_list',
			windowStyle = 'choose_player',
			titleText  = 'Group 1 Players',
			helpText    = 'Check the boxes of the players that should be synchronized within Group 1',
			items = {
				{ text = 'Player A', checkbox = 1, checked = true, iconStyle = 'player_baby'},
				{ text = 'Player B', checkbox = 1, checked = true, iconStyle = 'player_fab4'},
				{ text = 'Player C', checkbox = 1, iconStyle = 'player_receiver' },
				{ text = 'Player D', checkbox = 1, iconStyle = 'player_boom' },
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

	local window
	if data.special then

		-- any of the data.special methods need to return a full window spec and fill the window var with it
		if data.special == 'lineIn' then
			window = self:lineInWindow(data)
		end
	else
		window = Window(data.windowStyle or 'text_list', data.titleText)
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
	end

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
			iconStyle = item.iconStyle or nil,
		}
	)
end

function addRadioItem(self, item)
	self.menu:addItem(
		{	
                        text = item.text,
                        style = 'item_choice',
                        sound = "WINDOWSHOW",
			iconStyle = item.iconStyle or nil,
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
			iconStyle = item.iconStyle or nil,
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
			iconStyle = item.iconStyle or nil,
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


function lineInWindow(self, data)
        log:debug("line in window")

        local window = Window(data.windowStyle or 'linein')

        local titleGroup = Group('title', {
                --lbutton = window:createDefaultLeftButton(),
                text = Label("text", data.titleText),
                --rbutton = nil,
           })

        local artworkGroup = Group('npartwork', {
                        artwork = Icon(data.iconStyle),
        })

        local nptrackGroup = Group('nptitle', {
                nptrack = Label('nptrack', data.titleText ),
                xofy    = nil,
        })

        window:addWidget(titleGroup)
        window:addWidget(nptrackGroup)
        window:addWidget(artworkGroup)

	return window
end


