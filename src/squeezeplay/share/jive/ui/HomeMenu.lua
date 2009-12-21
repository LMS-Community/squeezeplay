
local assert, pairs, type, tostring, tonumber, setmetatable = assert, pairs, type, tostring, tonumber, setmetatable

local oo            = require("loop.base")
local table         = require("jive.utils.table")
local string        = require("jive.utils.string")

local Framework     = require("jive.ui.Framework")
local SimpleMenu    = require("jive.ui.SimpleMenu")
local Window        = require("jive.ui.Window")
local Icon          = require("jive.ui.Icon")

local debug         = require("jive.utils.debug")
local log           = require("jive.utils.log").logger("squeezeplay.ui")

local EVENT_WINDOW_ACTIVE         = jive.ui.EVENT_WINDOW_ACTIVE
local EVENT_WINDOW_INACTIVE       = jive.ui.EVENT_WINDOW_INACTIVE
local EVENT_UNUSED                = jive.ui.EVENT_UNUSED

-- our class
module(..., oo.class)

-- defines a new item that inherits from an existing item
local function _uses(parent, value)
	local item = {}
	setmetatable(item, { __index = parent })

	for k,v in pairs(value or {}) do
		if type(v) == "table" and type(parent[k]) == "table" then
		-- recursively inherrit from parent item
			item[k] = _uses(parent[k], v)
		else
			item[k] = v
		end
	end

	return item
end

local function bumpAction(self)
	self.window:playSound("BUMP")
	self.window:bumpLeft()

	return EVENT_CONSUME

end

-- create a new menu
function __init(self, name, style, titleStyle)
	local obj = oo.rawnew(self, {
		window = Window(style or "home_menu", name),
		windowTitle = name,
		menuTable = {},
		nodeTable = {},
		customMenuTable = {},
		customNodes = {},
	})

	local menu = SimpleMenu("menu")
	menu:setComparator(SimpleMenu.itemComparatorComplexWeightAlpha)

	-- home menu is not closeable
	menu:setCloseable(false)

	obj.window:addWidget(menu)
	obj.nodeTable['home'] = {
		menu = menu, 
		items = {}
	}
	
	--Avoid inadvertantly quitting the app.
	obj.window:addActionListener("back", obj, bumpAction)

	local homeRootHandler = function()
					local windowStack = Framework.windowStack

					-- if not at root of home, go to root of home :bug #14066
					if #windowStack == 1 then
						local homeMenu = obj.nodeTable["home"].menu
						if homeMenu:getSelectedIndex() and homeMenu:getSelectedIndex() > 1 then
							Framework:playSound("JUMP")
							homeMenu:setSelectedIndex(1)
							return EVENT_CONSUME
						end
					end

					--otherwise let standard action hanlder take over
					return EVENT_UNUSED
				end

	obj.window:addActionListener("go_home", obj, homeRootHandler)
	obj.window:addActionListener("go_home_or_now_playing", obj, homeRootHandler)


	-- power button, delayed display so that "back back back power" is avoided (if power button is selected as home press
	obj.window:setButtonAction("lbutton", "home_title_left_press", "home_title_left_hold", "soft_reset", true)

	obj.window:addListener( EVENT_WINDOW_ACTIVE,
				function()
					--only do timer when we know "home press" is power (still might be missing from INACTIVE handling if shortcuts changed recently) 
					if Framework:getActionToActionTranslation("home_title_left_press") == "power" then
						obj.window:addTimer(    1000,
									function ()
										obj.window:setButtonAction("lbutton", "home_title_left_press", "home_title_left_hold", "soft_reset", true)
									end,
									true)
					else
						obj.window:setButtonAction("lbutton", "home_title_left_press", "home_title_left_hold", "soft_reset", true)
					end
					return EVENT_UNUSED
				end)

	obj.window:addListener( EVENT_WINDOW_INACTIVE,
				function()
					if Framework:getActionToActionTranslation("home_title_left_press") == "power" then
						obj.window:setButtonAction("lbutton", nil)
					end
					return EVENT_UNUSED
				end)

	return obj
end

function getMenuItem(self, id)
	return self.menuTable[id]
end

function getMenuTable(self)
	return self.menuTable
end

function getNodeTable(self)
	return self.nodeTable
end

function getNodeText(self, node)
	assert(node)
	if self.nodeTable[node] and self.nodeTable[node]['item'] and self.nodeTable[node]['item']['text'] then
		return self.nodeTable[node]['item']['text']
	else
		return nil
	end
end

function getComplexWeight(self, id, item)
	if self.menuTable[id]['node'] == 'home' then
		return item.weight
	elseif self.menuTable[id]['node'] == 'hidden' then
		return self.menuTable[id].hiddenWeight and self.menuTable[id].hiddenWeight or 100
	else
		local nodeItem = self.menuTable[id]['node']
		if not self.menuTable[nodeItem] then
			log:warn('when trying to analyze ', item.text, ', its node, ', nodeItem, ', is not currently in the menuTable thus no way to establish a complex weight for sorting')
			return item.weight
		else
			return self:getComplexWeight(self.menuTable[id]['node'], self.menuTable[nodeItem]) .. '.' .. item.weight
		end
	end
end

function setTitle(self, title)
	if title then
		self.window:setTitle(title)
	else
		self.window:setTitle(self.windowTitle)
	end
end

function setCustomNode(self, id, node)
	if self.menuTable[id] then
		local item = self.menuTable[id]
		-- an item from home that is set for 'hidden' should be removed from home
		if item.node == 'home' and node == 'hidden' then
			self:removeItemFromNode(item, 'home')
		end
		self:addItemToNode(item, node)
	end
	self.customNodes[id] = node
end

function setNode(self, item, node)
	assert(item)
	assert(node)

	self:removeItem(item)
	self:setCustomNode(item.id, node)
	self:addItem(item)
end

--[[

Close all windows to expose the home menu. By default alwaysOnTop windows
are not hidden. Also move to root home item.

--]]
function closeToHome(self, hideAlwaysOnTop, transition)

	--move to root item :bug #14066
	if self.nodeTable then
		self.nodeTable["home"].menu:setSelectedIndex(1)
	end

	local stack = Framework.windowStack

	local k = 1
	for i = 1, #stack do
		if stack[i].alwaysOnTop and hideAlwaysOnTop ~= false then
			k = i + 1
		end

		if stack[i] == self.window then
			for j = i - 1, k, -1 do
				stack[j]:hide(transition)
			end
		end
	end
end


function _changeNode(self, id, node)
	-- looks at the node and decides whether it needs to be removed
	-- from a different node before adding
	if self.menuTable[id] and self.menuTable[id].node != node then 
		-- remove menuitem from previous node
		self.nodeTable[node].items[id] = nil
		-- change menuitem's node
		self.menuTable[id].node = node
		-- add item to that node
		self:addNode(self.menuTable[id])
	end
end

function exists(self, id)
	return self.menuTable[id] ~= nil
end

function addNode(self, item)

	if not item or not item.id or not item.node then
		return
	end

	log:debug("JiveMain.addNode: Adding a non-root node, ", item.id)

	item.isANode = 1

	if not item.weight then 
		item.weight = 100
	end

	if item.iconStyle then
		item.icon = Icon(item.iconStyle)
	else
		item.iconStyle = 'hm_advancedSettings'
	end
	-- remove/update node from previous node (if changed)
	if self.menuTable[item.id] then
		self.menuTable[item.id].text = item.text
		local newNode    = item.node
		local prevNode   = self.menuTable[item.id].node
		if newNode != prevNode then
			_changeNode(self, item.id, newNode)
		end

		return
	end

	local window
	-- FIXME: this if clause is mostly for mini icon support, which is either going obsolete
	-- or will need to be implemented differently after the skin reorg effort
	--[[
	if item.window and item.window.titleStyle then
		window = Window("text_list", item.text, item.window.titleStyle .. "title")
	elseif item.titleStyle then
		window = Window("text_list", item.text, item.titleStyle .. "title")
	else
		window = Window("text_list", item.text)
	end
	--]]

	if item.windowStyle then
		window = Window(item.windowStyle, item.text)
	else
		window = Window("home_menu", item.text)
	end

	local menuStyle = 'menu'
	if item.window and item.window.menuStyle then
		menuStyle = item.window.menuStyle .. 'menu'
	end
	local menu = SimpleMenu(menuStyle, item)
	menu:setComparator(SimpleMenu.itemComparatorWeightAlpha)

	window:addWidget(menu)

	self.nodeTable[item.id] = {
		menu = menu,
		item = item,
		items = {}
	}

	if not item.callback then
		item.callback = function ()
			window:setTitle(item.text)
			window:show()
		end
	end

	if not item.sound then
		item.sound = "WINDOWSHOW"
	end
end

-- add an item to a node
function addItemToNode(self, item, node)
	assert(item.id)
	self.node = node
	if node then
		self.customNodes[item.id] = node
		if item.node ~= 'home' and node == 'home' then
			local complexWeight = self:getComplexWeight(item.id, item)
			item.weights = string.split('%.', complexWeight)
		end
	else
		node = item.node
	end
	assert(node)

	if self.nodeTable[node] then
		self.nodeTable[node].items[item.id] = item
		local menuIdx = self.nodeTable[node].menu:addItem(item)
		if node == 'home' and item.homeMenuText then
			local labelText = item.homeMenuText
			-- change the menu item's text by creating a new item table with different label text
			local myItem = _uses(item, { text = labelText })
			self.customMenuTable[myItem.id] = myItem
			self.nodeTable[node].menu:replaceIndex(myItem, menuIdx)
		end
	end

end

-- add an item to a menu. the menu is ordered by weight, then item name
function addItem(self, item)
	assert(item.id)
	assert(item.node)

	if item.iconStyle then
		item.icon = Icon(item.iconStyle)
	end
	if not item.weight then
		item.weight = 100
	end

	if item.extras and type(item.extras) == 'table' then
		for key, val in pairs(item.extras) do
			item[key] = val
		end
		item.extras = nil
	end

	-- add or update the item from the menuTable
	self.menuTable[item.id] = item

	-- add item to its custom node
	local customNode = self.customNodes[item.id]
	if customNode then
		if customNode == 'hidden' and item.node == 'home' then
			self:addItemToNode(item, customNode)
			self:removeItemFromNode(item, 'home')
			return
		elseif customNode == 'home' then
			self:addItemToNode(item, customNode)
		end
	end

	-- add item to its default node
	self:addItemToNode(item)

	-- add parent node?
	local nodeEntry = self.nodeTable[item.node]

	-- FIXME: this looks like a bug...shouldn't we be adding a node entry also when nodeEntry is false?
	if nodeEntry and nodeEntry.item then
		local hasItem = self.menuTable[nodeEntry.item.id] ~= nil

		if not hasItem then
			-- any entries in items table?
			local hasEntry = pairs(nodeEntry.items)(nodeEntry.items)
			if  hasEntry then
				-- now add the item to the menu
				self:addItem(nodeEntry.item)
			end
		end
	end
end

-- takes an id and returns true if this item exists in either the menuTable or the nodeTable
function isMenuItem(self, id)
	if self.menuTable[id] or self.nodeTable[id] then
		return true
	else
		return false
	end
end

function _checkRemoveNode(self, node)
	local nodeEntry = self.nodeTable[node]

	if nodeEntry and nodeEntry.item then
		local hasItem = self.menuTable[nodeEntry.item.id] ~= nil

		if hasItem then
			-- any entries in items table?
			local hasEntry = pairs(nodeEntry.items)(nodeEntry.items)

			if not hasEntry  then
				self:removeItem(nodeEntry.item)
			end
		end
	end
end

-- remove an item from a node
function removeItemFromNode(self, item, node)
	assert(item)
	if not node then
		node = item.node
	end
	assert(node)
	if node == 'home' and self.customMenuTable[item.id] then
		local myIdx = self.nodeTable[node].menu:getIdIndex(item.id)
		if myIdx ~= nil then
			local myItem = self.nodeTable[node].menu:getItem(myIdx)
			self.nodeTable[node].menu:removeItem(myItem)
		end
	end

	if self.nodeTable[node] then
		self.nodeTable[node].items[item.id] = nil
		self.nodeTable[node].menu:removeItem(item)
		self:_checkRemoveNode(node)
	end


end

-- remove an item from a menu
function removeItem(self, item)
	assert(item)
	assert(item.node)

	if self.menuTable[item.id] then
		self.menuTable[item.id] = nil
	end

	self:removeItemFromNode(item)

	-- if this item is co-located in home, get rid of it there too
	self:removeItemFromNode(item, 'home')

end


function openNodeById(self, id, resetSelection)
	if self.nodeTable[id] then
		if resetSelection then
			self.nodeTable[id].menu:setSelectedIndex(1)
		end
		self.nodeTable[id].item.callback()
		return true
	else
		return false
	end
end


function enableItem(self, item)
	
end

--  disableItem differs from removeItem in that it drops the item into a removed node rather than eliminating it completely
--  this is useful for situations where you would not want GC, e.g., a meta file that needs to continue to be in memory
--  to handle jnt notification events

function disableItem(self, item)
	assert(item)
	assert(item.node)

	if self.menuTable[item.id] then
		self.menuTable[item.id] = nil
	end

	self:removeItemFromNode(item)

	item.node = 'hidden'
	self:addItem(item)

	-- if this item is co-located in home, get rid of it there too
	self:removeItemFromNode(item, 'home')

end

function disableItemById(self, id)
	if self.menuTable[id] then
		local item = self.menuTable[id]
		self:disableItem(item)
	end

end

-- remove an item from a menu by its id
function removeItemById(self, id)
	if self.menuTable[id] then
		local item = self.menuTable[id]
		self:removeItem(item)
	end
end


-- lock an item in the menu
function lockItem(self, item, ...)
	if self.customNodes[item.id] then
		self.nodeTable[self.customNodes[item.id]].menu:lock(...)
	elseif self.nodeTable[item.node] then
		self.nodeTable[item.node].menu:lock(...)
	end
end


-- unlock an item in the menu
function unlockItem(self, item)
	if self.customNodes[item.id] then
		self.nodeTable[self.customNodes[item.id]].menu:unlock()
	elseif self.nodeTable[item.node] then
		self.nodeTable[item.node].menu:unlock()
	end
end


-- iterator over items in menu
function iterator(self)
	return self.menu:iterator()
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

