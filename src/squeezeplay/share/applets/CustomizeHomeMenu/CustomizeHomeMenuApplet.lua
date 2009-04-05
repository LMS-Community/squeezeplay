
--[[
=head1 NAME

applets.CustomizeHomeMenu.CustomizeHomeMenuApplet - Customize Home Menu Applet

=head1 DESCRIPTION

This applet is to allow for a user to customize what items are displayed/hidden from the home menu

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 

=cut
--]]


-- stuff we use
local tostring, tonumber, pairs, ipairs, table = tostring, tonumber, pairs, ipairs, table
local oo                     = require("loop.simple")
local string                 = require("string")
local string                = require("jive.utils.string")
local table                  = require("jive.utils.table")

local Applet                 = require("jive.Applet")
local Checkbox               = require("jive.ui.Checkbox")
local Window                 = require("jive.ui.Window")
local Textarea               = require('jive.ui.Textarea')
local Framework              = require('jive.ui.Framework')

local SimpleMenu             = require("jive.ui.SimpleMenu")
local log                    = require("jive.utils.log").addCategory("customizeHome", jive.utils.log.DEBUG)

local debug                  = require("jive.utils.debug")
local jiveMain               = jiveMain
local appletManager          = appletManager
local jnt                    = jnt

module(..., Framework.constants)
oo.class(_M, Applet)

-- FIXME: this method should be farmed out to SimpleMenu as a function called from _itemRenderer()
-- _indent
-- returns a string of <size> spaces
local function _indent(indentSize)
	local indent = ''
	if not indentSize then
		return indent
	end
	for i = 1, tonumber(indentSize) do
		indent = tostring(indent) .. ' '
	end
	return indent
end

function menu(self, menuItem)

	log:info("menu")
	self.currentSettings = self:getSettings()

	-- get the menu table from jiveMain
	self.menuTable = jiveMain:getMenuTable()
	-- get items that have been customized
	--local customTable = jiveMain:getCustomTable()

	-- get the nodes. these become the choices + hidden
	self.nodeTable = jiveMain:getNodeTable()

	local homeMenuItems = {}
	
	-- add an entry for returning everything to defaults
	table.insert(homeMenuItems,
		{
			text = self:string('CUSTOMIZE_RESTORE_DEFAULTS'),
			weights = { 1001 },
			callback = function()
				self:restoreDefaultsMenu()
			end
		}
	)


	for id, item in pairs(self.menuTable) do
		if id ~= 'hidden'
			and id ~= 'nowhere'
			-- a small hack to make sounds/effects not appear twice
			and id ~= 'opmlsounds'
			then
			
		local title, selected

		local complexWeight = jiveMain:getComplexWeight(id, item)
		local weights = {}
		item.weights = string.split('%.', complexWeight, weights)

		-- if this is a home item and setting = 'hidden', then unselect
		if self.currentSettings[id] and self.currentSettings[id] == 'hidden' and item.node == 'home' then
			selected = false
		-- elseif setting = 'home' or item.node = 'home', then select
		elseif (self.currentSettings[id] and self.currentSettings[id] == 'home') or item.node == 'home' then
			selected = true
		-- anything else is unselect
		else
			selected = false
		end

		local indentSize = 0
		for i,v in ipairs(item.weights) do
			if i > 1 then
				indentSize = indentSize + 2
			end
		end
		local indent = _indent(indentSize)

		if item.node == 'home' then
			title = item.text
		elseif item.homeMenuToken then
			title = indent .. tostring(self:string(item.homeMenuToken))
		elseif item.homeMenuText then
			title = indent .. tostring(item.homeMenuText)
		else
			title = indent .. tostring(item.text)
		end
	
		if not item.weights[1] then
			item.weights = { 2 }
		end
		local menuItem
		if item.noCustom then
			menuItem = {
				text = title,
				weights = item.weights,
				indent = indentSize,
				style = 'item_no_arrow'
			}
		else
			menuItem = {
				text = title,
				weights = item.weights,
				indent = indentSize,
				style = 'item_choice',
				check = Checkbox(
					"checkbox",
					function(object, isSelected)
						if isSelected then
							if item.node == 'home' then
								self:getSettings()[item.id] = nil
								jiveMain:setNode(item, 'home')
							else
								self:getSettings()[item.id] = 'home'
								jiveMain:addItemToNode(item, 'home')
							end
						else
							if item.node == 'home' then
								self:getSettings()[item.id] = 'hidden'
								jiveMain:setNode(item, 'hidden')
							else
								self:getSettings()[item.id] = nil
								jiveMain:removeItemFromNode(item, 'home')
							end
						end
						self:storeSettings()
					end,
					selected
				),
			}
		end
		table.insert(homeMenuItems, menuItem)
		end
	end

	local menu = SimpleMenu("menu",  homeMenuItems  )
	menu:setComparator(menu.itemComparatorComplexWeightAlpha)

	local window = Window("text_list", self:string("CUSTOMIZE_HOME"), 'settingstitle')
	window:addWidget(menu)
	window:show()
end

function restoreDefaultsMenu(self, id)
	local window = Window("help_list", self:string("CUSTOMIZE_RESTORE_DEFAULTS"), 'settingstitle')
        local menu = SimpleMenu("menu", {
		{
			text = self:string("CUSTOMIZE_CANCEL"),
			sound = "WINDOWHIDE",
			callback = function()
				window:hide()
			end
		},
		{
			text = self:string("CUSTOMIZE_CONTINUE"),
			sound = "WINDOWSHOW",
			callback = function()
				local currentSettings = self:getSettings()
				for id, node in pairs(currentSettings) do
					self:getSettings()[id] = nil
					-- fetch item by id
					local item = jiveMain:getMenuItem(id)
					-- replace to original node, remove customNode
					if item then
						jiveMain:setNode(item, item.node)
					end
				end
				self:storeSettings()
				_goHome()
			end
		},
	})

	window:addWidget(Textarea("help_text", self:string("CUSTOMIZE_RESTORE_DEFAULTS_HELP")))
        window:addWidget(menu)
	window:show()
end

-- goHome
-- pushes the home window to the top
function _goHome()
	local windowStack = Framework.windowStack
	Framework:playSound("JUMP")
	while #windowStack > 1 do
		windowStack[#windowStack - 1]:hide()
	end
end


-- XXXX temporary:
function appGuide(self)
	local settings = self:getSettings()
	local menuTable = jiveMain:getMenuTable()

	local appGuideItems = {}

	for id, item in pairs(menuTable) do
		if item.guide then
			local selected
			if settings[id] then
				selected = (settings[id] == 'home')
			else
				selected = (item.node == 'home')
			end

			appGuideItems[#appGuideItems + 1] = {
				text = item.text,
				icon = item.icon,
				style = 'item_choice',
				check = Checkbox(
					"checkbox",
					function(object, isSelected)
						if isSelected then
							settings[item.id] = 'home'
							jiveMain:addItemToNode(item, 'home')
						else
							self:getSettings()[item.id] = 'hidden'
							jiveMain:removeItemFromNode(item, 'home')
						end
						self:storeSettings()
					end,
					selected)
				}
		end
	end


	local menu = SimpleMenu("menu",  appGuideItems  )
	menu:setComparator(menu.itemComparatorAlpha)

	local window = Window("text_list", self:string("APP_GUIDE"), 'settingstitle')
	window:addWidget(menu)
	window:show()
end
