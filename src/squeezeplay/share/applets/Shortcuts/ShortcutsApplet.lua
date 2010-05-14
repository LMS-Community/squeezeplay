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
local table               = require("jive.utils.table")
local System              = require("jive.System")

local math                = require("math")
local debug               = require("jive.utils.debug")

local jiveMain      = jiveMain



module(..., Framework.constants)
oo.class(_M, Applet)


function _getOutputActionMap(self)
	if not self.outputActionMap then
		self.outputActionMap = {
			["back"]               = {text = self:string("SHORTCUTS_OUTPUT_BACK"), offerOn = {"touch", "touchPrimary", "ir", "keys"} , weight = 10},
			["go_home"]            = {text = self:string("SHORTCUTS_OUTPUT_GO_HOME"), offerOn = {"touch", "touchPrimary", "ir", "keys"}, weight = 20},
			["go_now_playing_or_playlist"]     = {text = self:string("SHORTCUTS_OUTPUT_GO_NOW_PLAYING"), offerOn = {"touch", "touchPrimary", "ir", "keys"}, weight = 30},
			["go_playlist"]        = {text = self:string("SHORTCUTS_OUTPUT_GO_PLAYLIST"), offerOn = {"touch", "touchPrimary", "ir", "keys"}, weight = 40},
			["disabled"]           = {text = self:string("SHORTCUTS_OUTPUT_DISABLED"), offerOn = {"touch", "touchPrimary", "ir", "keys"}, weight = 200},
			["go_alarms"]       = {text = self:string("SHORTCUTS_OUTPUT_GO_ALARMS"), offerOn = {"touch", "ir", "keys"}, weight = 50},
			["go_favorites"]       = {text = self:string("SHORTCUTS_OUTPUT_GO_FAVORITES"), offerOn = {"touch", "ir", "keys"}, weight = 50},
			["go_brightness"]      = {text = self:string("SHORTCUTS_OUTPUT_GO_BRIGHTNESS"), offerOn = {"touch", "ir", "keys"}, weight = 65},
			["go_settings"]      = {text = self:string("SHORTCUTS_OUTPUT_SETTINGS"), offerOn = {"touch", "ir", "keys"}, weight = 65},
			["mute"]               = {text = self:string("SHORTCUTS_OUTPUT_MUTE"), offerOn = {"touch", "ir", "keys"}, weight = 80},
			["pause"]              = {text = self:string("SHORTCUTS_OUTPUT_PAUSE"), offerOn = {"touch", "ir", "keys"}, weight = 90},
			["stop"]               = {text = self:string("SHORTCUTS_OUTPUT_STOP"), offerOn = {"touch", "ir", "keys"}, weight = 90},
			["sleep"]              = {text = self:string("SHORTCUTS_OUTPUT_SLEEP"), offerOn = {"touch", "ir", "keys"}, weight = 90},
			["create_mix"]              = {text = self:string("SHORTCUTS_OUTPUT_CREATE_MIX"), offerOn = {"touch", "ir", "keys"}, weight = 90},
			["add"]              = {text = self:string("SHORTCUTS_OUTPUT_MORE"), offerOn = {"touch", "ir", "keys"}, weight = 90},
			["add_end"]              = {text = self:string("SHORTCUTS_OUTPUT_ADD_END"), offerOn = {"touch", "ir", "keys"}, weight = 90},
			["play_preset_1"]              = {text = self:string("SHORTCUTS_OUTPUT_PLAY_PRESET", 1), offerOn = {"touch", "ir", "keys"}, weight = 91},
			["play_preset_2"]              = {text = self:string("SHORTCUTS_OUTPUT_PLAY_PRESET", 2), offerOn = {"touch", "ir", "keys"}, weight = 91},
			["play_preset_3"]              = {text = self:string("SHORTCUTS_OUTPUT_PLAY_PRESET", 3), offerOn = {"touch", "ir", "keys"}, weight = 91},
			["play_preset_4"]              = {text = self:string("SHORTCUTS_OUTPUT_PLAY_PRESET", 4), offerOn = {"touch", "ir", "keys"}, weight = 91},
			["play_preset_5"]              = {text = self:string("SHORTCUTS_OUTPUT_PLAY_PRESET", 5), offerOn = {"touch", "ir", "keys"}, weight = 91},
			["play_preset_6"]              = {text = self:string("SHORTCUTS_OUTPUT_PLAY_PRESET", 6), offerOn = {"touch", "ir", "keys"}, weight = 91},
--			["play_preset_7"]              = {text = self:string("SHORTCUTS_OUTPUT_PLAY_PRESET", 7), offerOn = {"touch", "ir", "keys"}, weight = 91},
--			["play_preset_8"]              = {text = self:string("SHORTCUTS_OUTPUT_PLAY_PRESET", 8), offerOn = {"touch", "ir", "keys"}, weight = 91},
--			["play_preset_9"]              = {text = self:string("SHORTCUTS_OUTPUT_PLAY_PRESET", 9), offerOn = {"touch", "ir", "keys"}, weight = 91},
--			["play_preset_0"]              = {text = self:string("SHORTCUTS_OUTPUT_PLAY_PRESET", 10), offerOn = {"touch", "ir", "keys"}, weight = 92},
			["set_preset_1"]              = {text = self:string("SHORTCUTS_OUTPUT_SET_PRESET", 1), offerOn = {"touch", "ir", "keys"}, weight = 93},
			["set_preset_2"]              = {text = self:string("SHORTCUTS_OUTPUT_SET_PRESET", 2), offerOn = {"touch", "ir", "keys"}, weight = 93},
			["set_preset_3"]              = {text = self:string("SHORTCUTS_OUTPUT_SET_PRESET", 3), offerOn = {"touch", "ir", "keys"}, weight = 93},
			["set_preset_4"]              = {text = self:string("SHORTCUTS_OUTPUT_SET_PRESET", 4), offerOn = {"touch", "ir", "keys"}, weight = 93},
			["set_preset_5"]              = {text = self:string("SHORTCUTS_OUTPUT_SET_PRESET", 5), offerOn = {"touch", "ir", "keys"}, weight = 93},
			["set_preset_6"]              = {text = self:string("SHORTCUTS_OUTPUT_SET_PRESET", 6), offerOn = {"touch", "ir", "keys"}, weight = 93},
----			["set_preset_7"]              = {text = self:string("SHORTCUTS_OUTPUT_SET_PRESET", 7), offerOn = {"touch", "ir", "keys"}, weight = 93},
----			["set_preset_8"]              = {text = self:string("SHORTCUTS_OUTPUT_SET_PRESET", 8), offerOn = {"touch", "ir", "keys"}, weight = 93},
----			["set_preset_9"]              = {text = self:string("SHORTCUTS_OUTPUT_SET_PRESET", 9), offerOn = {"touch", "ir", "keys"}, weight = 93},
----			["set_preset_0"]              = {text = self:string("SHORTCUTS_OUTPUT_SET_PRESET", 10), offerOn = {"touch", "ir", "keys"}, weight = 94},
--			["0"]                  = {text = "0", offerOn = {"ir"}, weight = 90},
--			["1"]                  = {text = "1", offerOn = {"ir"}, weight = 90},
--			["2"]                  = {text = "2", offerOn = {"ir"}, weight = 90},
--			["3"]                  = {text = "3", offerOn = {"ir"}, weight = 90},
--			["4"]                  = {text = "4", offerOn = {"ir"}, weight = 90},
--			["5"]                  = {text = "5", offerOn = {"ir"}, weight = 90},
--			["6"]                  = {text = "6", offerOn = {"ir"}, weight = 90},
--			["7"]                  = {text = "7", offerOn = {"ir"}, weight = 90},
--			["8"]                  = {text = "8", offerOn = {"ir"}, weight = 90},
--			["9"]                  = {text = "9", offerOn = {"ir"}, weight = 90},
			["text_mode"]          = {text = self:string("SHORTCUTS_OUTPUT_TEXT_MODE", 6), offerOn = {"touch", "ir", "keys"}, weight = 94},
			["go_search"]          = {text = self:string("SHORTCUTS_OUTPUT_SEARCH", 6), offerOn = {"touch", "ir", "keys"}, weight = 94},
		}
		if System:hasTouch() then
			self.outputActionMap["power"]  = {text = self:string("SHORTCUTS_OUTPUT_POWER"), offerOn = {"touch", "touchPrimary", "ir", "keys"}, weight = 60}
		end
	
	end
	return self.outputActionMap

end

function getOutputActionMapSortedPairs(self)
	return table.pairsByValues(self:_getOutputActionMap(), SimpleMenu.itemComparatorKeyWeightAlpha)
end

function _getInputMap(self)
	if not self.inputMap then
		self.inputMap = {}
		if System:hasTouch() then
			self.inputMap.actionActionMappings = {
				["title_left_press"]       = {text = self:string("SHORTCUTS_INPUT_TITLE_TITLE_LEFT_PRESS"), isPrimary = true, weight = 1},
				["title_left_hold"]        = {text = self:string("SHORTCUTS_INPUT_TITLE_TITLE_LEFT_HOLD"), isPrimary = false, weight = 2},
				["title_right_press"]      = {text = self:string("SHORTCUTS_INPUT_TITLE_RIGHT_PRESS"), isPrimary = true, weight = 3},
				["title_right_hold"]       = {text = self:string("SHORTCUTS_INPUT_TITLE_RIGHT_HOLD"), isPrimary = false, weight = 4},
				["home_title_left_press"]  = {text = self:string("SHORTCUTS_INPUT_HOME_TITLE_LEFT_PRESS"), isPrimary = true, weight = 5},
				["home_title_left_hold"]   = {text = self:string("SHORTCUTS_INPUT_HOME_TITLE_LEFT_HOLD"), isPrimary = false, weight = 6},
			}
			self.inputMap.gestureActionMappings = {
				[GESTURE_L_R]            = {text = self:string("SHORTCUTS_INPUT_GESTURE_L_R"), isPrimary = false, weight = 7},
				[GESTURE_R_L]            = {text = self:string("SHORTCUTS_INPUT_GESTURE_R_L"), isPrimary = false, weight = 8},
			}
		end
		
		if System:hasIr() then
			self.inputMap.irActionMappings = {
				press = {
					["add"]  = {text = self:string("SHORTCUTS_INPUT_IR_PRESS", "MORE"),  weight = 41},
					["sleep"]  = {text = self:string("SHORTCUTS_INPUT_IR_PRESS", "SLEEP"),  weight = 45},
				} ,
				hold = {
					["play"]  = {text = self:string("SHORTCUTS_INPUT_IR_HOLD", "PLAY"),  weight = 40},
					["add"]  = {text = self:string("SHORTCUTS_INPUT_IR_HOLD", "MORE"),  weight = 41},
					["arrow_right"]  = {text = self:string("SHORTCUTS_INPUT_IR_HOLD", "RIGHT"),  weight = 42},
					["pause"]  = {text = self:string("SHORTCUTS_INPUT_IR_HOLD", "PAUSE"),  weight = 43},
					["home"]  = {text = self:string("SHORTCUTS_INPUT_IR_HOLD", "HOME"),  weight = 44},
					["sleep"]  = {text = self:string("SHORTCUTS_INPUT_IR_HOLD", "SLEEP"),  weight = 45},
					["0"]  = {text = self:string("SHORTCUTS_INPUT_IR_HOLD", "0"),  weight = 50},
					["1"]  = {text = self:string("SHORTCUTS_INPUT_IR_HOLD", "1"),  weight = 50},
					["2"]  = {text = self:string("SHORTCUTS_INPUT_IR_HOLD", "2"),  weight = 50},
					["3"]  = {text = self:string("SHORTCUTS_INPUT_IR_HOLD", "3"),  weight = 50},
					["4"]  = {text = self:string("SHORTCUTS_INPUT_IR_HOLD", "4"),  weight = 50},
					["5"]  = {text = self:string("SHORTCUTS_INPUT_IR_HOLD", "5"),  weight = 50},
					["6"]  = {text = self:string("SHORTCUTS_INPUT_IR_HOLD", "6"),  weight = 50},
					["7"]  = {text = self:string("SHORTCUTS_INPUT_IR_HOLD", "7"),  weight = 50},
					["8"]  = {text = self:string("SHORTCUTS_INPUT_IR_HOLD", "8"),  weight = 50},
					["9"]  = {text = self:string("SHORTCUTS_INPUT_IR_HOLD", "9"),  weight = 50},
				} 
			}
		end
		
		if System:hasCoreKeys() then
			self.inputMap.keyActionMappings = {
				press = {
					[KEY_ADD] = {text = self:string("SHORTCUTS_INPUT_KEY_PRESS", "MORE"),  weight = 31},
				},
				hold = {
					[KEY_GO] = {text = self:string("SHORTCUTS_INPUT_KEY_HOLD", "GO/RIGHT"),  weight = 31},
					[KEY_ADD] = {text = self:string("SHORTCUTS_INPUT_KEY_HOLD", "MORE"),  weight = 31},
					[KEY_PLAY] = {text = self:string("SHORTCUTS_INPUT_KEY_HOLD", "PLAY"),  weight = 31},
				},
			}
			if System:hasPresetKeys() then
				self.inputMap.keyActionMappings.press[KEY_PRESET_1] = {text = self:string("SHORTCUTS_INPUT_KEY_PRESET_PRESS", "1"),  weight = 31} 
				self.inputMap.keyActionMappings.press[KEY_PRESET_2] = {text = self:string("SHORTCUTS_INPUT_KEY_PRESET_PRESS", "2"),  weight = 31} 
				self.inputMap.keyActionMappings.press[KEY_PRESET_3] = {text = self:string("SHORTCUTS_INPUT_KEY_PRESET_PRESS", "3"),  weight = 31} 
				self.inputMap.keyActionMappings.press[KEY_PRESET_4] = {text = self:string("SHORTCUTS_INPUT_KEY_PRESET_PRESS", "4"),  weight = 31} 
				self.inputMap.keyActionMappings.press[KEY_PRESET_5] = {text = self:string("SHORTCUTS_INPUT_KEY_PRESET_PRESS", "5"),  weight = 31} 
				self.inputMap.keyActionMappings.press[KEY_PRESET_6] = {text = self:string("SHORTCUTS_INPUT_KEY_PRESET_PRESS", "6"),  weight = 31} 
	
				self.inputMap.keyActionMappings.hold[KEY_PRESET_1] = {text = self:string("SHORTCUTS_INPUT_KEY_PRESET_HOLD", "1"),  weight = 32} 
				self.inputMap.keyActionMappings.hold[KEY_PRESET_2] = {text = self:string("SHORTCUTS_INPUT_KEY_PRESET_HOLD", "2"),  weight = 32} 
				self.inputMap.keyActionMappings.hold[KEY_PRESET_3] = {text = self:string("SHORTCUTS_INPUT_KEY_PRESET_HOLD", "3"),  weight = 32} 
				self.inputMap.keyActionMappings.hold[KEY_PRESET_4] = {text = self:string("SHORTCUTS_INPUT_KEY_PRESET_HOLD", "4"),  weight = 32} 
				self.inputMap.keyActionMappings.hold[KEY_PRESET_5] = {text = self:string("SHORTCUTS_INPUT_KEY_PRESET_HOLD", "5"),  weight = 32} 
				self.inputMap.keyActionMappings.hold[KEY_PRESET_6] = {text = self:string("SHORTCUTS_INPUT_KEY_PRESET_HOLD", "6"),  weight = 32} 
			end
			if System:hasMuteKey() then
				self.inputMap.keyActionMappings.press[KEY_MUTE] = {text = self:string("SHORTCUTS_INPUT_KEY_PRESS", "MUTE"),  weight = 31}
				self.inputMap.keyActionMappings.hold[KEY_MUTE] = {text = self:string("SHORTCUTS_INPUT_KEY_HOLD", "MUTE"),  weight = 32}
			end
			if not System:hasHomeAsPowerKey() then
				self.inputMap.keyActionMappings.hold[KEY_HOME] = {text = self:string("SHORTCUTS_INPUT_KEY_HOLD", "HOME"),  weight = 32}
			end
			if System:hasAlarmKey() then
				self.inputMap.keyActionMappings.press[KEY_ALARM] = {text = self:string("SHORTCUTS_INPUT_KEY_PRESS", "ALARM"),  weight = 31}
				self.inputMap.keyActionMappings.hold[KEY_ALARM] = {text = self:string("SHORTCUTS_INPUT_KEY_HOLD", "ALARM"),  weight = 32}
			end
		end
	end

	return self.inputMap

end

function _applySetting(self, settingTable)
	log:warn("apply settings")

	Framework:applyInputToActionOverridesToDestination(settingTable, self:getSettings())
	Framework:applyInputToActionOverrides(self:getSettings())

	self:storeSettings()
end

function _resetSettings(self)
	--apply defaults, then clear settings
	self:_applySetting(Framework._inputToActionOverrideDefaults)
end

-- top level menu
function menu(self)
	local window = Window("text_list", self:string("SHORTCUTS_TITLE"))

	local menu = SimpleMenu("menu")

	local items = self:buildMainMenuItems()

	menu:setItems(items)
	menu:setComparator(SimpleMenu.itemComparatorWeightAlpha)

	window:addWidget(menu)

	self:tieAndShowWindow(window)
	
	--reload menu on update to pick up changes
	window:addListener(EVENT_WINDOW_ACTIVE,
			function ()
				items = self:buildMainMenuItems()
				menu:setItems(items)
				menu:setComparator(SimpleMenu.itemComparatorWeightAlpha)
				menu:reLayout()
			end
	)
	
	return window
end

function _addItem(self, items, inputMapping, defaultAction, isCustom, target, currentAction, newSettingTable, newSettingTableEntry, key, inputWrapper)
	local modifiedText = ""
	if isCustom then
		modifiedText = " " .. tostring(self:string("SHORTCUTS_MODIFIED"))
	end

	local currentOutput = self:_getOutputActionMap()[inputMapping]
	items[#items + 1] = {
				text = tostring(inputWrapper.text) .. modifiedText,
				weight = inputWrapper.weight,
				sound = "WINDOWSHOW",
				style = "item",
				callback =
					function ()
						self:outputActionSelectionWindow(inputWrapper,
										currentAction,
										function(output)
											--build single membered table to merge
											newSettingTableEntry[key] = output
											self:_applySetting(newSettingTable)
										end,
										target,
										defaultAction)
					end,
	  } 
end
 
 
function buildMainMenuItems(self)

	local items = {}

	if self:_getInputMap().actionActionMappings then
		for key, inputWrapper in pairs(self:_getInputMap().actionActionMappings) do
			local inputMapping = Framework.inputToActionMap.actionActionMappings[key]
			local defaultAction = Framework._inputToActionOverrideDefaults.actionActionMappings[key]
			local isCustom = (Framework._inputToActionOverrideDefaults.actionActionMappings[key] ~= inputMapping)
			local target = inputWrapper.isPrimary and "touchPrimary" or "touch"
			local currentAction = self:getSettings().actionActionMappings[key]
			local newSettingTable = {}
			newSettingTable.actionActionMappings = {}
			local newSettingTableEntry = newSettingTable.actionActionMappings
	
			self:_addItem(items, inputMapping, defaultAction, isCustom, target, currentAction, newSettingTable, newSettingTableEntry, key, inputWrapper)
		end
	
		for key, inputWrapper in pairs(self:_getInputMap().gestureActionMappings) do
			local inputMapping = Framework.inputToActionMap.gestureActionMappings[key]
			local defaultAction = Framework._inputToActionOverrideDefaults.gestureActionMappings[key]
			local isCustom = (Framework._inputToActionOverrideDefaults.gestureActionMappings[key] ~= inputMapping)
			local target = "touch"
			local currentAction = self:getSettings().gestureActionMappings[key]
			local newSettingTable = {}
			newSettingTable.gestureActionMappings = {}
			local newSettingTableEntry = newSettingTable.gestureActionMappings
	
			self:_addItem(items, inputMapping, defaultAction, isCustom, target, currentAction, newSettingTable, newSettingTableEntry, key, inputWrapper)
		end
	end
			
	if self:_getInputMap().irActionMappings then
		--user might have upgraded, so recreate these if needed
		if not self:getSettings().irActionMappings then
			self:getSettings().irActionMappings = {}
		end
		if not self:getSettings().irActionMappings.press then
			self:getSettings().irActionMappings.press = {}
		end
		if not self:getSettings().irActionMappings.hold then
			self:getSettings().irActionMappings.hold = {}
		end

		for key, inputWrapper in pairs(self:_getInputMap().irActionMappings.press) do
			local inputMapping = Framework.inputToActionMap.irActionMappings.press[key]
			local defaultAction = Framework._inputToActionOverrideDefaults.irActionMappings.press[key]
			local isCustom = (Framework._inputToActionOverrideDefaults.irActionMappings.press[key] ~= inputMapping)
			local target = "ir"
			local currentAction = self:getSettings().irActionMappings.press[key]
			local newSettingTable = {}
			newSettingTable.irActionMappings = {}
			newSettingTable.irActionMappings.press = {}
			local newSettingTableEntry = newSettingTable.irActionMappings.press
	
			self:_addItem(items, inputMapping, defaultAction, isCustom, target, currentAction, newSettingTable, newSettingTableEntry, key, inputWrapper)
		end
		for key, inputWrapper in pairs(self:_getInputMap().irActionMappings.hold) do
			local inputMapping = Framework.inputToActionMap.irActionMappings.hold[key]
			local defaultAction = Framework._inputToActionOverrideDefaults.irActionMappings.hold[key]
			local isCustom = (Framework._inputToActionOverrideDefaults.irActionMappings.hold[key] ~= inputMapping)
			local target = "ir"
			local currentAction = self:getSettings().irActionMappings.hold[key]
			local newSettingTable = {}
			newSettingTable.irActionMappings = {}
			newSettingTable.irActionMappings.hold = {}
			local newSettingTableEntry = newSettingTable.irActionMappings.hold
	
			self:_addItem(items, inputMapping, defaultAction, isCustom, target, currentAction, newSettingTable, newSettingTableEntry, key, inputWrapper)
		end
	end

	if self:_getInputMap().keyActionMappings then
		for key, inputWrapper in pairs(self:_getInputMap().keyActionMappings.press) do
			local inputMapping = Framework.inputToActionMap.keyActionMappings.press[key]
			local defaultAction = Framework._inputToActionOverrideDefaults.keyActionMappings.press[key]
			local isCustom = (Framework._inputToActionOverrideDefaults.keyActionMappings.press[key] ~= inputMapping)
			local target = "keys"
			local currentAction = self:getSettings().keyActionMappings.press[key]
			local newSettingTable = {}
			newSettingTable.keyActionMappings = {}
			newSettingTable.keyActionMappings.press = {}
			local newSettingTableEntry = newSettingTable.keyActionMappings.press
	
			self:_addItem(items, inputMapping, defaultAction, isCustom, target, currentAction, newSettingTable, newSettingTableEntry, key, inputWrapper)
		end

		for key, inputWrapper in pairs(self:_getInputMap().keyActionMappings.hold) do
			local inputMapping = Framework.inputToActionMap.keyActionMappings.hold[key]
			local defaultAction = Framework._inputToActionOverrideDefaults.keyActionMappings.hold[key]
			local isCustom = (Framework._inputToActionOverrideDefaults.keyActionMappings.hold[key] ~= inputMapping)
			local target = "keys"
			local currentAction = self:getSettings().keyActionMappings.hold[key]
			local newSettingTable = {}
			newSettingTable.keyActionMappings = {}
			newSettingTable.keyActionMappings.hold = {}
			local newSettingTableEntry = newSettingTable.keyActionMappings.hold
	
			self:_addItem(items, inputMapping, defaultAction, isCustom, target, currentAction, newSettingTable, newSettingTableEntry, key, inputWrapper)
		end
	end

	-- add an entry for returning everything to defaults
	items[#items + 1] = {
			text = self:string('SHORTCUTS_RESTORE_DEFAULTS'),
			weight = 2000,
			callback = function()
				self:restoreDefaultsMenu()
			end
	} 

	return items
end

--keeping here for a bit since I believe we will go back to this
function outputActionSelectionWindow(self, inputWrapper, currentAction, callback, target, defaultAction)
	local window = Window("text_list", inputWrapper.text)
	local menu = SimpleMenu("menu")
	menu:setComparator(SimpleMenu.itemComparatorWeightAlpha)
	window:addWidget(menu)

	local items = {}
	for action, outputWrapper in pairs(self:_getOutputActionMap()) do
		if table.contains(outputWrapper.offerOn, target) then
			--some output shouldn't be offered as primary (generally press) button choices (because we don't have button icons for them and they are fairly impractical for the user)
			local text = outputWrapper.text
			if defaultAction == action then
				text = tostring(text) .. " " .. tostring(self:string("SHORTCUTS_DEFAULT"))
			end
			local outputMenuItem = { text = text, weight = outputWrapper.weight }

			if action == currentAction then
				outputMenuItem.style = "item_checked"
			else
				outputMenuItem.style = "item"
			end

			outputMenuItem.callback =   function()
							callback(action)
							window:playSound("SELECT")
							window:hide()
						end

			items[#items + 1] = outputMenuItem
		end
	end

	menu:setItems(items)

	self:tieAndShowWindow(window)
	return window
end


function restoreDefaultsMenu(self, id)
	local window = Window("help_list", self:string("SHORTCUTS_RESTORE_DEFAULTS"), 'settingstitle')
        local menu = SimpleMenu("menu", {
		{
			text = self:string("SHORTCUTS_CANCEL"),
			sound = "WINDOWHIDE",
			callback = function()
				window:hide()
			end
		},
		{
			text = self:string("SHORTCUTS_CONTINUE"),
			sound = "WINDOWSHOW",
			callback = function()
				self:_resetSettings()
				window:hide()
			end
		},
	})

	menu:setHeaderWidget(Textarea("help_text", self:string("SHORTCUTS_RESTORE_DEFAULTS_HELP")))
        window:addWidget(menu)
	window:show()
end
