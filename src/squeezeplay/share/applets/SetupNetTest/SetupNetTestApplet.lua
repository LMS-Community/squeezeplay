
--[[
=head1 NAME

SetupNetTest Applet

=head1 DESCRIPTION

Test the network bandwidth between SqueezeCenter and a Player

=cut
--]]

-- stuff we use
local pairs, ipairs, tonumber, tostring, type = pairs, ipairs, tonumber, tostring, type

local oo            = require("loop.simple")
local table         = require("table")
local string        = require("string")

local Applet        = require("jive.Applet")

local AppletManager = require("jive.AppletManager")

local Framework     = require("jive.ui.Framework")
local SimpleMenu    = require("jive.ui.SimpleMenu")
local Window        = require("jive.ui.Window")
local Textarea      = require("jive.ui.Textarea")
local Label         = require("jive.ui.Label")
local Surface       = require("jive.ui.Surface")
local Icon          = require("jive.ui.Icon")
local Popup         = require("jive.ui.Popup")
local Timer         = require("jive.ui.Timer")

local log           = require("jive.utils.log").logger("applets.misc")
local debug         = require("jive.utils.debug")

local EVENT_SCROLL     = jive.ui.EVENT_SCROLL
local EVENT_KEY_PRESS  = jive.ui.EVENT_KEY_PRESS
local KEY_BACK         = jive.ui.KEY_BACK
local KEY_GO           = jive.ui.KEY_GO
local KEY_ADD          = jive.ui.KEY_ADD
local EVENT_CONSUME    = jive.ui.EVENT_CONSUME
local EVENT_UNUSED     = jive.ui.EVENT_UNUSED
local EVENT_ACTION     = jive.ui.EVENT_ACTION


module(...)
oo.class(_M, Applet)

local scroll = 2

local bground = 0x808080FF
local graphBG = 0x303040FF
local graphFG = 0x808080FF
local graphR  = 0x800000FF
local graphA  = 0x808000FF
local graphG  = 0x008000FF

-- open window
function open(self, menuItem)

	-- find a server: server for current player, else first server
	self.player = AppletManager:callService("getCurrentPlayer")
	if self.player then
		self.server = self.player:getSlimServer()
	end

	self.window = Window("nettest", self:string('SETUPNETTEST_TESTING'))

	self:tieAndShowWindow(self.window)

	local timer = Timer(1000, function() self.window:addWidget(Textarea("textarea", self:string('SETUPNETTEST_NOSERVER'))) end, true)
	timer:start()

	self:requestStatus(function() timer:stop() self:showMainWindow() end)
end


function showMainWindow(self)
	self.window:addWidget(Label("graphtitle", self:string('SETUPNETTEST_CURRENT')))

	self.graph1 = Surface:newRGBA(200, 80)
	self.graph1:filledRectangle(0, 0, 200, 80, graphBG)
	local icon1 = Icon("icon", self.graph1)
	self.window:addWidget(icon1)
	icon1:setPosition(20, 20)

	self.window:addWidget(Label("graphtitle", self:string('SETUPNETTEST_HISTORY')))

	self.graph2 = Surface:newRGBA(200, 80)
	self.graph2:filledRectangle(0, 0, 200, 80, graphBG)
	local icon2 = Icon("icon", self.graph2)
	self.window:addWidget(icon2)
	icon2:setPosition(20, 180)

	self.window:addWidget(Label("graphaxis", "0                                         100 %"))

	self.window:addWidget(Textarea("help", tostring(self:string('SETUPNETTEST_TESTINGTO')) .. ' ' .. self.player.name .. "\n" .. tostring(self:string('SETUPNETTEST_INFO'))))
	
	self.window:setAllowScreensaver(false)

	self.window:addListener(EVENT_SCROLL | EVENT_KEY_PRESS,
		function(event)
			return _event_handler(self, event)
		end
	)

	self.timer = Timer(1000, function() self:requestStatus(response) end)
	self.timer:start()
end


function _event_handler(self, event)

	if self.rates == nil or #self.rates == 0 then
		return
	end
	
	local type = event:getType()

	if type == EVENT_SCROLL then
		local rate = self.rate or 0
		local index = self.index[rate] or 1

		if event:getScroll() > 0 then
			if index < #self.rates then index = index + 1 end
		else
			if index > 1 then index = index - 1 end
		end

		self:startTest(self.rates[index])
		
		return EVENT_CONSUME
	end

	if type == EVENT_KEY_PRESS then
		local key = event:getKeycode()
		
		if key == KEY_BACK then
			self.window:hide()
		end
		if key == KEY_ADD then
			self:startTest(self.rate)
		end
		if key == KEY_GO then
			self:showHelpWindow()
		end

		return EVENT_CONSUME
	end

	return EVENT_UNUSED
end


function showHelpWindow(self)
	local window = Window("nettest", self:string('SETUPNETTEST_HELPTITLE'))
	local help = Textarea("textarea", self:string('SETUPNETTEST_HELP'))

	window:addWidget(help)
	
	self:tieAndShowWindow(window)

	return window
end


-- request status
function requestStatus(self, sink)
	self.server.comet:request(
		function(chunk, err)
			if err then
				log:debug(err)
			elseif chunk then
				sink(self, chunk.data)
			end
		end,
		self.player.id,
		{ 'nettest', self.rates and nil or 'rates' }
	)
end


-- sink to process response
function response(self, data)

	if data.rates_loop then
		local index = 1
		self.rates = {}
		self.index = {}
		for _,entry in pairs(data.rates_loop) do
			for k, v in pairs(entry) do
				self.rates[index] = v
				self.index[v] = index
				index = index + 1
			end
		end
		self.default = data.default
	end

	if data.state == 'running' then
		-- update display for current test
		self.rate = data.rate
		self.window:setTitle(tostring(self:string('SETUPNETTEST_TESTING')) .. ' ' .. data.rate .. " kbps")
		self:graph1Update(data.inst)
		self:graph2Update(data.distrib)
		Framework:reDraw(nil)

	elseif self.default then
		self:startTest(self.default)
	end
end


function startTest(self, rate)
	self.server.comet:request(nil, self.player.id, { 'nettest', 'start', rate })
	self.timer.callback()
	self.timer:restart()
end


function stopTest(self)
	self.server.comet:request(nil, self.player.id, { 'nettest', 'stop' })
end


function graph1Update(self, val)
	local graph = self.graph1
	local w, h = graph:getSize()

	graph:blitClip(scroll, 0, w - scroll, h, graph, 0, 0)
	graph:filledRectangle(w - scroll, 0, w, h, graphBG)
	graph:filledRectangle(w - scroll, h - (val * h / 100), w, h, graphFG)
end


function graph2Update(self, distrib)
	local graph = self.graph2
	local w, h = graph:getSize()

	graph:filledRectangle(0, 0, w, h, graphBG)

	local bar = w / #distrib
	local count = 0

	for i, res in ipairs(distrib) do
		for k, v in pairs(res) do
			count = count + v
		end
	end

	if count == 0 then return end

	for i, res in ipairs(distrib) do
		for k, v in pairs(res) do
			k = tonumber(k) or 100
			local color
			if     k > 95 then color = graphG
			elseif k > 80 then color = graphA
			else   color = graphR
			end
			graph:filledRectangle((i-1) * bar, h - (v / count * 100), i * bar - 2, h, color)
		end
	end
end


function skin(self, s)
	s.nettest = {
		icon = {
			padding = { 20, 3, 20, 1 }
		},
		graphtitle = {
			padding = { 20, 7, 0, 0 },
			fg = { 0xE7, 0xE7, 0xE7 }
		},
		graphaxis = {
			padding = { 20, 1, 0, 0 },
			fg = { 0xE7, 0xE7, 0xE7 }
		}
	}
end


function free(self)
	self.timer:stop()
	self:stopTest()
end