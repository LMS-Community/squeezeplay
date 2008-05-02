
local assert, pairs = assert, pairs

local oo            = require("loop.base")
local table         = require("jive.utils.table")

local Framework     = require("jive.ui.Framework")
local SimpleMenu    = require("jive.ui.SimpleMenu")
local Window        = require("jive.ui.Window")

local debug         = require("jive.utils.debug")
local log           = require("jive.utils.log").logger("ui")


-- our class
module(..., oo.class)


-- create a new menu
function __init(self, name, style, titleStyle)
	local obj = oo.rawnew(self, {
		window = Window(style or "window", name, titleStyle),
		windowTitle = name,
		menuTable = {},
		nodeTable = {},
		customNodes = {},
	})

	local menu = SimpleMenu("menu")
	menu:setComparator(SimpleMenu.itemComparatorWeightAlpha)

	-- home menu is not closeable
	menu:setCloseable(false)

	obj.window:addWidget(menu)
	obj.nodeTable['home'] = {
		menu = menu, 
		items = {}
	}

	return obj
end

function getMenuTable(self)
	return self.menuTable
end

function getNodeTable(self)
	return self.nodeTable
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
		self:removeItem(item)
		self:addItem(item)
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
are not hidden.

--]]
function closeToHome(self, hideAlwaysOnTop)
	local stack = Framework.windowStack

	local k = 1
	for i = 1, #stack do
		if stack[i].alwaysOnTop and hideAlwaysOnTop ~= false then
			k = i + 1
		end

		if stack[i] == self.window then
			for j = i - 1, k, -1 do
				stack[j]:hide()
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
		addNode(self.menuTable[id])
	end
end

function addNode(self, item)
	assert(item.id)
	assert(item.node)

	log:debug("JiveMain.addNode: Adding a non-root node, ", item.id)

	item.isANode = 1

	if not item.weight then 
		item.weight = 100
	end
	if not item.defaultNode then
		item.defaultNode = item.node
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
	if item.window and item.window.titleStyle then
		window = Window("window", item.text, item.window.titleStyle .. "title")
	elseif item.titleStyle then
		window = Window("window", item.text, item.titleStyle .. "title")
	else
		window = Window("window", item.text)
	end

	local menu = SimpleMenu("menu", item)
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


-- add an item to a menu. the menu is ordered by weight, then item name
function addItem(self, item)
	assert(item.id)
	assert(item.node)

	if not item.weight then 
		item.weight = 100
	end
	if not item.defaultNode then
		item.defaultNode = item.node
	end

	local whichNode
	if self.customNodes[item.id] then
		whichNode = self.customNodes[item.id]
	else
		whichNode = item.node
	end

	-- add or update the item from the menuTable
	self.menuTable[item.id] = item

	if self.nodeTable[whichNode] then
		self.nodeTable[whichNode].items[item.id] = item
		self.nodeTable[whichNode].menu:addItem(item)
	end

	-- add parent node?
	local nodeEntry = self.nodeTable[whichNode]
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


-- remove an item from a menu by its index
function removeItem(self, item)
	assert(item)
	assert(item.node)

	if self.menuTable[item.id] then
		self.menuTable[item.id] = nil
	end

	local node
	if self.customNodes[item.id] then
		node = self.customNodes[item.id]
	elseif self.nodeTable[item.node] then
		node = item.node
	end

	if self.nodeTable[node] then
		self.nodeTable[node].items[item.id] = nil
		self.nodeTable[node].menu:removeItem(item)
		self:_checkRemoveNode(node)
	end
end

-- remove an item from a menu by its id
function removeItemById(self, id)
	if self.menuTable[id] then
		local item = self.menuTable[id]
		if self.nodeTable[item.node] then
			self.nodeTable[item.node].menu:removeItemById(id)
			self.nodeTable[item.node].items[id] = nil
		end
		self.menuTable[id] = nil

		self:_checkRemoveNode(item.node)

	end
end


-- lock an item in the menu
function lockItem(self, item, ...)
	if self.nodeTable[item.node] then
		self.nodeTable[item.node].menu:lock(...)
	end
end


-- unlock an item in the menu
function unlockItem(self, item)
	if self.nodeTable[item.node] then
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

