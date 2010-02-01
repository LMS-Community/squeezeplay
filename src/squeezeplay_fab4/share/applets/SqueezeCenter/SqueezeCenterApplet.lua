local load, ipairs, pairs, type, tostring, tonumber  = load, ipairs, pairs, type, tostring, tonumber

-- stuff we use
local math             = require("math")
local json             = require("json")
local table            = require("jive.utils.table")
local string           = require("jive.utils.string")
local squeezeos        = require("jive.utils.squeezeos")
local debug            = require("jive.utils.debug")

local oo                     = require("loop.simple")
local io                     = require("io")
local os                     = require("os")

local Applet                 = require("jive.Applet")
local Framework              = require("jive.ui.Framework")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local Popup                  = require("jive.ui.Popup")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Textarea               = require("jive.ui.Textarea")
local Task                   = require("jive.ui.Task")
local Timer                  = require("jive.ui.Timer")
local Window                 = require("jive.ui.Window")

local appletManager          = appletManager
local jiveMain               = jiveMain


module(..., Framework.constants)
oo.class(_M, Applet)

function init(self)
	self.mountedDevices = self:getSettings()['mountedDevices']
	self.ejectItems     = {}
	self.MOUNTING_DRIVE_TIMEOUT = 30
	self.UNMOUNTING_DRIVE_TIMEOUT = 10
	self.WIPE_TIMEOUT = 60
	self.supportedFormats = {"FAT16","FAT32","NTFS","ext2","ext3"}
	self.prefsFile = "/etc/squeezecenter/prefs.json"

	self.settingsMenuItems = {
		startServer = {
			text = self:string("START"),
			sound = "WINDOWSHOW",
			callback = function()
					self:_startServerWindow()
				   end
		},
		wipeRescan = {
			text = self:string("WIPE_AND_RESTART"),
			sound = "WINDOWSHOW",
			callback = function()
					self:_confirmWipeRescan()
				   end
		},
		stopServer = {
			text = self:string("STOP"),
			sound = "WINDOWSHOW",
			callback = function()
					self:_confirmStopServer()
				   end
		}
	}
	
end

-- do the right thing on jive startup
function squeezecenterStartupCheck(self)

	-- the startup check is re-initializing which drives are mounted, so whatever is pulled from settings in init() needs clearing here first
	self.mountedDevices = {}


	local mountedDrives       = self:mountedDriveCheck()
	local usbDrives           = {}
	local sdDrives            = {}
	local mountedDrivePresent = false
	local usbDrivePresent     = false

	for k, v in pairs(mountedDrives) do
		mountedDrivePresent = true
		if self:mediaType(k) == 'USB' then
			log:debug('STARTUP| USB drive detected in mounted drives: ', v)
			usbDrivePresent = true
			usbDrives[k] = v
		else
			log:debug('STARTUP| SD drive detected in mounted drives: ', v)
			sdDrives[k] = v
		end
	end

	-- mounted drive present
	if mountedDrivePresent then
		log:debug('STARTUP (1) | Mounted Drive Detected')
		local prefs = self:readSCPrefsFile()
		-- prefs.json present
		if prefs and prefs.mountpath then
			log:debug('STARTUP (2A)| prefs.json detected')
			local devName = string.match(prefs.mountpath, "/media/(%w*)")
			-- mountpath represents a mounted drive
			if mountedDrives[devName] then 
				log:debug('STARTUP (3A)| prefs.json mountpath represents a mounted drive')
                        	-- store device in self.mountedDevices
				self:addMountedDevice(devName, true)
			-- mountpath represents an umounted drive
			else
				log:debug('STARTUP (3B)| prefs.json mountpath is not a mounted drive')
				local scDrive
				if usbDrivePresent then
				log:debug('STARTUP (4A)| USB drive present')
					scDrive = self:_firstTableElement(usbDrives)
				else
				log:debug('STARTUP (4B)| SD drive present')
					scDrive = self:_firstTableElement(mountedDrives)
				end
				-- write prefs.json
				log:debug('STARTUP (5)| Write prefs.json file')
				self:addMountedDevice(scDrive, true)
				self:_writeSCPrefsFile(scDrive)

			end
				
		-- prefs.json not present
		else
			log:debug('STARTUP (2B)| No prefs.json file found')
			local scDrive
			if usbDrivePresent then
				log:debug('STARTUP (4A)| USB drive will be the tinySC Drive')
				scDrive = self:_firstTableElement(usbDrives)
			else
				log:debug('STARTUP (4B)| SD drive will be the tinySC Drive')
				scDrive = self:_firstTableElement(mountedDrives)
			end
			-- write prefs.json
			log:debug('STARTUP (5)| Write prefs.json file')
			self:addMountedDevice(scDrive, true)
			self:_writeSCPrefsFile(scDrive)
		end

		log:debug('STARTUP (6)| Restart Server')
		self:restartServer(true)

		-- populate non-SC mounted drives to self.mountedDevices
		-- create menu items for each
		for k, v in pairs(mountedDrives) do
			if not self.mountedDevices[k] then
				self:addMountedDevice(k, false)
			end
			log:debug('STARTUP (7)| Create eject item for ', k)
			self:_addEjectDeviceItem(k)
		end
	else
		-- remove mounted devices from settings since we don't have any
		self:getSettings()['mountedDevices'] = self.mountedDevices
		self:storeSettings()
	end

end


function _firstTableElement(self, t)
	for k, v in pairs(t) do
		return k, v 
	end
end


function addMountedDevice(self, devName, isSCDrive)
	log:warn('addMountedDevice: ', devName)
	self.mountedDevices[devName] = {
		devName    = devName,
		deviceName = "/dev/"   .. devName,
		mountPath  = "/media/" .. devName,
		devType    = self:mediaType(devName),
		SCDrive    = isSCDrive,
	}
	self:getSettings()['mountedDevices'] = self.mountedDevices
	self:storeSettings()
	--debug.dump(self.mountedDevices)
	return true
end

function settingsShow(self)
	-- Squeezebox Server is Squeezebox Server in all langs, so no need to translate title text
	local window = Window("text_list", 'Squeezebox Server')
	
	window:setAllowScreensaver(false)
	-- XXX: first attempt at showing scan process running
	self.status = Textarea("help_text", self:_getStatusText() )

	self.settingsMenu = SimpleMenu("menu")

	self:_updateSettingsMenu()

	self.settingsMenu:setHeaderWidget(self.status)
	window:addWidget(self.settingsMenu)
	
	window:addTimer(5000, 
		function() 
			_updateStatus(self) 
			_updateSettingsMenu(self)
		end)
	
	self:tieAndShowWindow(window)
	return window
end


function _updateSettingsMenu(self)
	log:debug('_updateSettingsMenu()')
	if self:serverRunning() then
		log:debug('server is running')
		if not self.settingsMenu:getIndex(self.settingsMenuItems.stopServer) then
			self.settingsMenu:addItem(self.settingsMenuItems.stopServer)
		end
		if self.settingsMenu:getIndex(self.settingsMenuItems.startServer) then
			self.settingsMenu:removeItem(self.settingsMenuItems.startServer)
		end
		if self.settingsMenu:getIndex(self.settingsMenuItems.wipeRescan) then
			self.settingsMenu:removeItem(self.settingsMenuItems.wipeRescan)
		end
	else
		log:debug('server is not running')
		if not self.settingsMenu:getIndex(self.settingsMenuItems.startServer) then
			log:debug('add start item')
			self.settingsMenu:addItem(self.settingsMenuItems.startServer)
		end
		if not self.settingsMenu:getIndex(self.settingsMenuItems.wipeRescan) then
			log:debug('add rescan item')
			self.settingsMenu:addItem(self.settingsMenuItems.wipeRescan)
		end
		if self.settingsMenu:getIndex(self.settingsMenuItems.stopServer) then
			log:debug('remove stop item')
			self.settingsMenu:removeItem(self.settingsMenuItems.stopServer)
		end
	end

end

function _squeezecenterAction(self, icon, text, subtext, time, action, silent)

	-- Check validity of action
	if (
		action == 'start' and ( self:serverRunning() or self:scannerRunning() )
		or action == 'stop' and not self:serverRunning() 
		or action == 'rescan' and self:scannerRunning() )
	then
		return EVENT_UNUSED
	end

	if not silent then
		local popup = Popup("waiting_popup")
		popup:addWidget(Icon(icon))
		popup:addWidget(Label("text", self:string(text)))
		
		if (subtext ~= nil) then popup:addWidget(Textarea("subtext", self:string(subtext))) end
		
		popup:showBriefly(time,
			function()
				_updateStatus(self)
			end,
			Window.transitionPushPopupUp,
			Window.transitionPushPopupDown
		)
	end

	if action == 'stop' then
		-- don't use shell script, we might be out of memory
		if self:serverRunning() then

			-- stop server
			squeezeos:killByPidFile("/var/run/squeezecenter.pid")
			
			-- stop resize helper daemon
			squeezeos:killByPidFile("/var/run/gdresized.pid")
	
			-- stop scanner
	--		local pid = _pidfor('scanner.pl')
	--		if pid then
	--			squeezeos.kill(pid, 15)
	--		end
		end

	else
		os.execute("/etc/init.d/squeezecenter " .. action);
	end
end

function _getStatusText(self)

	local statusText

	-- server is not running
	if not self:serverRunning() then
		return self:string('STATUS_NOTHING')

	-- server is running
	else
		-- server running string
		--return self:string("STATUS_SQUEEZECENTER_RUNNING")

		-- server is running, check scan.json file
		local scanData = self:_scanStatus()

		-- scan.json file exists
		if scanData then
			statusText = self:_parseScanData(scanData)

		-- server is running but no scan.json. PUNT!
		else
			statusText = self:string('SCANNER_NO_STATUS')
		end
	end

	log:debug('statusText: ', statusText)
	return statusText
end


function _updateStatus(self)
	if self.status then
		self.status:setValue( self:_getStatusText() )
	end
end


-- udevHandler takes events on udev and decides whether and when to kick off the scanner
function udevEventHandler(self, evt, msg)

	log:debug('udevEventHandler()')

	-- work in progress: useful for viewing what's in the msg table
	--[[
	for k, val in pairs(msg) do
		log:warn('key: ', k, ' val: ', val)
	end
	--]]

	-- if the ACTION in the msg is add and DEVTYPE is partition
	-- 	bring up a spinny "Checking Drive..."
	--	we should start polling mount to see if a drive gets mounted rw
	--	if it does, hide the popup, start the scanner (/etc/init.d/squeezecenter rescan), and push to the SqueezeCenter menu
	--	if it doesn't, popup an appropriate error
	if msg and ( msg.ACTION == 'add' or msg.ACTION == 'remove' ) and msg.DEVTYPE == 'partition' then
		local devPath = msg.DEVPATH
		-- Extract device name (last element)
		local pathElements = string.split('/', devPath)
		local devName = pathElements[#pathElements]
		-- devName that begins with mmc* is an SD card
		-- devName that starts with sd* is a USB device
		if msg.ACTION == 'add' then
			log:debug("Attaching Device: ", devName)

			self:_mountingDrive(devName)
		else
			log:debug('Device Removal Detected: ', devName)
			self:_deviceRemoval(devName)
		end
	end
end

function mediaType(self, devName)
	if string.match(devName, "^sd") then
		return 'USB'
	elseif string.match(devName, "^mmc") then
		return 'SD'
	end
	return false
end

-- _mountingDrive
-- full screen popup that appears until mounting is complete or failed
---function _mountingDrive(self)
function _mountingDrive(self, devName)
	log:debug('**** popup during drive mount')
	if self.popupMountWaiting then
		return
	end

        local popup = Popup("waiting_popup")
        local icon  = Icon("icon_connecting")

	-- set self.devType var based on devName during the _mountingDrive method
	self.devType = self:mediaType(devName)
	self.mountingDriveTimeout = 0

	icon:addTimer(1000,
		function()
			_mountingDriveTimer(self, devName)
		end)

        popup:addWidget(icon)

	local label = Label("text", self:string('ATTACHING') )
	popup:addWidget(label)

	local token = 'DEVICE'
	if self.devType then
		token = self.devType
	end
	local sublabel = Label("subtext", self:string(token) )
	popup:addWidget(sublabel)

	self.popupMountWaiting = popup
	self:tieAndShowWindow(popup)
	return popup
end


-- _deviceRemoval
-- kicked off when udev listener detects a device removal
-- checks if device is still in mount table, 
-- if so push on the DON'T DO THAT window, stop SC if drive was attached to SC
---function _mountingDrive(self)
function _deviceRemoval(self, devName)

	-- if devName is still in the self.mountedDevices table, consider this an unsafe eject
	if self.mountedDevices and self.mountedDevices[devName] then
		
		log:warn('!!! Drive ', self.mountedDevices[devName].deviceName, ' was unsafely ejected.')
		local window = Window("text_list", self:string("DEVICE_REMOVAL_WARNING"))
		window:setAllowScreensaver(false)
		local menu = SimpleMenu("menu")
		menu:addItem({
			text = self:string("OK"),
			style = 'item',
			sound = "WINDOWSHOW",		
			callback = function ()
				window:hide()
			end
		})

		local token = 'DEVICE_REMOVAL_WARNING_INFO'
		if self.mountedDevices[devName].devType then
			token = token .. '_' .. self.mountedDevices[devName].devType
		end
	
		menu:setHeaderWidget( Textarea("help_text", self:string(token) ) )
		window:addWidget(menu)

		if self.mountedDevices[devName].SCDrive then
			log:warn('SqueezeCenter drive was improperly ejected. Stopping SqueezeCenter')
			self:_stopServer(silent)
		end
		self.mountedDevices[devName] = nil
		self:getSettings()['mountedDevices'] = self.mountedDevices
		self:storeSettings()
		
		self:tieAndShowWindow(window)
		return window
	end

end


function _unmountActions(self, devName, silent, force)

	local item = self:_getItemFromDevName(devName)
	if item.SCDrive then
		self:_stopServer(silent)
	else
		log:debug('This is not the SCDrive, so ')
	end
	if force then
		os.execute("umount -l /media/" .. devName)
	else
		os.execute("umount /media/" .. devName)
	end

end


function _stopServer(self, silent)
	if self:serverRunning() then
		-- attempt to stop SC
		log:debug('STOP SERVER')
		self:_squeezecenterAction("icon_connecting", "STOPPING_SQUEEZECENTER", nil, 3000, "stop", silent)
	end

end

function stopSqueezeCenter(self)
	self:_stopServer(true)
end


-- _unmountingDrive
-- full screen popup that appears until unmounting is complete or failed
function _unmountDrive(self, devName, force)
	
	log:warn('_unmountDrive() ', devName)

	local item = self:_getItemFromDevName(devName)


	-- require that we have an item.devPath to eject
	if not item.mountPath then
		log:warn("no mountPath to eject item")
		return EVENT_UNUSED
	end

	self:_unmountActions(devName, _, force)

	if self.popupUnmountWaiting then
		return
	end

        local popup = Popup("waiting_popup")
        local icon  = Icon("icon_connecting")

	-- set self.devType var based on devName during the _mountingDrive method
	self.devType = self:mediaType(devName)
	self.unmountingDriveTimeout = 0

	icon:addTimer(1000,
		function()
			_unmountingDriveTimer(self, devName)
		end)

        popup:addWidget(icon)

	local label = Label("text", self:string('EJECTING') )
	popup:addWidget(label)

	local token = 'DEVICE'
	if self.devType then
		token = self.devType
	end
	local sublabel = Label("subtext", self:string(token) )
	popup:addWidget(sublabel)

	self.popupUnmountWaiting = popup
	self:tieAndShowWindow(popup)
	return popup
end


function _mountingDriveTimer(self, devName)
	local mounted = false

	Task("mountingDrive", self, function()
		log:debug("mountingDriveTimeout=", self.mountingDriveTimeout)

		mounted = self:checkDriveMounted(devName)

		if mounted then
			-- success
			log:debug("*** Device mounted sucessfully.")


			-- store device in self.mountedDevices
			local isScDrive = true
			for k, v in pairs (self.mountedDevices) do
				if v.SCDrive then
					isScDrive = false
				end
			end

			self:addMountedDevice(devName, isScDrive)

			self:_ejectWarning(devName)
			self:_addEjectDeviceItem(devName)
		else
			-- Not yet mounted
			self.mountingDriveTimeout = self.mountingDriveTimeout + 1
			if self.mountingDriveTimeout <= self.MOUNTING_DRIVE_TIMEOUT then
				return
			end

			-- failure
			log:warn("*** Device failed to mount.")

			self:_unsupportedDiskFormat()
		end

		self.popupMountWaiting:hide()
		self.popupMountWaiting = nil

	end):addTask()
end


function _unmountingDriveTimer(self, devName)
	local unmounted = false

	Task("unmountingDrive", self, function()
		log:debug("unmountingDriveTimeout=", self.unmountingDriveTimeout)

		unmounted = self:_checkDriveUnmounted(devName)

		if unmounted then
			-- success
			log:warn("*** Device ", devName, " unmounted sucessfully.")

			self:_removeEjectDeviceItem(devName)

			-- rmdir cleanup of /media/devName, as stale dirs appear to be a problem after umount
			if self:_mediaDirExists(devName) then
				os.execute("rmdir /media/" .. devName)
			end

			self:_unmountSuccess(devName)


		else
			-- Not yet unmounted
			self.unmountingDriveTimeout = self.unmountingDriveTimeout + 1
			if self.unmountingDriveTimeout <= self.UNMOUNTING_DRIVE_TIMEOUT then
				log:warn("*** Device failed to unmount. try again")
				log:warn("*** self.unmountingDriveTimeout: ", self.unmountingDriveTimeout)
				log:warn("*** self.UNMOUNTING_DRIVE_TIMEOUT: ", self.UNMOUNTING_DRIVE_TIMEOUT)
				-- try again
				self:_unmountActions(devName, true)
				return
			end

			-- failure
			log:warn("*** Device failed to unmount.")

			self:_unmountFailure(devName)
		end

		self.popupUnmountWaiting:hide()
		self.popupUnmountWaiting = nil

	end):addTask()
end


function _unmountSuccess(self, devName)
	log:debug('_unmountSuccess()')
	local item = self:_getItemFromDevName(devName)
	local token = 'DEVICE_EJECTED_INFO'
	if item.devType then
		token = token .. "_" .. item.devType
	end

	if self.confirmEjectWindow then
		self.confirmEjectWindow:hide()
		self.confirmEjectWindow = nil
	end


	-- clear device from self.mountedDevices
	if self.mountedDevices and self.mountedDevices[devName] then
		self.mountedDevices[devName] = nil
	end


	local window = Window("text_list", self:string("DEVICE_EJECTED"))
	window:setAllowScreensaver(false)
	window:setButtonAction("rbutton", nil)

	local menu = SimpleMenu("menu")

	menu:addItem({
		text = self:string("OK"),
		style = 'item',
		sound = "WINDOWSHOW",		
		callback = function ()
			window:hide()
		end
	})

	menu:setHeaderWidget( Textarea("help_text", self:string(token) ) )

	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


-- TODO
function _unmountFailure(self, devName)
	log:warn('_unmountFailure()')

	local window = Window("text_list", self:string("EJECT_FAILURE"))
	window:setAllowScreensaver(false)
	window:setButtonAction("rbutton", nil)

	local menu = SimpleMenu("menu")

	menu:addItem({
		text = self:string("OK"),
		style = 'item',
		sound = "WINDOWSHOW",		
		callback = function ()
			window:hide()
		end
	})
	menu:addItem({
		text = self:string("EJECT_TRY_AGAIN"),
		style = 'item',
		sound = "WINDOWSHOW",		
		callback = function ()
			-- force the umount with -l
			window:hide()
			self:_unmountDrive(devName, true)
		end
	})


	menu:setHeaderWidget( Textarea("help_text", self:string('EJECT_FAILURE_INFO') ) )

	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function _removeEjectDeviceItem(self, devName)
	log:debug('_removeEjectDeviceItem()')
	if self.ejectItems and self.ejectItems[devName] then
		log:debug('removing menu item for ', devName)
		jiveMain:removeItem(self.ejectItems[devName])
		self.ejectItems[devName] = nil
	else
		log:warn('no menu item found for ', devName)
	end
end


function _addEjectDeviceItem(self, devName)

	log:debug('_addEjectDeviceItem()')

	local item = self.mountedDevices and self.mountedDevices[devName]

	local token = 'EJECT_CONFIRM_ITEM'
	if item.devType then
		token = 'EJECT_' .. item.devType
	end

	self.ejectItems[devName] = {
                id = item.devName,
                node = "home",
                text = self:string(token),
                iconStyle = 'hm_eject',
                weight = 5,
		sound = "WINDOWSHOW",		
                --weight = 1000,
		-- TODO: add a method to eject the device (that works!)
		callback = function()
			self:_confirmEject(devName)
		end,
        }
	jiveMain:addItem(self.ejectItems[devName])
end


function _confirmWipeRescan(self)
	log:debug('confirmWipeRescan()')
	local callbackFunction = function() 
		self:_wipeRescan()
		self.confirmWindow:hide()
	end
	
	return self:_confirmWindow('WIPE_AND_RESTART', 'WIPE_AND_RESTART_INFO', callbackFunction)
end


function _confirmStopServer(self)
	log:debug('confirmStopServer()')
	local callbackFunction = function() 
		appletManager:callService('goHome')
		self:_squeezecenterAction("icon_connecting", "STOPPING_SQUEEZECENTER", nil, 2000, "stop")
	end
	
	return self:_confirmWindow('STOP', 'STOP_INFO', callbackFunction)
end


function _wipeRescan(self)

	log:debug('**** popup during wipe of .Squeezebox dir')
	if self.popupRescanWaiting then
		return
	end

        local popup = Popup("waiting_popup")
        local icon  = Icon("icon_connecting")

	local scDrive = self:_scDrive()
	if not scDrive then
		self:_startServerWindow()
	end

	-- wipe the .Squeezebox directory forcefully through linux
	local command = "rm -rf " .. scDrive .. "/.Squeezebox &"
	os.execute(command)

	self.wipeTimeout = 0

	icon:addTimer(1000,
		function()
			_wipeTimer(self, scDrive)
		end)

        popup:addWidget(icon)

	local label = Label("text", self:string('REMOVING_DATABASE') )
	popup:addWidget(label)

	self.popupRescanWaiting = popup
	self:tieAndShowWindow(popup)
	
end


function _wipeTimer(self, scDrive)

	local present = false

	Task("wipeRescan", self, function()
		log:debug("wipeRescan=", self.wipeTimeout)

		present = self:squeezeboxDirPresent(scDrive)

		if present then
			-- Not yet wiped
			self.wipeTimeout = self.wipeTimeout + 1
			if self.wipeTimeout <= self.WIPE_TIMEOUT then
				return
			end

			-- failure
			log:warn("*** .Squeezebox dir failed to be successfully removed from ", scDrive)
		else
			-- success
			log:debug("*** ", scDrive, ", /.Squeezebox area of sucessfully removed.")

		end

		self.popupRescanWaiting:hide()
		self.popupRescanWaiting = nil
		self:_startServerWindow()
	end):addTask()
end


function _startServerWindow(self)

	local mountedDrives = 0
	for k, v in pairs(self.mountedDevices) do
		mountedDrives = mountedDrives + 1
	end

	local window, menu

	log:debug(mountedDrives, ' mounted drive(s) found')
	if mountedDrives == 0 then
		log:debug('No drives detected')
		window = Window("text_list", self:string('NO_DRIVES_DETECTED') )
		menu = SimpleMenu("menu", {
			{
				text = self:string("OK"),
				style = 'item',
				sound = "WINDOWSHOW",		
				callback = function ()
					window:hide()
				end
			}
		})
		menu:setHeaderWidget( Textarea("help_text", self:string('NO_DRIVES_DETECTED_INFO')))

	elseif mountedDrives == 1 then
		self:_squeezecenterAction("icon_connecting", "STARTING_SQUEEZECENTER", nil, 5000, "start")
		return EVENT_CONSUMED

	else
		window = Window("text_list", self:string('MULTIPLE_DRIVES_DETECTED') )
		menu = SimpleMenu("menu", {
			{
				text = self:string("CANCEL"),
				sound = "WINDOWHIDE",
				callback = function() 
					window:hide()
				end
			},
		})

		for devName, item in pairs(self.mountedDevices) do
			local iconStyle = 'hm_usbdrive'
			local menuItemToken = 'USE_DRIVE_USB'
			if self:mediaType(devName) == 'SD' then
				iconStyle = 'hm_sdcard'
				menuItemToken = 'USE_DRIVE_SD'
			end
			menu:addItem({
				text = self:string(menuItemToken),
	                	iconStyle = iconStyle,
				sound = 'WINDOWSHOW',
				callback = function()
					log:debug('write prefs.json file to use ', devName)
					self:_writeSCPrefsFile(devName)
					self:_squeezecenterAction("icon_connecting", "STARTING_SQUEEZECENTER", nil, 5000, "start")
					self:settingsShow()
					window:hide()
				end
			})
		end
		menu:setHeaderWidget( Textarea("help_text", self:string('MULTIPLE_DRIVES_DETECTED_INFO')))

	end

	window:setAllowScreensaver(false)
	window:addWidget(menu)
	self:tieAndShowWindow(window)
	return window

end

function _confirmWindow(self, titleToken, helpTextToken, callbackFunction)

	self.confirmWindow = Window("text_list", self:string(titleToken) )
	local menu = SimpleMenu("menu", {
			{
				text = self:string("CANCEL"),
				sound = "WINDOWHIDE",
				callback = function() 
					self.confirmWindow:hide()
					self.confirmWindow = nil
				end
			},
			{
				text = self:string(self:string(titleToken)),
				sound = "WINDOWSHOW",
				callback = callbackFunction,
			},
	})

	menu:setHeaderWidget( Textarea("help_text", self:string(helpTextToken) ) )
	self.confirmWindow:addWidget(menu)
	self:tieAndShowWindow(self.confirmWindow)
	return self.confirmWindow
end


function _confirmEject(self, devName)
	log:debug('confirmEject()')
	local item = self:_getItemFromDevName(devName)

	local titleToken   = 'EJECT_CONFIRM'
	local confirmToken = 'EJECT_CONFIRM_INFO'
	local ejectToken   = 'EJECT_REMOVABLE_MEDIA'

	if item.devType then
		titleToken   = 'EJECT_CONFIRM_' .. item.devType
		confirmToken = 'EJECT_CONFIRM_INFO_' .. item.devType
		ejectToken   = 'EJECT_DRIVE_' .. item.devType
	end
	local window = Window("text_list", self:string(titleToken) )
	local menu = SimpleMenu("menu", {
			{
				text = self:string("CANCEL"),
				sound = "WINDOWHIDE",
				callback = function() 
					window:hide()
				end
			},
			{
				text = self:string(ejectToken, item.devName),
				sound = "WINDOWSHOW",
				callback = function() 
					-- eject drive
					self:_unmountDrive(devName)
				end
			},
	})

	menu:setHeaderWidget( Textarea("help_text", self:string(confirmToken, item.devName) ) )
	window:addWidget(menu)
	self.confirmEjectWindow = window
	self:tieAndShowWindow(window)
	return window
end


function _getItemFromDevName(self, devName)
	return self.mountedDevices and 
		self.mountedDevices[devName]
end


function restartServer(self, silent)
	log:warn('Restarting squeezebox server')
	self:_squeezecenterAction("icon_connected", "RESTARTING_SQUEEZECENTER", "PLEASE_WAIT", 5000, "restart", silent)

end


-- returns table of devNames for mounted devices
function mountedDriveCheck(self)
        local mount = io.popen("/bin/mount")

	local mountedDrives = {}

	local foundOne = nil
        for line in mount:lines() do
                local stringMatch = string.match(line, "/media/(%w*)")
		if stringMatch then
			log:debug('Mounted drive found at /media/', stringMatch)
			mountedDrives[stringMatch] = "/media/" .. stringMatch
		end
        end
        mount:close()

        return mountedDrives
end


-- will return true if .Squeezebox is listed in the output of the ls command for scDrive
function squeezeboxDirPresent(self, scDrive)
	local present = false
	local command = "/bin/ls -A " .. scDrive
	local ls = io.popen(command)

	for line in ls:lines() do
		local match = string.match(line, "^\.") -- we can quit after going through . files
		if match then
			present = string.match(line, "^\.Squeezebox")
			if present then
				log:warn("squeezeboxDirPresent(), found it: ", present)
				break
			end
		else
			break
		end
	end
	ls:close()

	log:warn(scDrive, "/.Squeezebox present: ", present)

	if present then
		return true
	end

	return false
end


-- will return true if /media/<devName> is listed in the output of the mount command
function checkDriveMounted(self, devName)
	local format = nil
	local mount = io.popen("/bin/mount")

	for line in mount:lines() do
		local dummy = string.match(line, "/dev/" .. devName)
		if dummy then
			format = string.match(line, "type (%w*)")
		end
	end
	mount:close()

	if format then
		log:debug("New device: /dev/", devName, " formatted with: ", format)
		return true
	end

	return false
end


function _mediaDirExists(self, devName)
	local dirExists = nil
	local mount = io.popen("/bin/ls /media")

	log:debug('--- ', devName)
	for line in mount:lines() do
		local stringMatch = string.match(line, devName)
		if stringMatch then
			dirExists = true
		end
	end
	mount:close()

	if dirExists then
		return true
	end

	return false
end


function _checkDriveUnmounted(self, devName)
	local devMount = nil
	local mount = io.popen("/bin/mount")

	log:debug('--- ', devName)
	for line in mount:lines() do
		local stringMatch = string.match(line, "/dev/" .. devName)
		log:debug('--- ', line, '--- ', devMount)
		if stringMatch then
			devMount = string.match(line, "type (%w*)")
		end
	end
	mount:close()

	if devMount then
		log:warn("Device: /dev/", devName, " is still in the mount table")
		return false
	end

	return true
end


-- Not supported disk format error message
function _unsupportedDiskFormat(self)
	local window = Window("text_list", self:string("UNSUPPORTED_DISK_FORMAT"))
	window:setAllowScreensaver(false)
	window:setButtonAction("rbutton", nil)

	local menu = SimpleMenu("menu")

	menu:addItem({
		text = self:string("OK"),
		style = 'item',
		sound = "WINDOWSHOW",		
		callback = function ()
			window:hide()
		end
	})

	local formatsString = table.concat(self.supportedFormats, ", ")

	local token = 'UNSUPPORTED_DISK_FORMAT_INFO'
	if self.devType then
		token = 'UNSUPPORTED_DISK_FORMAT_INFO_' .. self.devType
	end
	menu:setHeaderWidget( Textarea("help_text", self:string(token, formatsString) ) )

	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


-- Ejection Warning for new USB/SD drives
function _ejectWarning(self, devName)

	local item = self:_getItemFromDevName(devName)

	local window = Window("text_list", self:string("EJECT_WARNING"))
	window:setAllowScreensaver(false)
	window:setButtonAction("rbutton", nil)

	local menu = SimpleMenu("menu")


	if item.SCDrive then


		-- Server status
		menu:addItem({
			text = self:string("SERVER_STATUS"),
			iconStyle = 'hm_advancedSettings',
			sound = "WINDOWSHOW",		
			callback = function()
				self:settingsShow()
				window:hide()
			end,
		})

		-- My Music
		--[[ FIXME: does not provide a positive user experience yet. Going to My Music when scan is just starting yields not good behavior
		menu:addItem({
			text = self:string("MY_MUSIC"),
			iconStyle = 'hm_appletCustomizeHome',
			sound = "WINDOWSHOW",		
			callback = function()
				--Framework:pushAction("go_music_library")
				--window:hide()
				log:warn('my music!')
			        if jiveMain:getMenuTable()['_myMusic'] then
	                 	       Framework:playSound("JUMP")
					debug.dump(jiveMain:getMenuTable()['_myMusic'])
					jiveMain:getMenuTable()['_myMusic'].callback(nil, nil, true)
				else
					log:warn('_myMusic not found')
				end
			end
		})
		--]]

		-- Eject item
		local ejectToken = 'EJECT_CONFIRM_ITEM'
		if item.devType then
			ejectToken = 'EJECT_' .. item.devType
		end
		menu:addItem({
			text = self:string(ejectToken),
			iconStyle = 'hm_eject',
			sound = "WINDOWSHOW",		
			callback = function()
				self:_confirmEject(devName)
			end,
		})
	else
		menu:addItem({
			text = self:string("OK"),
			style = 'item',
			sound = "WINDOWSHOW",		
			callback = function()
				window:hide()
			end,
		})
	end

	menu:setHeaderWidget(Textarea("help_text", self:string("EJECT_WARNING_INFO")))

	window:addWidget(menu)
	self:tieAndShowWindow(window)

	-- restart the server
	if item.SCDrive then
		log:warn('!! Writing prefs.json file and starting scan')
		self:_writeSCPrefsFile(devName)
		self:restartServer()
	end

	return window
end

function _writeSCPrefsFile(self, devName)
	local item = self:_getItemFromDevName(devName)
	if not item then
		self:addMountedDevice(devName, true)
		item = self:_getItemFromDevName(devName)
	end
	if item.mountPath then
		local exportTable = {
			audiodir = item.mountPath, -- audiodir could be changed in the future to a user-configured subdir of the mounted drive
			mountpath = item.mountPath
		}
		local forExport = json.encode(exportTable)
		
		local fh = io.open(self.prefsFile, "w")

		if fh == nil then
			return false
		end

		fh:write(forExport)
		fh:close()
	end
end


function _scDrive(self)
	local prefsData = self:readSCPrefsFile()
	if prefsData.mountpath then
		return prefsData.mountpath
	else
		return false
	end
end


function readSCPrefsFile(self)
	local fh = io.open(self.prefsFile, "r")
	if fh == nil then
		return false
	end

	local jsonData = fh:read("*all")
	fh:close()

	local prefsData = json.decode(jsonData)
	return prefsData

end


-- Make running status about built in SC available as service
function isBuiltInSCRunning(self)
	return serverRunning(self)
end


function serverRunning(self)
	if squeezeos:pidfor("squeezecenter") then
		return true
	end
	return squeezeos:processRunning('slimserver.pl')
end


function scannerRunning(self)
	return squeezeos:processRunning('scanner.pl')
end


function _scanStatus(self)

	log:debug("_scanStatus()")
	local scanStatus = {}

	local file = "/etc/squeezecenter/scan.json"
	local fh = io.open(file, "r")

        if fh == nil then
		-- no scan file present
		return false
        end

	local jsonData = fh:read("*all")
	fh:close()

	scanStatus = json.decode(jsonData)
	return scanStatus
end


-- uses table decoded from scan.json and returns a formatted text block for informational display
function _parseScanData(self, scanData)

	local runningText   = self:string('RUNNING')
	local completedText = self:string('COMPLETE')
	local hasData       = false

	local progressReport = {}
	-- scanData is an array of scanner steps

	-- if every step has an eta of 0, the assumption is that the scan is complete
	local scanComplete = true
	for i, step in ipairs(scanData) do
		-- step.eta < 0 is when no eta is known but the step is running, as in discovering_files
		if step.eta ~= 0 then 
			log:debug('scan not done')
			scanComplete = false
		end
	end


	if scanComplete then
		log:debug('scan done')
		return self:string("STATUS_SQUEEZECENTER_RUNNING")
	end

	for i, step in ipairs(scanData) do
		-- without a step.name, don't report anything
		if step.name then
			hasData = true
			local token = string.upper(step.name) .. '_PROGRESS'
			local nameString = self:string(token)

			-- first line is the name of the step and the status of it (completed or running)
			if step.finish and type(step.finish) == 'number' and step.finish > 0 then
				local completed = tostring(nameString) .. ": " .. tostring(completedText)
				table.insert(progressReport, completed)
			else
			
				local eta = step.eta and tonumber(step.eta)
				if eta and eta > 0 then
					table.insert(progressReport, tostring(nameString))

					local timeLeftString = self:string('TIME_LEFT')
					local timeLeft = '        ' .. tostring(timeLeftString) .. ": " .. _secondsToString(eta)
					table.insert(progressReport, timeLeft)
				-- if eta is not > 0, then we must be running but with no final estimate
				else
					local running = tostring(nameString) .. ": " .. tostring(runningText)
					if step.done then
						running = running .. " (" .. tostring(step.done) .. ")"
					end
					table.insert(progressReport, running)
				end

				local percentCompleteTable = {}
				if step.done and step.total and tonumber(step.total) > 0 then
					local percentDoneString = self:string('PERCENT_DONE')
					local percentageDone = tostring(math.floor( 100 * tonumber(step.done)/tonumber(step.total)))
					local percentageString = percentageDone .. "%"
					local xofy = "(" .. tostring(step.done) .. '/' .. tostring(step.total) .. ")"

					local percentDone = '        ' .. tostring(percentDoneString) .. ": " .. percentageString .. ' ' .. xofy
					table.insert(progressReport, percentDone)
				end
			end
		end
	end

	if hasData then
		return table.concat(progressReport, "\n") 
	else
		-- no data (this should never happen, but is here as a failsafe)
		log:warn('Warning: no usable data in scan.json found')
		return self:string('SCANNER_NO_STATUS')
	end

end


function _secondsToString(seconds)
	local hrs = math.floor(seconds / 3600)
	local min = math.floor((seconds / 60) - (hrs*60))
	local sec = math.floor( seconds - (hrs*3600) - (min*60) )

	if hrs > 0 then
		return string.format("%d:%02d:%02d", hrs, min, sec)
	else
		return string.format("%d:%02d", min, sec)
	end
end

--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
