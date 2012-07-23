
--[[
=head1 NAME

Info Browser Applet

=head1 DESCRIPTION

Browser for information sources using the Slimserver InfoBrowser plugin.

=cut
--]]

-- stuff we use
local pairs, tonumber, tostring = pairs, tonumber, tostring

local oo            = require("loop.simple")
local table         = require("table")
local string        = require("string")

local Applet        = require("jive.Applet")

local Framework     = require("jive.ui.Framework")
local SimpleMenu    = require("jive.ui.SimpleMenu")
local Window        = require("jive.ui.Window")
local Textarea      = require("jive.ui.Textarea")
local Popup         = require("jive.ui.Popup")
local Timer         = require("jive.ui.Timer")

local debug         = require("jive.utils.debug")

local appletManager = appletManager

module(..., Framework.constants)
oo.class(_M, Applet)


local gulp    = 20     -- get this many entries per request


-- open main menu
function menu(self, menuItem)

	local list = {}
	local window = Window("text_list", menuItem.text, "infobrowsertitle")
	local menu = SimpleMenu("menu", list)
	window:addWidget(menu)

	self:tieAndShowWindow(window)

	-- find a server: server for current player, else first server
	self.player = appletManager:callService("getCurrentPlayer")
	if self.player then
		self.server = self.player:getSlimServer()
	else
		for _, server in appletManager:callService("iterateSqueezeCenters") do
			if server:isConnected() then
				self.server = server
				break
			end
		end
	end

	-- send first request if we have a server
	if self.server then
		self:request(nil, 0, window, menu, list)
		self.timer = Timer(5000, function()
									 menu:setHeaderWidget(Textarea("help_text", self:string('INFOBROWSER_NORESPONSE')))
									 menu:reSkin()
								 end)
		self.timer:start()
	end
end


-- request for items
function request(self, index, start, window, widget, list, prevmenu, locked)

	self.server:userRequest(
		function(chunk, err)
			if err then
				log:debug(err)
			elseif chunk then
				self:response(chunk.data, window, widget, list, prevmenu, locked)
			end
		end,
		self.player and self.player:getId(),
		{ 'infobrowser', 'items', start, gulp, index and ("item_id:" .. index) }
	)
end


-- sink to process response and display items
function response(self, result, window, widget, list, prevmenu, locked)

	local id

	-- cancel the warning for no response
	if self.timer then
		self.timer:stop()
		self.timer = nil
	end

	-- end previous menu animation and show new window
	if locked then
		prevmenu:unlock()
		window:show()
	end

	-- display help if no feeds found
	if result.loop_loop == nil then
		prevmenu:setHeaderWidget(Textarea("help_text", self:string( 'INFOBROWSER_NOINFO_' .. (self.server:isSqueezeNetwork() and 'SN' or 'SC') ) ) )
		prevmenu:reSkin()
		return
	end

	-- itterate though response - handle leaves as well as branches
	for _,entry in pairs(result.loop_loop) do
		id = entry.id
		if entry.hasitems then
			-- branch - add menu entry for this item
			list[#list + 1] = {
				text = entry.name or entry.title,
				sound = "WINDOWSHOW",
				callback = function(_, menuItem)
							   local newlist = {}
							   local newwindow = Window("text_list", menuItem.text)
							   -- assume new level is a menu for the moment, this is replaced later if it is not
							   local newmenu = SimpleMenu("menu", newlist)
							   newwindow:addWidget(newmenu)
							   widget:lock()
							   self:request(entry.id, 0, newwindow, newmenu, newlist, widget, true)
						   end
			}
		elseif entry.description then
			-- leaf - update textarea page for this item or replace menu with textarea and update
			window:setTitle(entry.name or entry.title)
			if oo.instanceof(widget, SimpleMenu) then
				window:removeWidget(widget)
				widget = Textarea("text")
				window:addWidget(widget)
			end

			-- update the display, ensuring we go back to the top
			widget.topLine = 0
			widget:setValue(entry.description)

			local _navigateEntriesAction =  function (self, event)
												local pre, c = _split(id)
												if event:getAction() == "play" and c+1 < prevmenu.listSize then
													c = c + 1
												elseif event:getAction() == "add" and c > 0 then
													c = c - 1
												else
													window:bumpRight()
												end
												-- fetch next item and update index on previous menu to match
												self:request(pre .. "." .. tostring(c), 0, window, widget, list, prevmenu)
												prevmenu:setSelectedIndex(c+1)
												return EVENT_CONSUME
												
											end
			
			widget:addActionListener("play", self, _navigateEntriesAction)
			widget:addActionListener("add", self, _navigateEntriesAction)
		end
	end

	-- handle fetching rest of level if it is larger than one gulp
	if #list > 0 then
		widget:setItems(list)
		local pre, c = _split(id)
		if c < result.count - 1 then
			self:request(pre, c + 1, window, widget, list, prevmenu)
		end
	end
end


-- split cli index into prefix and index for this level
function _split(index)
	local t = {}
	for i in string.gmatch(index or "", "[0-9a-f]+") do
		t[#t+1] = i
	end
	local c = t[#t]
	t[#t] = nil
	local pre = table.concat(t, ".")
	return pre, tonumber(c)
end

