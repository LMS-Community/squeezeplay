
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
local tostring, pairs, table = tostring, pairs, table
local oo                     = require("loop.simple")
local string                 = require("string")
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

module(...)
oo.class(_M, Applet)


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
			weight = 100,
			callback = function()
				self:restoreDefaultsMenu()
			end
		}
	)

	for id, item in pairs(self.menuTable) do
		if id ~= 'hidden' and
			id ~= 'nowhere' and
			id ~= 'settings' and
			not item.noCustom
			then
			
		local title, selected, weight

		local defaultNode = jiveMain:getNodeText(item.node)
		if defaultNode then
			title = tostring(item.text) .. ' (' .. tostring(defaultNode) .. ')'
		else
			title = item.text
		end

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

		if item.node == 'home' then
			weight = 2
		else
			weight = 5
		end

		local menuItem = {
			text = title,
			weight = weight,
			icon = Checkbox(
				"checkbox",
				function(object, isSelected)
					if isSelected then
						if item.node == 'home' then
							self:getSettings()[item.id] = nil
							jiveMain:setNode(item, 'home')
						else
							self:getSettings()[item.id] = 'home'
							if item.homeMenuToken then
								item.text = self:string(item.homeMenuToken)
							elseif item.homeMenuText then
								item.text = item.homeMenuText
							end
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
		table.insert(homeMenuItems, menuItem)
		end
	end

	local menu = SimpleMenu("menu",  homeMenuItems  )
	menu:setComparator(menu.itemComparatorWeightAlpha)

	local window = Window("window", self:string("CUSTOMIZE_HOME"), 'settingstitle')
	window:addWidget(menu)
	window:show()
end

function restoreDefaultsMenu(self, id)
	local window = Window("window", self:string("CUSTOMIZE_RESTORE_DEFAULTS"), 'settingstitle')
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
					jiveMain:setNode(item, item.node)
				end
				self:storeSettings()
				_goHome()
			end
		},
	})

	window:addWidget(Textarea("help", self:string("CUSTOMIZE_RESTORE_DEFAULTS_HELP")))
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
