
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
local Checkbox         = require("jive.ui.Checkbox")
local Label            = require("jive.ui.Label")
local Group            = require("jive.ui.Group")
local Keyboard         = require("jive.ui.Keyboard")
local SimpleMenu       = require("jive.ui.SimpleMenu")
local Surface          = require("jive.ui.Surface")
local Task             = require("jive.ui.Task")
local Textarea         = require("jive.ui.Textarea")
local Textinput        = require("jive.ui.Textinput")
local Window           = require("jive.ui.Window")

local debug            = require("jive.utils.debug")

local jnt = jnt
local appletManager    = appletManager


module(..., Framework.constants)
oo.class(_M, Applet)


-- ------------------------------ DEVICES ------------------------------ --

local devicesTests = {
	"USB_DISK_VOLUMENAME",
	"USB_DISK_SIZE",
	"USB_DISK_FREE",
	"SD_CARD_VOLUMENAME",
	"SD_CARD_SIZE",
	"SD_CARD_FREE",
}


function setValue(self, menu, key, value)
	if not value then
		value = '-'
	end
	menu:setText(self.labels[key], self:string(key, value))
end


function doDevicesValues(self)
	local usbLabel = tostring( self:string("DEVICES_NONE"))
	local sdCardLabel = tostring( self:string("DEVICES_NONE"))
	local blkid = io.popen("/sbin/blkid")

	-- Allow a-z, A-Z, 0-9, '_' , '-' and ' ' in volume lables => [%w_%- ]
	-- Win2k and OSX 10.6.1 do not allow '.' in volume labels
	for line in blkid:lines() do

		local label = string.match(line, "/dev/sda1:%s*LABEL=\"([%w_%- ]*)\"")
		if label then
			usbLabel = tostring(label)
		else
			-- No LABEL but a UUID means it is 'untitled'
			local uuid = string.match(line, "/dev/sda1:%s*UUID=\"(%S*)\"")
			if uuid then
				usbLabel = tostring( self:string("DEVICES_UNTITLED"))
			end
		end

		label = string.match(line, "/dev/mmcblk0p1:%s*LABEL=\"([%w_%- ]*)\"")
		if label then
			sdCardLabel = tostring(label)
		else
			-- No LABEL but a UUID means it is 'untitled'
			local uuid = string.match(line, "/dev/mmcblk0p1:%s*UUID=\"(%S*)\"")
			if uuid then
				sdCardLabel = tostring( self:string("DEVICES_UNTITLED"))
			end
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

-- ------------------------------ SHARING ------------------------------ --

function _enableSharing(self, window)
	-- enable Samba	
	log:info("Enabling Samba Access")
	os.execute("echo enabled > /etc/samba/status");
	os.execute("/etc/init.d/samba restart");
end


function _disableSharing(self, window)
	-- disable Samba	
	log:info("Disabling Samba Access")
	os.execute("echo disabled > /etc/samba/status");
	os.execute("/etc/init.d/samba stop");
end


function _fileMatch(file, pattern)
	local fi = io.open(file, "r")

	for line in fi:lines() do
		if string.match(line, pattern) then
			fi:close()
			return true
		end
	end
	fi:close()
	
	return false
end


function _updateSharingHelpText(self)
	self.howto = Textarea("help_text", self:string("SHARING_HOWTO", self:getSettings()['sharingAccount'], self:getSettings()['sharingPassword']))
	self.networkSharingMenu:setHeaderWidget(self.howto)
end


function _setSharingAccount(self)
	local window = Window("input", self:string("SHARING_ACCOUNT"), 'setuptitle')
	window:setAllowScreensaver(false)

	local v = Textinput.textValue(self:getSettings()['sharingAccount'], 1, 32)
	local textinput = Textinput("textinput", v,
				function(widget, value)
					value = tostring(value)

					if #value == 0 then
						return false
					end

					-- Remove some special chars samba cannot handle
					value = string.gsub(value, '\\', '')
					value = string.gsub(value, '"', '')
					value = string.gsub(value, "'", '')

					-- Store for later reference
					self:getSettings()['sharingAccount'] = value
					self:storeSettings()

					-- Quote to support spaces etc.
					value = '"' .. value .. '"'

					-- Set samba user alias for root
					-- Samba daemon doesn't need to be restarted
					os.execute("echo 'root = " .. value .. "' > /etc/samba/smbusers")

					self:_updateSharingHelpText()

					-- close the window
					window:playSound("WINDOWHIDE")
					window:hide()

					return true
				end
			)

	local backspace = Keyboard.backspace()
	local group = Group('keyboard_textinput', { textinput = textinput, backspace = backspace } )

        window:addWidget(group)
	window:addWidget(Keyboard("keyboard", 'qwerty', textinput))
        window:focusWidget(group)

--	_helpAction(self, window, 'NETWORK_NETWORK_NAME_HELP', 'NETWORK_NETWORK_NAME_HELP_BODY', menu)

	self:tieAndShowWindow(window)
end


function _setSharingPassword(self)

	local window = Window("input", self:string("SHARING_PASSWORD"), 'setuptitle')
	window:setAllowScreensaver(false)

	-- Allow length to be 0 for no password
	local v = Textinput.textValue(self:getSettings()['sharingPassword'], 0, 32)

	local textinput = Textinput("textinput", v,
				function(widget, value)
					value = tostring(value)

					-- Remove some special chars samba cannot handle
					value = string.gsub(value, "'", "")

					-- Store for later reference
					-- Not sure we want that as it is cleartext
					self:getSettings()['sharingPassword'] = value
					self:storeSettings()

					-- Escape some special chars
					value = string.gsub(value, '\\', '\\\\')
					value = string.gsub(value, '"', '\\"')
					value = string.gsub(value, "`", "\\`")

					-- Quote to support spaces etc.
					value = '"' .. value .. '"'

					-- Set samba password
					-- Samba daemon doesn't need to be restarted
					-- A valid smb.conf file is needed
					os.execute("(echo " .. value .. "; echo " .. value .. ") | smbpasswd -s -a -c /etc/samba/smb.conf.dist root")

					self:_updateSharingHelpText()

					-- close the window
					window:playSound("WINDOWHIDE")
					window:hide()

					return true
				end
			)

	local backspace = Keyboard.backspace()
	local group = Group('keyboard_textinput', { textinput = textinput, backspace = backspace } )

        window:addWidget(group)
	window:addWidget(Keyboard("keyboard", 'qwerty', textinput))
        window:focusWidget(group)

--	_helpAction(self, window, 'NETWORK_NETWORK_NAME_HELP', 'NETWORK_NETWORK_NAME_HELP_BODY', menu)

	self:tieAndShowWindow(window)
end


function showNetworkSharingMenu(self)
	local window = Window("text_list", self:string("SHARING"))
	window:setAllowScreensaver(false)
	window:setButtonAction("rbutton", nil)

	local sharingEnabled = _fileMatch("/etc/samba/status", "enabled")

	local menu = SimpleMenu("menu")

	menu:addItem({
		text = self:string("SHARING_ENABLE"),
		style = 'item_choice',
		check = Checkbox("checkbox",
					function(_, isSelected)
						if isSelected then
							self:_enableSharing()
						else
							self:_disableSharing()
						end
					end,
					sharingEnabled
				)
	})

	menu:addItem({
		text = self:string("SHARING_ACCOUNT"),
		style = 'item',
		sound = "WINDOWSHOW",		
		callback = function ()
			self:_setSharingAccount()
		end
	})

	menu:addItem({
		text = self:string("SHARING_PASSWORD"),
		style = 'item',
		sound = "WINDOWSHOW",		
		callback = function ()
			self:_setSharingPassword()
		end
	})

	self.networkSharingMenu = menu

	self:_updateSharingHelpText()

	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end

-- ------------------------------ Main Menu ---------------------------- --

function SBSSettingsMenu(self)
	local window = Window("text_list", self:string("USB_SD_STORAGE"))
	window:setAllowScreensaver(false)
	window:setButtonAction("rbutton", nil)

	local menu = SimpleMenu("menu")

	self.labels = {}

	menu:addItem({
		text = self:string("DEVICES"),
		style = 'item',
		sound = "WINDOWSHOW",		
		callback = function ()
			self:showDevicesMenu()
		end
	})

	menu:addItem({
		text = self:string("SHARING"),
		style = 'item',
		sound = "WINDOWSHOW",		
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

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

