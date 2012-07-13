
-- stuff we use
local pairs = pairs

local oo                     = require("loop.simple")
local string                 = require("string")

local Applet                 = require("jive.Applet")
local Framework              = require("jive.ui.Framework")
local Window                 = require("jive.ui.Window")
local Textarea               = require("jive.ui.Textarea")
local SimpleMenu             = require("jive.ui.SimpleMenu")

local jiveMain               = jiveMain
local appletManager          = appletManager
local jnt                    = jnt


module(..., Framework.constants)
oo.class(_M, Applet)


local _attachedServers = {}
local _lockedItem = false
local _playerMenus = {}


function init(self)
	jnt:subscribe(self)
end


function  _addNode(self, node)
	if not jiveMain:exists(node.id) then
		jiveMain:addNode(node, true)
	else
		log:debug("Node already present: ", node.id)
	end
end


function _addItem(self, item)
	if not _playerMenus[item.node .. item.id] then
		_playerMenus[item.node .. item.id] = item
		jiveMain:addItem(item)
		log:debug("Add item - node: ", item.node, " id: ", item.id)
	else
		log:debug("Item already present - node: ", item.node, " id: ", item.id)
	end
end


function _serverVersionError(self, server)
	local window = Window("error", self:string("MYMUSIC_MUSIC_LIBRARY_VERSION"), setupsqueezeboxTitleStyle)
	window:setAllowScreensaver(false)

	local help = Textarea("help_text", self:string("MYMUSIC_MUSIC_LIBRARY_VERSION_HELP", server:getName(), server:getVersion()))

	window:addWidget(help)

	-- timer to check if server has been upgraded
	window:addTimer(1000, function()
		appletManager:callService("discoverServers")
		if server:isCompatible() then
			self:_selectServer(server)
			window:hide(Window.transitionPushLeft)
		end
	end)

	self:tieAndShowWindow(window)
end


function _selectServer(self, server)
	if server:getVersion() and not server:isCompatible() then
		--we only know if compatible if serverstatus has come back, other version will be nil, and we shouldn't assume not compatible
		_serverVersionError(self, server)
		return
	end

	self:_updateMyMusicTitle(server)
	jiveMain:openNodeById(server:getId())
end


-- _menuSink
-- returns a sink with a closure to self
-- cmd is passed in so we know what process function to call
-- this sink receives all the data from our Comet interface
local function _menuSink(self, server)
	return function(chunk, err)
		menuItems = chunk.data.item_loop

		if not menuItems then
			return
		end

		log:info("_menuSink(" .. #menuItems ..") server: ", server)

		for k, v in pairs(menuItems) do

			local item = {
				id = v.id,
				node = v.node,
				isANode = v.isANode,
				iconStyle = v.iconStyle,
				style = v.style,
				text = v.text,
				weight = v.weight,
				sound = "WINDOWSHOW",
			}

			-- make a style
			if item.id and not item.iconStyle then
				local iconStyle = 'hm_' .. item.id
				item.iconStyle = iconStyle
			end

			if item.id == "myMusic" then
				item.id = server:getId()
				item.node = "hidden"
				self:_addNode(item)

			elseif item.node == "myMusic" then
				item.node = server:getId()

				local actionInternal = function(noLocking)
					log:debug("send browserActionRequest request")
					local alreadyUnlocked = false
					local step = appletManager:callService("browserActionRequest", server, v,
						function()
							jiveMain:unlockItem(item)
							_lockedItem = false
							alreadyUnlocked = true
					end)

					if not v.input then -- no locks for an input item, which is immediate
						_lockedItem = item
						if not alreadyUnlocked and not noLocking then
							jiveMain:lockItem(item, function()
								appletManager:callService("browserCancel", step)
							end)
						end
					end
				end

				item.callback = function(_, _, noLocking)
					local action = function () actionInternal(noLocking) end

					log:debug("Let slim browse handle the connection issue")
					action()
				end

				self:_addItem(item)
			end
		end
         end
end


function _updateMyMusicTitle(self, server)
	local myMusicNode = jiveMain:getMenuTable()[server:getId()]
	-- it is possible on some branches for there to be no myMusicNode
	if not myMusicNode then
		return
	end

	if not myMusicNode.originalNodeText then
		myMusicNode.originalNodeText = myMusicNode.text
		--todo: this doesn't handle on-the-fly language change well
	end

	if not server or server:getId() == "ID_mysqueezebox.com" then
		myMusicNode.text = myMusicNode.originalNodeText
	else
		myMusicNode.text =  server:getName()
	end
end


function myMusicSelector(self)
	local window = Window("help_list", self:string("MYMUSIC_SERVERS"), "setuptitle")
	window:setAllowScreensaver(false)

	local numServer, lastServer = _numAttachedServer(self)

	if numServer == 1 then
		-- Only one attached server - show it directly
		self:_selectServer(lastServer)
		return
	end

	self.serverMenu = nil
	self.serverMenu = SimpleMenu("menu")
	self.serverMenu:setComparator(SimpleMenu.itemComparatorAlpha)

	for i, server in pairs(_attachedServers) do
		if server then
			local item = {
				id = server:getId(),
				text = server:getName(),
				sound = "WINDOWSHOW",
				callback = function()
						self:_selectServer(server)
					   end,
				weight = 1,
			}
			self.serverMenu:addItem(item)
		end
	end

	-- Always show help text for now
	--  Framework does not allow dynamic removal of help text
	--  Framework does not allow empty menu
	_showHelpText(self, true)

	window:addWidget(self.serverMenu)

	-- Discover servers in this window
	appletManager:callService("discoverServers")
	window:addTimer(1000, function() appletManager:callService("discoverServers") end)

	self:tieAndShowWindow(window)
end


function _numAttachedServer(self)
	local numServer = 0
	local lastServer = false
	for i, server in pairs(_attachedServers) do
		if server then
			numServer = numServer + 1
			lastServer = server
		end
	end

	return numServer, lastServer
end


function _showHelpText(self, enable)
	if enable then
		if self.serverMenu then
			self.helpText = Textarea("help_text", self:string("MYMUSIC_HINT"))
			self.serverMenu:setHeaderWidget(self.helpText)
		end
	else
		if self.serverMenu then
			-- This does not work
			--  Framework does not allow dynamic removal of help text
			self.helpText = nil
			self.serverMenu:setHeaderWidget(self.helpText)
		end
	end
end


-- Can be called even when applet has been freed
function notify_serverNew(self, server)
	if server:isSqueezeNetwork() then
		return
	end

	log:debug("New attached server: ", server)

	_attachedServers[server:getId()] = server

	if self.serverMenu then
		local item = {
			id = server:getId(),
			text = server:getName(),
			sound = "WINDOWSHOW",
			callback = function()
					self:_selectServer(server)
				   end,
			weight = 1,
		}
		self.serverMenu:addItem(item)

		-- show text again - this selects the first menu item
		_showHelpText(self, true)
	end

	-- Use current player's mac as id for the user request
	local player = appletManager:callService("getCurrentPlayer")

	-- Get menus from attached server, i.e. Artist, Album, ...
	server:userRequest(_menuSink(self, server), player:getId(), { 'menu', 0, 100, "direct:1" })
end


-- Can be called even when applet has been freed
function notify_serverDelete(self, server)
	if server:isSqueezeNetwork() then
		return
	end

	log:debug("Delete attached server: ", server)

-- Do not remove - if on this screen strange things happen
--	for id, v in pairs(_playerMenus) do
--		if v.node == server:getId() or v.id == server:getId() then
--			log:debug("For node: ", v.node, " remove item: ", v.id)
--			jiveMain:removeItem(v)
--			_playerMenus[id] = nil
--		end
--	end

	_attachedServers[server:getId()] = nil

	if self.serverMenu then
		self.serverMenu:removeItemById(server:getId())
	end
end



function free(self)

-- Do not remove - on reenter menu is empty
--	for id, v in pairs(_playerMenus) do
--		jiveMain:removeItem(v)
--	end
--	_playerMenus = {}

	-- make sure any home menu item are unlocked
	if _lockedItem then
		jiveMain:unlockItem(_lockedItem)
		_lockedItem = false
	end

	return false
end

--[[

=head1 LICENSE

Copyright 2012 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
