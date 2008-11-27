
-- board specific driver
local fab4_bsp               = require("fab4_bsp")

local oo                     = require("loop.simple")
local io                     = require("io")
local string                 = require("string")

local Applet                 = require("jive.Applet")
local System                 = require("jive.System")

local Framework              = require("jive.ui.Framework")
local Popup                  = require("jive.ui.Popup")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Textarea               = require("jive.ui.Textarea")
local Timer                  = require("jive.ui.Timer")

local Watchdog               = require("jiveWatchdog")

local debug                  = require("jive.utils.debug")
local log                    = require("jive.utils.log").logger("applets.setup")

local jnt                    = jnt


module(..., Framework.constants)
oo.class(_M, Applet)


function init(self)
	local uuid, mac

	-- read device uuid
	local f = io.open("/proc/cpuinfo")
	if f then
		for line in f:lines() do
			if string.match(line, "UUID") then
				uuid = string.match(line, "UUID%s+:%s+([%x-]+)")
				uuid = string.gsub(uuid, "[^%x]", "")
			end
		end
		f:close()
	end

	System:init({
		uuid = uuid,
		machine = "fab4",
	})

	mac = System:getMacAddress()
	uuid = System:getUUID()

	if not uuid or string.match(mac, "^00:40:20") then
		local popup = Popup("errorWindow", self:string("INVALID_MAC_TITLE"))

		popup:setAllowScreensaver(false)
		popup:setAlwaysOnTop(true)
		popup:setAutoHide(false)

		local text = Textarea("textarea", self:string("INVALID_MAC_TEXT"))
		local menu = SimpleMenu("menu", {
			{
				text = self:string("INVALID_MAC_CONTINUE"),
				sound = "WINDOWHIDE",
				callback = function()
						   popup:hide()
					   end
			},
		})

		popup:addWidget(text)
		popup:addWidget(menu)
		popup:show()
	end


	-- watchdog timer
	self.watchdog = Watchdog:open()
	if self.watchdog then
		-- allow 30 seconds to boot
		self.watchdog:setTimeout(30)
		local timer = Timer(2000, -- 2 seconds
			function()
				-- 10 second when running
				if not self.watchdogRunning then
					self.watchdog:setTimeout(10)
					self.watchdogRunning = true
				end
				self.watchdog:keepAlive()
			end)
		timer:start()
	else
		log:warn("Watchdog timer is disabled")
	end
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
