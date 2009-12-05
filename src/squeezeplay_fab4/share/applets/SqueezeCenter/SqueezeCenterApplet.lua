local load, ipairs, pairs, type, tostring, tonumber  = load, ipairs, pairs, type, tostring, tonumber

-- stuff we use
local math             = require("math")
local json             = require("json")
local table            = require("jive.utils.table")
local string           = require("jive.utils.string")
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
	self.mountedDevices = {}
	self.MOUNTING_DRIVE_TIMEOUT = 30
	self.UNMOUNTING_DRIVE_TIMEOUT = 30
	self.supportedFormats = {"FAT16","FAT32","NTFS","ext2","ext3"}
	self.prefsFile = "/etc/squeezecenter/prefs.json"
end


-- do the right thing on jive startup
function squeezecenterStartupCheck(self)

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

		log:debug('STARTUP (6)| Start Scanner')
		--- start scanner 
		self:startScan()

		-- populate non-SC mounted drives to self.mountedDevices
		-- create menu items for each
		for k, v in pairs(mountedDrives) do
			if not self.mountedDevices[k] then
				self:addMountedDevice(k, false)
			end
			log:debug('STARTUP (7)| Create eject item for ', k)
			self:_addEjectDeviceItem(k)
		end
	end

end


function _firstTableElement(self, t)
	for k, v in pairs(t) do
		return k, v 
	end
end


function addMountedDevice(self, devName, isSCDrive)
	self.mountedDevices[devName] = {
		devName    = devName,
		deviceName = "/dev/"   .. devName,
		mountPath  = "/media/" .. devName,
		devType    = self:mediaType(devName),
		SCDrive    = isSCDrive,
	}
	return true
end

function settingsShow(self)
	-- Squeezebox Server is Squeezebox Server in all langs, so no need to translate title text
	local window = Window("text_list", 'Squeezebox Server')
	
	-- XXX: first attempt at showing scan process running
	self.status = Textarea("help_text", self:_getStatusText() )

	local menu = SimpleMenu("menu", {
					{
						text = self:string("START"),
						sound = "WINDOWSHOW",
						callback = function()
								   self:_squeezecenterAction("icon_connecting", "STARTING_SQUEEZECENTER", "STARTING_SQUEEZECENTER_TEXT", 5000, "start")
							   end
					},
					{
						text = self:string("STOP"),
						sound = "WINDOWSHOW",
						callback = function()
								   self:_squeezecenterAction("icon_connecting", "STOPPING_SQUEEZECENTER", nil, 2000, "stop")
							   end
					},
					{
						text = self:string("STOP_RESCAN_START"),
						sound = "WINDOWSHOW",
						callback = function()
								   self:startScan()
							   end
					},
				})

	menu:setHeaderWidget(self.status)
	window:addWidget(menu)
	self:tieAndShowWindow(window)
	
	window:addTimer(5000, function() _updateStatus(self) end)
	
	return window
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

	os.execute("/etc/init.d/squeezecenter " .. action);

end


function _getStatusText(self)
	-- XXX: first attempt at showing scan process running
	local statusText
	if self:scannerRunning() then
		self.scannerStatus = self:_scanStatus()
		statusText = self:_scanProgressText()
		log:debug(statusText)
	else
		statusText = self:string( self:_getStatus() )
	end
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
			-- TODO: if we hit this spot, this is where we check if the device was properly unmounted
			log:warn('Device Removal Detected: ', devName)
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
end

function _unmountActions(self, devName, silent)

	local item = self:_getItemFromDevName(devName)
	if item.SCDrive then
		self:_stopScanner(silent)
		self:_stopServer(silent)
	else
		log:warn('!! This is not the SCDrive')
	end
	os.execute("umount /media/" .. devName)

end

function _stopScanner(self, silent)
	if self:scannerRunning() then
		-- attempt to stop scanner
		log:debug('STOPPING SCANNER')
		self:_squeezecenterAction("icon_connecting", "STOPPING_SCANNER", nil, 2000, "stopscan", silent)
	end
end


function _stopServer(self, silent)
	if self:serverRunning() then
		-- attempt to stop SC
		log:debug('STOP SERVER')
		self:_squeezecenterAction("icon_connecting", "STOPPING_SQUEEZECENTER", nil, 2000, "stop", silent)
	end

end

-- _unmountingDrive
-- full screen popup that appears until unmounting is complete or failed
function _unmountDrive(self, devName)
	
	log:warn('_unmountDrive()')

	local item = self:_getItemFromDevName(devName)


	-- require that we have an item.devPath to eject
	if not item.mountPath then
		log:warn("no mountPath to eject item")
		return EVENT_UNUSED
	end

	self:_unmountActions(devName)

	if self.popupUnmountWaiting then
		return
	end

        local popup = Popup("waiting_popup")
        local icon  = Icon("icon_connecting")

	-- set self.devType var based on devName during the _mountingDrive method
	self.devType = self:mediaType(devName)
	self.mountingDriveTimeout = 0

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
			debug.dump(self.mountedDevices)

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
	self.unmountingDriveTimeout = 0

	Task("unmountingDrive", self, function()
		log:debug("unmountingDriveTimeout=", self.mountingDriveTimeout)

		unmounted = self:_checkDriveUnmounted(devName)

		if unmounted then
			-- success
			log:debug("*** Device ", devName, " unmounted sucessfully.")

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

	-- XXX: This is a currently necessary hack. 
	-- If the scanner is running when the unmount occurs, stopscan will trigger the server to start, 
	-- because the /etc/init.d/squeezecenter script will go to the next interpreted line after the scanner stops, which is to start the server.
	-- Sometimes when this occurs the server does not start until _after_ the server stop command is issued by this applet and the drive is unmounted, which causes BAD THINGS. 
	-- Add a one time 3 second timer to stop the server one more time and forcefully remove the /media/<devName> folder. 
	-- Ouch.
	window:addTimer(
		3000, 
		function()
			log:warn('making sure server is killed and /media/' .. devName .. ' is deleted from filesystem')
			self:_stopServer(true)
			if self:_mediaDirExists(devName) then 
				log:warn('forcefully remove /media/', devName)
				-- we need an rm -rf here because a .Squeezebox dir may have been created, but let's be careful with the rm -rf shall we?
				-- make sure devName is there, otherwise this command is rm -rf /media
				if devName and devName ~= '' then
					os.execute("rm -rf /media/" .. devName)
				end
			end
		end,
		true
	)

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

function _unmountFailure(self, devName)
	log:warn('_unmountFailure()')
end

function _removeEjectDeviceItem(self, devName)
	log:debug('_removeEjectDeviceItem()')
	local item = self:_getItemFromDevName(devName)
	if item and item.menuItem then
		log:debug('removing menu item for ', item.devType)
		jiveMain:removeItem(item.menuItem)
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

	self.mountedDevices[devName].menuItem = {
                id = item.devName,
                node = "_myMusic",
                text = self:string(token),
                iconStyle = 'hm_eject',
                weight = 1,
                --weight = 1000,
		-- TODO: add a method to eject the device (that works!)
		callback = function()
			self:_confirmEject(devName)
		end,
        }
	jiveMain:addItem(self.mountedDevices[devName].menuItem)
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
end


function _getItemFromDevName(self, devName)
	return self.mountedDevices and 
		self.mountedDevices[devName]
end


function startScan(self)

	if not self:scannerRunning() then
		log:warn('Starting scanner')
		self:_squeezecenterAction("icon_connected", "RESCAN_SQUEEZECENTER", "RESCAN_SQUEEZECENTER_TEXT", 5000, "rescan")
	end
end


-- returns table of devNames for mounted devices
function mountedDriveCheck(self)
        local mount = io.popen("/bin/mount")

	local mountedDrives = {}

	local foundOne = nil
        for line in mount:lines() do
                local stringMatch = string.match(line, "/media/(%w*)")
		if stringMatch then
			log:warn('Mounted drive found at /media/', stringMatch)
			mountedDrives[stringMatch] = "/media/" .. stringMatch
		end
        end
        mount:close()

        return mountedDrives
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

	menu:addItem({
		text = self:string("OK"),
		style = 'item',
		sound = "WINDOWSHOW",		
		callback = function ()
			self:settingsShow()
			window:hide()
		end
	})

	menu:setHeaderWidget(Textarea("help_text", self:string("EJECT_WARNING_INFO")))

	window:addWidget(menu)
	self:tieAndShowWindow(window)

	-- start the scanner
	if item.SCDrive then
		self:_writeSCPrefsFile(devName)
		self:startScan()
	else
		log:warn('!! This is not the SCDrive')
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


function serverRunning(self)
	local sc = _pidfor('slimserver.pl')
	if (sc ~= nil) then
		return true
	end
	return false
end


function scannerRunning(self)
	local scanner = _pidfor('scanner.pl')
	if (scanner ~= nil) then
		return true
	end
	return false
end


function processRunning(self, process)
	local pid = _pidfor(process)
	if (pid ~= nil) then
		return true
	end
	return false
end


function _getStatus(self)
	if self:serverRunning() then
		return "STATUS_SQUEEZECENTER_RUNNING"
	elseif self:scannerRunning() then
		return "STATUS_SCANNER_RUNNING"
	else
		return "STATUS_NOTHING"
	end
end


function _pidfor(process)
	local pid

	local pattern = "%s*(%d+).*" .. process

	log:debug("pattern is ", pattern)

	local cmd = io.popen("/bin/ps -o pid,command")
	for line in cmd:lines() do
		pid = string.match(line, pattern)
		if pid then break end
	end
	cmd:close()

	return pid
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


-- uses self.scannerStatus table and returns a formatted text block for informational display
function _scanProgressText(self)

	local runningText   = self:string('RUNNING')
	local completedText = self:string('COMPLETE')
	local hasData       = false

	if self.scannerStatus then
		local progressReport = {}
		-- self.scannerStatus is an array of scanner steps
		for i, step in ipairs(self.scannerStatus) do
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
					local running = tostring(nameString) .. ": " .. tostring(runningText)
					table.insert(progressReport, running)
				end
				
				--- second line is detailed info on the step
				local secondLineTable = {}
				if step.done and step.total then
					local percentageDone = tostring(math.floor( 100 * tonumber(step.done)/tonumber(step.total)))
					local percentageString = tostring(completedText) .. ": " .. percentageDone .. "%"
					local xofy = "(" .. tostring(step.done) .. '/' .. tostring(step.total) .. ")"

					log:debug(percentageString)
					log:debug(xofy)

					table.insert(secondLineTable, percentageString)
					table.insert(secondLineTable, xofy)
				end
				-- XXX: do something with time here

				-- put the secondLineTable together as one string
				local secondLine = table.concat(secondLineTable, ' ')
				-- add the second line to the report
				table.insert(progressReport, secondLine)
			end
		end
		if hasData then
			return table.concat(progressReport, "\n") 
		else
			-- no data
			return self:string('SCANNER_NO_STATUS')
		end
	else
		-- no data
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

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
