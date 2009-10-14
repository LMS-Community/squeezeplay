--[[

Experiments applet.

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

local math                = require("math")
local debug               = require("jive.utils.debug")

local jiveMain      = jiveMain
--local contextMenuManager  = contextMenuManager


module(..., Framework.constants)
oo.class(_M, Applet)


if Framework.experiments_multiTapOn == nil then
	Framework.experiments_multiTapOn = false

	--really getting hacky now, holding mouse state in the globals
	Framework.experiments_multiTapMouseDownPt = {}

end

-- top level menu
function menu(self)
	local window = Window("text_list", "UI Experiments")

	local menu = SimpleMenu("menu",
		{
--			{ text = "Menu with CM items",
--				sound = "WINDOWSHOW",
--				callback = function(event, menuItem)
--					self:menuWindow(menuItem)
--				end },
			{ text = "2+ finger: tap to NP, T-B pause, L-R fwd, R-L rew anywhere",
				style = 'item_choice',
				check  = Checkbox(
						"checkbox",
						function(_, enable)
							Framework.experiments_multiTapOn = enable
							log:error("Switching experiments_multiTapOn to: ", Framework.experiments_multiTapOn)

							if Framework.experiments_multiTapOn then
								if Framework.experiments_multiTapListener then
									Framework:removeListener(Framework.experiments_multiTapListener)
								end
								Framework.experiments_multiTapListener = Framework:addListener(EVENT_MOUSE_ALL,
									function(event)

										local x, y, fingerCount = event:getMouse()

										if event:getType() == EVENT_MOUSE_UP then
											if Framework.experiments_multiTapMouseDownPt.y then
												--A point was collected on the down so is a multi-tap
												local deltaY = y - Framework.experiments_multiTapMouseDownPt.y
												local deltaX = x - Framework.experiments_multiTapMouseDownPt.x

												log:error("deltaY : ", deltaY )
												if deltaY >= 100 and math.abs(deltaX) < 120 then
													Framework:pushAction("pause")

												elseif deltaX >= 150 then
													Framework:pushAction("jump_fwd")

												elseif deltaX <= -150 then
													Framework:pushAction("jump_rew")

												else
													Framework:pushAction("go_now_playing")
												end
												Framework.experiments_multiTapMouseDownPt = {}
												return EVENT_CONSUME
											end

											return EVENT_UNUSED
										end

										if not fingerCount or fingerCount < 2 then
											return EVENT_UNUSED
										end

										if event:getType() == EVENT_MOUSE_DOWN then
											Framework.experiments_multiTapMouseDownPt = {x = x, y = y}
--											Framework:pushAction("go_now_playing")
										end

										--Might be nice to handle case where a single finger goes down then a second comes,
										 -- would require watching the DRAG and probably the UP. Maybe synaptics multifinger detection is good enough to make this extra check not needed.
										return EVENT_CONSUME
									end,
									-100)

							else
								if Framework.experiments_multiTapListener then
									Framework:removeListener(Framework.experiments_multiTapListener)
								end
							end
						end,
						Framework.experiments_multiTapOn == true
				),
			},
		})

	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end

function menuWindow(self, menuItem, style)
	local itemStyle, menuStyle
	if not style then
		menuStyle = 'menu'
		itemStyle = 'item'
	else
		menuStyle = style .. "menu"
		itemStyle = style .. "item"
	end
	local window = Window("text_list", menuItem.text)

	--use global contextMenuManager. Using contextMenuManager suggests that that applet wants to expose its
	-- context menu to other applet to subscriber to.
	--If an applet doesn't intend to expose it CM's, it can put self isntead of contextMenuManager, and implement showContextMenu(self, item, menu, window)
	local menu = SimpleMenu(menuStyle, nil, contextMenuManager)
	window:addWidget(menu)

	local items = {}
	for i=1,2 do
		items[#items + 1] = { 
			text = "Artist  " .. i,
			style = "item",
			contextMenuType = "uiExperiments",
		}
	end

	menu:setItems(items)

	self:tieAndShowWindow(window)
	return window
end


function addMenuWindowContextMenuItems(self, menu, list, itemWidget, menuIndex)
	log:error("menu, list, itemWidget, menuIndex: ", menu, list, itemWidget, menuIndex)

	local items = {}
	items[#items + 1] = {
		text = "Play next",
		style = "item",
		}
	items[#items + 1] = {
		text = "Play now",
		style = "item",
		}
	items[#items + 1] = {
		text = "Play at end",
		style = "item",
		}

	return items
end

--function init(self)
--	self.addMenuWindowContextMenuItemsHandle = contextMenuManager:subscribe("uiExperiments", self, addMenuWindowContextMenuItems)
--end
--
--function free(self)
--	contextMenuManager:unsubscribe(self.addMenuWindowContextMenuItemsHandle)
--
--	return true
--end
