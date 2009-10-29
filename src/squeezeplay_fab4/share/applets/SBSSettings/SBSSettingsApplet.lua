
local ipairs, tostring = ipairs, tostring, tonumber

-- stuff we use
local oo               = require("loop.simple")
local os               = require("os")
local io               = require("io")
local math             = require("math")
local string           = require("string")
local table            = require("jive.utils.table")
local lfs              = require("lfs")

local Applet           = require("jive.Applet")
local Framework        = require("jive.ui.Framework")
local Label            = require("jive.ui.Label")
local SimpleMenu       = require("jive.ui.SimpleMenu")
local Surface          = require("jive.ui.Surface")
local Task             = require("jive.ui.Task")
local Textarea         = require("jive.ui.Textarea")
local Window           = require("jive.ui.Window")

local debug            = require("jive.utils.debug")

local jnt = jnt
local appletManager    = appletManager


module(..., Framework.constants)
oo.class(_M, Applet)


local devicesTests = {
	"USB_DISK_VOLUMENAME",
	"USB_DISK_SIZE",
	"USB_DISK_FREE",
	"SD_CARD_VOLUMENAME",
	"SD_CARD_SIZE",
	"SD_CARD_FREE",
}


local networkSharingTests = {
	"SHARING_ENABLE",
	"SHARING_ACCOUNT",
	"SHARING_PASSWORD",
}


function setValue(self, menu, key, value)
	if not value then
		value = '-'
	end
	menu:setText(self.labels[key], self:string(key, value))
end


function doDevicesValues(self)
	local usbLabel = "none"
	local sdCardLabel = "none"
	local blkid = io.popen("/sbin/blkid")

	for line in blkid:lines() do
		local label = string.match(line, "/dev/sda1:%s*LABEL=\"(%S*)\"")
		if label then
			usbLabel = tostring(label)
		end

		label = string.match(line, "/dev/mmcblk0p1:%s*LABEL=\"(%S*)\"")
		if label then
			sdCardLabel = tostring(label)
		end
	end
	blkid:close()
	self:setValue(self.devicesMenu, "USB_DISK_VOLUMENAME", usbLabel)
	self:setValue(self.devicesMenu, "SD_CARD_VOLUMENAME", sdCardLabel)

	local usbSize = "-"
	local usbFree = "-"
	local sdCardSize = "-"
	local sdCardFree = "-"
	local df = io.popen("/bin/df")

	for line in df:lines() do
		local size, free = string.match(line, "/dev/sda1%s*(%d+)%s*%d+%s*(%d+)")
		if size and free then
			usbSize = tostring(math.floor(size / 1000)) .. " MB"
			usbFree = tostring(math.floor(free / 1000)) .. " MB"
		end

		size, free = string.match(line, "/dev/mmcblk0p1%s*(%d+)%s*%d+%s*(%d+)")
		if size and free then
			sdCardSize = tostring(math.floor(size / 1000)) .. " MB"
			sdCardFree = tostring(math.floor(free / 1000)) .. " MB"
		end
	end
	df:close()
	self:setValue(self.devicesMenu, "USB_DISK_SIZE", usbSize)
	self:setValue(self.devicesMenu, "USB_DISK_FREE", usbFree)
	self:setValue(self.devicesMenu, "SD_CARD_SIZE", sdCardSize)
	self:setValue(self.devicesMenu, "SD_CARD_FREE", sdCardFree)
end


function showDevicesMenu(self)
	local window = Window("text_list", self:string("DEVICES"))
	window:setAllowScreensaver(false)
	window:setButtonAction("rbutton", nil)

	local menu = SimpleMenu("menu")

	self.labels = {}

	for i,name in ipairs(devicesTests) do
		self.labels[name] = {
			text = self:string(name, ''),
			style = 'item_info',
		}
		menu:addItem(self.labels[name])
	end

	self.devicesMenu = menu
	doDevicesValues(self)
	menu:addTimer(5000, function()
		doDevicesValues(self)
	end)

	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function showNetworkSharingMenu(self)
	local window = Window("text_list", self:string("NETWORK_SHARING"))
	window:setAllowScreensaver(false)
	window:setButtonAction("rbutton", nil)

	local menu = SimpleMenu("menu")

	self.labels = {}

	for i,name in ipairs(networkSharingTests) do
		self.labels[name] = {
			text = self:string(name, ''),
			style = 'item_info',
		}
		menu:addItem(self.labels[name])
	end

	self.networkSharingMenu = menu
--	doNetworkSharingValues(self)
--	menu:addTimer(5000, function()
--		doNetworkSharingValues(self)
--	end)

	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function SBSSettingsMenu(self)
	local window = Window("text_list", self:string("USB_SD_STORAGE"))
	window:setAllowScreensaver(false)
	window:setButtonAction("rbutton", nil)

	local menu = SimpleMenu("menu")

	self.labels = {}

	menu:addItem({
		text = self:string("DEVICES"),
		style = 'item',
		callback = function ()
			self:showDevicesMenu()
		end
	})

	menu:addItem({
		text = self:string("NETWORK_SHARING"),
		style = 'item',
		callback = function ()
			self:showNetworkSharingMenu()
		end
	})

	self.sbsSettingsMenu = menu
--	doValues(self)
--	menu:addTimer(5000, function()
--		doValues(self)
--	end)

	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


--[[

=head1 LICENSE

Copyright 2009 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

