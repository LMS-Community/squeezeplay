

-----------------------------------------------------------------------------
-- Convention: functions/methods starting with t_ are executed in the thread
-----------------------------------------------------------------------------



-- stuff we use
local assert, getmetatable, ipairs, pcall, setmetatable, tonumber, tostring = assert, getmetatable, ipairs, pcall, setmetatable, tonumber, tostring

local oo                     = require("loop.simple")

local string                 = require("string")
local table                  = require("jive.utils.table")
local socket                 = require("socket")
local lfs                    = require("lfs")
local os                     = require("os")
local bsp                    = require("jiveBSP")

local Applet                 = require("jive.Applet")
local Framework              = require("jive.ui.Framework")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local Tile                   = require("jive.ui.Tile")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Surface                = require("jive.ui.Surface")
local Textarea               = require("jive.ui.Textarea")
local Textinput              = require("jive.ui.Textinput")
local Window                 = require("jive.ui.Window")
local Popup                  = require("jive.ui.Popup")
local Upgrade                = require("applets.SetupFirmwareUpgrade.Upgrade")

local log                    = require("jive.utils.log").logger("applets.setup")

local jnt                    = jnt
local upgradeUrl             = upgradeUrl

local EVENT_ACTION           = jive.ui.EVENT_ACTION
local EVENT_CONSUME          = jive.ui.EVENT_CONSUME
local EVENT_WINDOW_POP       = jive.ui.EVENT_WINDOW_POP
local LAYER_FRAME            = jive.ui.LAYER_FRAME
local LAYER_CONTENT_ON_STAGE = jive.ui.LAYER_CONTENT_ON_STAGE

local LAYOUT_NORTH           = jive.ui.LAYOUT_NORTH
local LAYOUT_EAST            = jive.ui.LAYOUT_EAST
local LAYOUT_SOUTH           = jive.ui.LAYOUT_SOUTH
local LAYOUT_WEST            = jive.ui.LAYOUT_WEST
local LAYOUT_CENTER          = jive.ui.LAYOUT_CENTER
local LAYOUT_NONE            = jive.ui.LAYOUT_NONE

local EVENT_KEY_PRESS        = jive.ui.EVENT_KEY_PRESS
local EVENT_WINDOW_ACTIVE    = jive.ui.EVENT_WINDOW_ACTIVE
local EVENT_WINDOW_INACTIVE  = jive.ui.EVENT_WINDOW_INACTIVE
local EVENT_CONSUME          = jive.ui.EVENT_CONSUME
local EVENT_UNUSED           = jive.ui.EVENT_UNUSED

local KEY_FWD         = jive.ui.KEY_FWD
local KEY_REW         = jive.ui.KEY_REW
local KEY_GO          = jive.ui.KEY_GO
local KEY_BACK        = jive.ui.KEY_BACK
local KEY_UP          = jive.ui.KEY_UP
local KEY_DOWN        = jive.ui.KEY_DOWN
local KEY_LEFT        = jive.ui.KEY_LEFT
local KEY_RIGHT       = jive.ui.KEY_RIGHT


module(...)
oo.class(_M, Applet)


-- if force is true you can't bump from the menu
function settingsShow(self, force)
	local window = Window("window", self:string("UPDATE"))

	local menu = SimpleMenu("menu")

	log:warn("upgradeUrl=", upgradeUrl[1])

	if upgradeUrl[1] then
		menu:addItem({
				     text = self:string("UPDATE_CONTINUE"),
				     callback = function()
							self.url = upgradeUrl[1]
							self:_upgrade()
						end
			     })
	end

	if lfs.attributes("/mnt/mmc/jive.bin", "mode") == "file" then
		menu:addItem({
				     text = self:string("UPDATE_CONTINUE_SDCARD"),
				     callback = function()
							self.url = "file:/mnt/mmc/jive.bin"
							self:_upgrade()
						end
			     })
	end

	if force then
		menu:setCloseable(false)
	end

	local help = Textarea("help", self:string("UPDATE_CONTINUE_HELP"))
	window:addWidget(help)
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function _checkBattery()
	return bsp.ioctl(23) == 0 or bsp.ioctl(17) > 200
end


function _chargeBattery(self)
	local window = Window("window", self:string("UPDATE_BATTERY"))

	local menu = SimpleMenu("menu",
				{
					{
						text = self:string("UPDATE_CONTINUE"),
						callback = function()
								   if _checkBattery() then
									   self:_upgrade()
								   else
									   window:bumpRight()
								   end
							   end
					}
				})

	local help = Textarea("help", self:string("UPDATE_BATTERY_HELP"))
	window:addWidget(help)
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function _t_setText(self, msg, done)
	jnt:t_perform(function()
			      self.textarea:setValue(self:string(msg))
			      if done then
				      self.icon:setStyle("iconConnected")
			      end
		      end)
end

function _t_upgrade(self)
	local t, err = self.upgrade:start(function(msg)
						  self:_t_setText(msg)
					  end)

	if t == nil then
		-- error
		jnt:t_perform(function()
				      self:_upgradeFailed():showInstead()
			      end)
	else
		self:_t_setText(self:string("UPDATE_REBOOT"), true)

		-- two second delay
		socket.select(nil, nil, 2)

		-- reboot
		log:warn("REBOOTING ...")
		os.execute("/bin/busybox reboot -n -f")
	end
end


function _upgrade(self)
	-- require ac power or sufficient battery to continue
	if not _checkBattery() then
		return self:_chargeBattery()
	end

	local window = Popup("popupIcon")

	self.icon = Icon("iconConnecting")
	window:addWidget(self.icon)

	self.textarea = Label("text", self:string("UPDATE_DOWNLOAD"))
	window:addWidget(self.textarea)

	-- no way to exit this window
	-- FIXME add global handler to block all key events
	window:addListener(EVENT_KEY_PRESS,
			   function(event)
				   return EVENT_CONSUME
			   end)

	-- start the upgrade
	self.upgrade = Upgrade(self.url)
	jnt:perform(function()
			    _t_upgrade(self)
		    end)

	self:tieAndShowWindow(window)
	return window
end


function _upgradeFailed(self)
	local window = Window("window", self:string("UPDATE_FAILURE"))

	local menu = SimpleMenu("menu",
				{
					{
						text = self:string("UPDATE_TRY_AGAIN"),
						callback = function()
								   if _checkBattery() then
									   self:_upgrade():showInstead()
								   else
									   window:bumpRight()
								   end
							   end
					}
				})

	local help = Textarea("help", self:string("UPDATE_FAILURE_HELP"))
	window:addWidget(help)
	window:addWidget(menu)

	return window
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
