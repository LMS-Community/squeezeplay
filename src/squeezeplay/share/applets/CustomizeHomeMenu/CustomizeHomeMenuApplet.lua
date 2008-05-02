
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
local Choice                 = require("jive.ui.Choice")
local RadioButton            = require("jive.ui.RadioButton")
local RadioGroup             = require("jive.ui.RadioGroup")
local Window                 = require("jive.ui.Window")
local Popup                  = require("jive.ui.Popup")
local Textarea               = require('jive.ui.Textarea')
local Framework              = require('jive.ui.Framework')

local SimpleMenu             = require("jive.ui.SimpleMenu")
local RadioGroup             = require("jive.ui.RadioGroup")
local log                    = require("jive.utils.log").addCategory("customizeHome", jive.utils.log.DEBUG)

local debug                  = require("jive.utils.debug")
local jiveMain               = jiveMain
local appletManager          = appletManager
local jnt                    = jnt

module(...)
oo.class(_M, Applet)


function menu(self, menuItem)

	log:info("menu")
	local group = RadioGroup()
	self.currentSettings = self:getSettings()

	-- get the menu table from jiveMain
	self.menuTable = jiveMain:getMenuTable()
	-- get items that have been customized
	--local customTable = jiveMain:getCustomTable()

	-- get the nodes. these become the choices + hidden
	self.nodeTable = jiveMain:getNodeTable()

	local homeMenuItems = {}
	
	-- first add an entry for returning everything to defaults
	table.insert(homeMenuItems,
		{
			text = self:string('CUSTOMIZE_RESTORE_DEFAULTS'),
			weight = 1,
			callback = function()
				self:restoreDefaultsMenu()
			end
		}
	)

	table.insert(homeMenuItems,  
		{
			text = self:string('SETTINGS'),
			weight = 100,
			callback = function()
				self:warnHide('settings')
			end
		}
	)

	table.insert(homeMenuItems, 
		{
			text = self:string('CUSTOMIZE_HOME'),
			weight = 101,
			callback = function()
				self:warnHide('appletCustomizeHome')
			end
		}
	)


	for id, item in pairs(self.menuTable) do
		if id ~= 'hidden' and
			id ~= 'nowhere' and
			id ~= 'appletCustomizeHome' and
			id ~= 'settings' then
			
		local selected
		local choices = { self:string('CUSTOMIZE_HIDDEN'), self:string('HOME') }

		-- add the item's node to the list of choices if it's not home or hidden
		if item.node ~= 'home' and item.node ~= 'hidden' then
			table.insert(choices, self.nodeTable[item.node]['item']['text'])
		end

		if self.currentSettings[id] and self.currentSettings[id] == 'hidden' then
			selected = 1
		elseif self.currentSettings[id] and self.currentSettings[id] == 'home' then
			selected = 2
		else
			selected = #choices
		end

		local menuItem = {
			text = item.text,
			weight = 5,
			icon = Choice(
				"choice",
				choices,
				function(object, selectedIndex)
					local node
					if selectedIndex == 1 then
						node = 'hidden'
						self:getSettings()[item.id] = node
					elseif selectedIndex == 2 then
						node = 'home'
						self:getSettings()[item.id] = node
					elseif selectedIndex == 3 then
						node = self.menuTable[id]['node']
						self:getSettings()[item.id] = nil
					end
					self:storeSettings()
					jiveMain:setNode(item, node)
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

function warnHide(self, id)
	local item = self.menuTable[id]
	local window = Window("window", item.text, 'settingstitle')

	local selected
	local choices = { self:string('CUSTOMIZE_HIDDEN'), self:string('HOME') }

	-- add the item's (default) node to the list of choices if it's not home or hidden
	if item.node ~= 'home' and item.node ~= 'hidden' then
		table.insert(choices, self.nodeTable[item.node]['item']['text'])
	end

	if self.currentSettings[id] and self.currentSettings[id] == 'hidden' then
		selected = 1
	elseif self.currentSettings[id] and self.currentSettings[id] == 'home' then
		selected = 2
	else
		selected = #choices
	end

	local menuItem = {
		text = item.text,
		icon = Choice(
			"choice",
			choices,
			function(object, selectedIndex)
				local node
				if selectedIndex == 1 then
					node = 'hidden'
					self:getSettings()[item.id] = node
				elseif selectedIndex == 2 then
					node = 'home'
					self:getSettings()[item.id] = node
				elseif selectedIndex == 3 then
					node = self.menuTable[id]['node']
					self:getSettings()[item.id] = nil
				end
				self:storeSettings()
				jiveMain:setNode(item, node)
			end,
			selected
		),
	}

        local menu = SimpleMenu("menu", {
		{
			text = self:string("CUSTOMIZE_CANCEL"),
			sound = "WINDOWHIDE",
			callback = function()
				window:hide()
			end
		},
		menuItem
	})


	window:addWidget(Textarea("help", self:string("CUSTOMIZE_HIDDEN_WARNING")))
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
