
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
	local currentSettings = self:getSettings()

	-- get the menu table from jiveMain
	local menuTable = jiveMain:getMenuTable()
	-- get items that have been customized
	--local customTable = jiveMain:getCustomTable()

	-- get the nodes. these become the choices + hidden
	local nodeTable = jiveMain:getNodeTable()

	local homeMenuItems = {}
	for id, item in pairs(menuTable) do
		if id ~= 'nowhere' and id ~= 'hidden' then
			
		local selected
		local choices = { self:string('HIDDEN'), self:string('HOME') }

		-- add the default node if it's not home
		if item.defaultNode ~= 'home' then
			log:warn(id)
			log:warn(item.node)
			table.insert(choices, nodeTable[item.defaultNode]['item']['text'])
		end

		if currentSettings[id] and currentSettings[id] == 'hidden' then
			selected = 1
		elseif currentSettings[id] and currentSettings[id] == 'home' then
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
					elseif selectedIndex == 2 then
						node = 'home'
					elseif selectedIndex == 3 then
						node = menuTable[id]['defaultNode']
					end
					jiveMain:setNode(item, node)
					self:getSettings()[item.id] = item.node
					self:storeSettings()
				end,
				selected
			),
		}
		table.insert(homeMenuItems, menuItem)
		end
	end

	local menu = SimpleMenu("menu",  homeMenuItems  )
	menu:setComparator(menu.itemComparatorAlpha)

	local window = Window("window", self:string("CUSTOMIZE_HOME"))
	window:addWidget(menu)
	window:show()
end

