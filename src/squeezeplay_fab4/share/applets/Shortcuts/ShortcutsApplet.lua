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
local table                  = require("jive.utils.table")

local math                = require("math")
local debug               = require("jive.utils.debug")

local jiveMain      = jiveMain



module(..., Framework.constants)
oo.class(_M, Applet)


function _getOutputActionMap(self)
	if not self.outputActionMap then
		self.outputActionMap = {
			["back"]               = {text = self:string("SHORTCUTS_OUTPUT_BACK"), showOnPrimary = true, weight = 1},
			["go_home"]            = {text = self:string("SHORTCUTS_OUTPUT_GO_HOME"), showOnPrimary = true, weight = 2},
			["go_now_playing"]     = {text = self:string("SHORTCUTS_OUTPUT_GO_NOW_PLAYING"), showOnPrimary = true, weight = 3},
			["go_playlist"]        = {text = self:string("SHORTCUTS_OUTPUT_GO_PLAYLIST"), showOnPrimary = true, weight = 4},
			["go_favorites"]       = {text = self:string("SHORTCUTS_OUTPUT_GO_FAVORITES"), showOnPrimary = false, weight = 5},
			["power"]              = {text = self:string("SHORTCUTS_OUTPUT_POWER"), showOnPrimary = true, weight = 6},
			["disabled"]           = {text = self:string("SHORTCUTS_OUTPUT_DISABLED"), showOnPrimary = true, weight = 7},
		}
	end

	return self.outputActionMap

end

function _getInputMap(self)
	if not self.inputMap then
		self.inputMap = {
			actionActionMappings = {
				["title_left_press"]       = {text = self:string("SHORTCUTS_INPUT_TITLE_TITLE_LEFT_PRESS"), isPrimary = true, weight = 1},
				["title_left_hold"]        = {text = self:string("SHORTCUTS_INPUT_TITLE_TITLE_LEFT_HOLD"), isPrimary = false, weight = 2},
				["title_right_press"]      = {text = self:string("SHORTCUTS_INPUT_TITLE_RIGHT_PRESS"), isPrimary = true, weight = 3},
				["title_right_hold"]       = {text = self:string("SHORTCUTS_INPUT_TITLE_RIGHT_HOLD"), isPrimary = false, weight = 4},
				["home_title_left_press"]  = {text = self:string("SHORTCUTS_INPUT_HOME_TITLE_LEFT_PRESS"), isPrimary = true, weight = 5},
				["home_title_left_hold"]   = {text = self:string("SHORTCUTS_INPUT_HOME_TITLE_LEFT_HOLD"), isPrimary = false, weight = 6},
			},
			gestureActionMappings = {
				[GESTURE_L_R]            = {text = self:string("SHORTCUTS_INPUT_GESTURE_L_R"), isPrimary = false, weight = 7},
				[GESTURE_R_L]            = {text = self:string("SHORTCUTS_INPUT_GESTURE_R_L"), isPrimary = false, weight = 8},
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


function _getOutputActionBySelectedIndex(self, selectedIndex, isPrimary)
	local i = 1
	for action, outputWrapper in table.pairsByKeys(self:_getOutputActionMap()) do
		if outputWrapper.showOnPrimary or not isPrimary then
			log:warn("isPrimary : ", isPrimary )

			if i == selectedIndex then
				return action
			end
			i = i + 1
		end
	end
end

-- top level menu
function menu(self)
	local window = Window("text_list", self:string("SHORTCUTS_TITLE"))

	local menu = SimpleMenu("menu")
	menu:setComparator(SimpleMenu.itemComparatorWeightAlpha)
	window:addWidget(menu)

	local items = {}

--keeping here for a bit since I believe we will go back to this
--	for key, inputWrapper in pairs(self:_getInputMap().actionActionMappings) do
--		items[#items + 1] = {
--					text = tostring(inputWrapper.text) .. " (" .. tostring(self:_getOutputActionMap()[Framework.inputToActionMap.actionActionMappings[key]]["text"]) ..")",
--					weight = inputWrapper.weight,
--					style = "item",
--					callback =
--						function ()
--							self:outputActionSelectionWindow(inputWrapper,
--											self:getSettings().actionActionMappings[key],
--											function(output)
--												--build single membered table to merge
--												local setting = {}
--												setting.actionActionMappings = {}
--												setting.actionActionMappings[key] = output
--												self:_applySetting(setting)
--											end)
--						end,
--				  }
--	end

	for key, inputWrapper in pairs(self:_getInputMap().actionActionMappings) do

		--get current text from the "source" since local defautl settings might not have it when new output choices are added.
		local currentText = tostring(self:_getOutputActionMap()[Framework.inputToActionMap.actionActionMappings[key]]["text"])
		local currentSelectedIndex = 1
		local outputTextTable = {}
		local i = 1
		for action, outputWrapper in table.pairsByKeys(self:_getOutputActionMap()) do
			if outputWrapper.showOnPrimary or not inputWrapper.isPrimary then
				outputTextTable[#outputTextTable + 1] = outputWrapper.text

				if tostring(currentText) == tostring(outputWrapper.text) then
					currentSelectedIndex = i
				end
				i = i + 1
			end
		end

		items[#items + 1] = {
					text = inputWrapper.text,
					weight = inputWrapper.weight,
					style = "item_choice",
					check = Choice(
					       "choice",
					       outputTextTable,
					       function(obj, selectedIndex)
							--build single membered table to merge
							local setting = {}
							setting.actionActionMappings = {}
							setting.actionActionMappings[key] = self:_getOutputActionBySelectedIndex(selectedIndex, inputWrapper.isPrimary)
							self:_applySetting(setting)

						        log:debug("Choice updated: ", tostring(selectedIndex)," - ", tostring(obj:getSelected()))
					       end,
					       currentSelectedIndex
				       )
				  }
	end

	for key, inputWrapper in pairs(self:_getInputMap().gestureActionMappings) do
		--get current text from the "source" since local defautl settings might not have it when new output choices are added.
		local currentText = tostring(self:_getOutputActionMap()[Framework.inputToActionMap.gestureActionMappings[key]]["text"])
		local currentSelectedIndex = 1
		local outputTextTable = {}
		local i = 1
		for action, outputWrapper in table.pairsByKeys(self:_getOutputActionMap()) do
			if outputWrapper.showOnPrimary or not inputWrapper.isPrimary then
				outputTextTable[#outputTextTable + 1] = outputWrapper.text

				if tostring(currentText) == tostring(outputWrapper.text) then
					currentSelectedIndex = i
				end
				i = i + 1
			end
		end

		items[#items + 1] = {
					text = inputWrapper.text,
					weight = inputWrapper.weight,
					style = "item_choice",
					check = Choice(
					       "choice",
					       outputTextTable,
					       function(obj, selectedIndex)
							--build single membered table to merge
							local setting = {}
							setting.gestureActionMappings = {}
							setting.gestureActionMappings[key] = self:_getOutputActionBySelectedIndex(selectedIndex, inputWrapper.isPrimary)
							self:_applySetting(setting)

						        log:debug("Choice updated: ", tostring(selectedIndex)," - ", tostring(obj:getSelected()))
					       end,
					       currentSelectedIndex
				       )
				  }
	end

--keeping here for a bit since I believe we will go back to this
--	for key, inputWrapper in pairs(self:_getInputMap().gestureActionMappings) do
--		items[#items + 1] = {
--					text = tostring(inputWrapper.text) .. " (" .. tostring(self:_getOutputActionMap()[Framework.inputToActionMap.gestureActionMappings[key]]["text"]) ..")",
--					weight = inputWrapper.weight,
--					style = "item",
--					callback =
--						function ()
--							self:outputActionSelectionWindow(inputWrapper,
--											self:getSettings().gestureActionMappings[key],
--											function(output)
--												--build single membered table to merge
--												local setting = {}
--												setting.gestureActionMappings = {}
--												setting.gestureActionMappings[key] = output
--												self:_applySetting(setting)
--											end)
--						end,
--				  }
--	end


	menu:setItems(items)

	self:tieAndShowWindow(window)
	return window
end

--keeping here for a bit since I believe we will go back to this
--function outputActionSelectionWindow(self, inputWrapper, currentAction, callback)
--	local window = Window("text_list", inputWrapper.text)
--	local menu = SimpleMenu("menu")
--	menu:setComparator(SimpleMenu.itemComparatorWeightAlpha)
--	window:addWidget(menu)
--
--	local items = {}
--	for action, outputWrapper in pairs(self:_getOutputActionMap()) do
--		if outputWrapper.showOnPrimary or not inputWrapper.isPrimary then
--			--some output shouldn't be offered as primary (generally press) button choices (because we don't have button icons for them and they are fairly impractical for the user)
--			local outputMenuItem = { text = outputWrapper.text, weight = outputWrapper.weight }
--
--			if action == currentAction then
--				outputMenuItem.style = "item_checked"
--			else
--				outputMenuItem.style = "item"
--			end
--
--			outputMenuItem.callback =   function()
--							callback(action)
--							window:playSound("SELECT")
--							window:hide()
--						end
--
--			items[#items + 1] = outputMenuItem
--		end
--	end
--
--	menu:setItems(items)
--
--	self:tieAndShowWindow(window)
--	return window
--end