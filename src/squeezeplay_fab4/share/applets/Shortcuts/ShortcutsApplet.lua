--[[

Shortcuts applet

--]]

local string, ipairs, tostring, pairs = string, ipairs, tostring, pairs

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

local math                = require("math")
local debug               = require("jive.utils.debug")

local jiveMain      = jiveMain



module(..., Framework.constants)
oo.class(_M, Applet)


function _getOutputActionMap(self)
	if not self.outputActionMap then
		self.outputActionMap = {
			["back"]  = self:string("SHORTCUTS_OUTPUT_BACK"),
			["go_home"]  = self:string("SHORTCUTS_OUTPUT_GO_HOME"),
			["go_now_playing"]  = self:string("SHORTCUTS_OUTPUT_GO_NOW_PLAYING"),
			["go_playlist"]  = self:string("SHORTCUTS_OUTPUT_GO_PLAYLIST"),
		}
	end

	return self.outputActionMap

end

function _getInputMap(self)
	if not self.inputMap then
		self.inputMap = {
			actionActionMappings = {
				["title_left_press"]  = self:string("SHORTCUTS_INPUT_TITLE_TITLE_LEFT_PRESS"),
				["title_left_hold"]  = self:string("SHORTCUTS_INPUT_TITLE_TITLE_LEFT_HOLD"),
				["title_right_press"]  = self:string("SHORTCUTS_INPUT_TITLE_RIGHT_PRESS"),
				["title_right_hold"]  = self:string("SHORTCUTS_INPUT_TITLE_RIGHT_HOLD"),
			},
			gestureActionMappings = {
				[GESTURE_L_R] = self:string("SHORTCUTS_INPUT_GESTURE_L_R"),
				[GESTURE_R_L] = self:string("SHORTCUTS_INPUT_GESTURE_R_L"),
			},
		}

	end

	return self.inputMap

end

function _applySetting(self, settingTable)
	Framework:applyInputToActionOverridesToDestination(settingTable, self:getSettings())
	Framework:applyInputToActionOverrides(self:getSettings())

	self:storeSettings()
end

-- top level menu
function menu(self)
	local window = Window("text_list", self:string("SHORTCUTS_TITLE"))

	local menu = SimpleMenu("menu")
	menu:setComparator(SimpleMenu.itemComparatorAlpha)
	window:addWidget(menu)

	local items = {}
	for key, text in pairs(self:_getInputMap().actionActionMappings) do
		items[#items + 1] = {
					text = text,
					style = "item",
					callback =
						function ()
							self:outputActionSelectionWindow(text,
											self:getSettings().actionActionMappings[key],
											function(output)
												--build single membered table to merge
												local setting = {}
												setting.actionActionMappings = {}
												setting.actionActionMappings[key] = output
												self:_applySetting(setting)
											end)
						end,
				  }
	end

	for key, text in pairs(self:_getInputMap().gestureActionMappings) do
		items[#items + 1] = {
					text = text,
					style = "item",
					callback =
						function ()
							self:outputActionSelectionWindow(text,
											self:getSettings().gestureActionMappings[key],
											function(output)
												--build single membered table to merge
												local setting = {}
												setting.gestureActionMappings = {}
												setting.gestureActionMappings[key] = output
												self:_applySetting(setting)
											end)
						end,
				  }
	end


	menu:setItems(items)

	self:tieAndShowWindow(window)
	return window
end

function outputActionSelectionWindow(self, text, currentAction, callback)
	local window = Window("text_list", text)
	local menu = SimpleMenu("menu")
	menu:setComparator(SimpleMenu.itemComparatorAlpha)
	window:addWidget(menu)

	local items = {}
	for action, outputText in pairs(self:_getOutputActionMap()) do
		local outputItem = { text = outputText }

		if action == currentAction then
			outputItem.style = "item_checked"
		else
			outputItem.style = "item"
		end

		outputItem.callback =   function()
						callback(action)
						window:playSound("SELECT")
						window:hide()
					end
		
		items[#items + 1] = outputItem
	end

	menu:setItems(items)

	self:tieAndShowWindow(window)
	return window
end