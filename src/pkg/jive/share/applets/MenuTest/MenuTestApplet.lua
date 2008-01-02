
-- stuff we use
local print, pairs, tonumber, tostring = print, pairs, tonumber, tostring

local oo            = require("loop.simple")
local table         = require("table")
local string        = require("string")
local math          = require("math")

local Applet        = require("jive.Applet")
local SlimServers   = require("jive.slim.SlimServers")

local AppletManager = require("jive.AppletManager")

local Framework     = require("jive.ui.Framework")
local SimpleMenu    = require("jive.ui.SimpleMenu")
local Menu          = require("jive.ui.Menu")
local Window        = require("jive.ui.Window")
local Textarea      = require("jive.ui.Textarea")
local Popup         = require("jive.ui.Popup")
local Timer         = require("jive.ui.Timer")
local Label         = require("jive.ui.Label")
local Group         = require("jive.ui.Group")
local Icon          = require("jive.ui.Icon")

local DB            = require("applets.SlimBrowser.DB")

local log           = require("jive.utils.log").logger("applets.misc")
local debug         = require("jive.utils.debug")

local EVENT_FOCUS_GAINED = jive.ui.EVENT_FOCUS_GAINED

module(...)
oo.class(_M, Applet)


local total = 10000  -- total number of items for list
local pad   = 100    -- pad each response with this many bytes

-- Option 1 : settings for download first and then scroll
--local fetchFirst = true
--local gulp  = 200    -- number of items per response

-- Options 2: settings for downloading in real time
local fetchFirst = false
local gulp  = 200     -- number of items per response (as small as possible???)


-- open main menu
function menu(self, menuItem)

	-- create dumy menu entries which get filled in later - used to demo real time fetching of menu data
	--[[
	local list = {}
	for i = 1, total do
		list[i] = { 
			text = '', 
			focusGained = function(event, item)
							  if fetchFirst then return end
							  if i - 1 + gulp > total then
								  self:request(total - gulp)
							  elseif self.menu.scrollDir < 1 then
								  self:request(i - 2)
							  else
								  self:request(i - self.menu.numWidgets + 1)
							  end
						  end
		}
	end
	--]]

	local window = Window("window", menuItem.text)

	self.menu = Menu("menu", _menuRenderer, _menuListener)

	self.db = DB({})
	self.db.owner = self
	self.menu:setItems(self.db:menuItems())

	window:addWidget(self.menu)
	self:tieAndShowWindow(window)

	sd = AppletManager:getAppletInstance("SlimDiscovery")

	if sd then
		if sd:getCurrentPlayer() then
			self.server = sd:getCurrentPlayer():getSlimServer()
		else
			for _, server in sd:allServers() do
				self.server = server
				break
			end
		end
	end

	if self.server then
		self:request(0)
	end
end


function _decoratedLabel(group, item, db)
	if not group then
		group = Group("item", { text = Label("text", ""), icon = Icon("icon"), play = Icon("play") })
	end

	if item then
		group:setWidgetValue("text", item.text)

	else
		group:setWidgetValue("text", "")
		group:setWidgetValue("icon", nil)
		group:setStyle("item")
	end

	return group
end


function _menuRenderer(menu, widgets, toRenderIndexes, toRenderSize, db)
	local labelItemStyle = db:labelItemStyle()
	
	for widgetIndex = 1, toRenderSize do
		local dbIndex = toRenderIndexes[widgetIndex]
		
		if dbIndex then
			local item = db:item(dbIndex)

			local widget = widgets[widgetIndex]
			widgets[widgetIndex] = _decoratedLabel(widget, item, db)
		end
	end


	-- fetch next data...
	if fetchFirst then return end

	local self = db.owner
	local i = menu:getSelectedIndex() or 1

	if math.modf(i, 10) == 0 then
		log:warn("i=", i)
	end


	if db:item(i + 50) then
		return
	end

	if i - 1 + gulp > total then
		self:request(total - gulp)
	elseif self.menu.scrollDir < 1 then
		self:request(i - 2)
	else
		self:request(i - self.menu.numWidgets + 1)
	end
end


function _menuListener(menu, menuItem, db, dbIndex, event)
	-- not needed for test
end


function request(self, start)
	log:warn("reqest  (", start, " - ", start + gulp, ")")

	local now = Framework:getTicks()

	if not fetchFirst and self.pending then
		return
	end

	self.pending = true

	self.server.comet:request(
		function(chunk, err)
			if err then
				log:debug(err)
			elseif chunk then
				self:response(chunk.data)
			end
		end,
		false,
		{ 'menutest', start, gulp, 'total:' .. total, 'req:' .. now, 'pad:' .. pad }
	)

end


function response(self, result)

	if result == nil or result.item_loop == nil then
		return
	end

	local now = Framework:getTicks()

	self.menu:setItems(self.db:menuItems(result))

	log:warn("fetched (", first, " - ", last, ") : ", now - result.req, " ms")

	if fetchFirst then
		-- fetch next gulp if in this mode
		self:request(last + 1)
	end

	self.pending = false
end

