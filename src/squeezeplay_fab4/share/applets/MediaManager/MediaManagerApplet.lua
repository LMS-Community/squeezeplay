local ipairs, pairs, type, tostring, tonumber  = ipairs, pairs, type, tostring, tonumber

-- stuff we use
local table                  = require("jive.utils.table")
local string                 = require("jive.utils.string")
local debug                  = require("jive.utils.debug")

local oo                     = require("loop.simple")
local io                     = require("io")
local os                     = require("os")
local lfs                    = require("lfs")

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
	self.MOUNTING_DRIVE_TIMEOUT   = 60
	self.UNMOUNTING_DRIVE_TIMEOUT = 10
	self.WIPE_TIMEOUT             = 60
	self.supportedFormats         = {"FAT16","FAT32","NTFS","ext2","ext3"}
	self.mmOnEjectHandlers        = {}
	self.mmOnMountHandlers        = {}
	self.mmMenuItems              = {}
end


-- mmStartupCheck looks for mounted drives and adds menu items for these
-- each menu item should have a few items (like eject) added directly from this applet, 
-- but can also have items from other applets (SqueezeCenter, ImageViewer) inserted in them as needed via service methods
function mmStartupCheck(self)

	-- the startup check is re-initializing which drives are mounted, so whatever is pulled from settings in init() needs clearing here first
	-- addMountedDevice() in this method repopulates self.mountedDevices as needed
	self.mountedDevices = {}

	local mountedDrives       = self:mountedDriveCheck()

	for k, v in pairs(mountedDrives) do
		mountedDrivePresent = true
		break
	end

	-- mounted drive present
	if mountedDrivePresent then
		-- create menu items for each
		for k, v in pairs(mountedDrives) do
			-- check whether the mount point is ending in a partition number
			-- ignore disks without partition like eg. sdb (virtual CD drive)
			if string.match(k, "[123456789]$") then
				log:debug('STARTUP | Create main menu item for ', k)
				self:addMountedDevice(k, false)
			end
		end
	end

end


function addMountedDevice(self, devName)
	log:info('addMountedDevice: ', devName)
	self.mountedDevices[devName] = {
		devName    = devName,
		deviceName = "/dev/"   .. devName,
		mountPath  = "/media/" .. devName,
		devType    = self:mediaType(devName),
	}

	-- add menu item for this device
	log:info('addDeviceMenuItem(): ', devName)

	local iconStyle
	if self.mountedDevices[devName].devType == 'SD' then
		iconStyle = 'hm_sdcard'
	else
		iconStyle = 'hm_usbdrive'
	end

	-- add the menu item and store it in self.mountedDevices[devName]
	self.mountedDevices[devName].menuItem = 
		{
			id = 'mm_' .. devName,
			iconStyle = iconStyle,
			node = 'home',
			-- XXX: this should be more descriptive than just 'SD Card' or 'USB device'
			text = self:string(self.mountedDevices[devName].devType),
			sound = 'WINDOWSHOW',
			weight = 5,
			callback = function(event)
				self:showMediaManagerWindow(devName)
			end
		}
	jiveMain:addItem(self.mountedDevices[devName].menuItem)

	return true
end


-- create and display a window that shows the items in the menu for devName
function showMediaManagerWindow(self, devName)

	log:info('showMediaManagerWindow(): ', devName)
	local token = self:mediaType(devName)
	local window = Window('text_list', self:string(token))
	local menu = SimpleMenu("menu")

	-- go through mmMenuItems and add items to the menu
	for k, v in pairs(self.mmMenuItems) do
		log:info('adding menu item for ', k)

		local addThisItem = true
		if v.onlyIfTrue or v.onlyIfFalse then
			if v.onlyIfTrue and v.onlyIfFalse then
				log:info('needs to return true for onlyIfTrue and false for onlyIfFalse to add this menu item')
				addThisItem = appletManager:callService(v.onlyIfTrue, devName) and not appletManager:callService(v.onlyIfFalse, devName)
			elseif v.onlyIfTrue then
				log:info('onlyIfTrue method needs to return true to add this menu item')
				addThisItem = appletManager:callService(v.onlyIfTrue, devName)
			elseif v.onlyIfFalse then
				log:info('onlyIfFalse method needs to return false to add this menu item')
				addThisItem = not appletManager:callService(v.onlyIfFalse, devName)
			end
			log:info('---> addThisItem is now ', addThisItem)
		end

		if addThisItem then
			local callback = function() appletManager:callService(v.serviceMethod, devName, v.serviceMethodParams) end
			local text
			if v.menuToken then
				if v.devNameAsTokenArg then
					text = self:string(v.menuToken, self:mediaType(devName))
				else
					text = self:string(v.menuToken)
				end
			else
				text = v.menuText
			end

			menu:addItem({
				text     = text,
				style    = v.itemStyle or 'item',
				weight   = v.weight or 50,
				sound    = "WINDOWSHOW",		
				callback = callback,
			})
		end
	end
	menu:setComparator(SimpleMenu.itemComparatorWeightAlpha)

	window:addWidget(menu)
	self:tieAndShowWindow(window)
	return window
	
end


-- udevHandler takes events on udev and decides what action to take
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


function mmGetMountedDevices(self)
	log:info('mmGetMountedDevices()')
	if self.mountedDevices then
		return self.mountedDevices
	end
	log:warn('no mounted devices found, returning false')
	return false
end


function mediaType(self, devName)
	if string.match(devName, "^sd") then
		return 'USB'
	elseif string.match(devName, "^mmc") then
		return 'SD'
	end
	return false
end


-- mmRegisterMenuItem
-- service method for adding a menu item for media manager 
-- options is a table of arguments used to register a menu item for a media manager menu
-- some args are mandatory, some are optional. checks should be made here and errors thrown when things that are not expected are delivered
function mmRegisterMenuItem(self, options)

	if not options then
		log:error("mmRegisterMenuItem() called without an options table")
		return
	end

	-- checks for correct args to options table
	local mandatoryArgs = { 'serviceMethod' }
	local failedCheck = false
	for i, v in ipairs(mandatoryArgs) do
		if not options[v] then
			log:warn('options table did not include mandatory key of ', v)
			failedCheck = true
		end
	end
	if not options.menuText and not options.menuToken then
		log:warn('options table did not include either menuText or menuToken')
		failedCheck = true
	end

	-- if any of the checks fail, do not add the menu item
	if failedCheck then
		log:warn('Failed check for adding a media manager menu item')
		return false
	end

	-- if there's an options.key, use that. otherwise, use options.serviceMethod
	local key = options.key or options.serviceMethod
	log:info('key for this item is set to: ', key)
        self.mmMenuItems[key] = options

	return true
end


-- mmRegisterOnEjectHandler
-- service method for registering service methods to be called at the time of a device eject
-- by design, these methods are run before the device is unmounted
function mmRegisterOnEjectHandler(self, options)
	if not options.serviceMethod then
		log:error('mmRegisterOnEjectHandler() called without a service method')
		return false
	end

	local key = options.key or options.serviceMethod
	log:info('adding an onEject handler for ', key)
	self.mmOnEjectHandlers[key] = options

end


--mmRegisterOnMountHandler
-- service method for registering service methods to be called at the time of a device eject
-- by design, these methods are run before the device is unmounted
function mmRegisterOnMountHandler(self, options)
	if not options.serviceMethod then
		log:error('mmRegisterOnMountHandler() called without a service method')
		return false
	end

	local key = options.key or options.serviceMethod
	self.mmOnMountHandlers[key] = options

end


function getKey(self, ...)
	local key = table.concat({...}, ':')
	return key
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

        --make sure this popup remains on screen
	popup:setAllowScreensaver(false)
	popup:setAlwaysOnTop(true)
	popup:setAutoHide(false)
	popup:setTransparent(false)
	popup:ignoreAllInputExcept()

	self.popupMountWaiting = popup
	self:tieAndShowWindow(popup)
	return popup
end


-- _deviceRemoval
-- kicked off when udev listener detects a device removal
-- checks if device is still in mount table, 
-- if so push on the DON'T DO THAT window
---function _mountingDrive(self)
function _deviceRemoval(self, devName)

	-- If unmount success window is still up - automatically hide it and go home
	-- This saves the user from needing to click 'ok' manually
	if self.unmountSuccessWindow then
		self.unmountSuccessWindow:hide()
		self.unmountSuccessWindow = nil
		Framework:pushAction("go_home")
	end

	-- if devName is still in the self.mountedDevices table, consider this an unsafe eject
	if self.mountedDevices and self.mountedDevices[devName] then
		
		log:warn('!!! Drive ', self.mountedDevices[devName].deviceName, ' was unsafely ejected.')

		-- perform registered on eject methods first
		self:_runOnEjectHandlers(devName)

		local window = Window("text_list", self:string("DEVICE_REMOVAL_WARNING"))
		window:setAllowScreensaver(false)
		local menu = SimpleMenu("menu")
		menu:addItem({
			text = self:string("OK"),
			style = 'item',
			sound = "WINDOWSHOW",		
			callback = function ()
				if self.ejectWarningWindow then
					self.ejectWarningWindow:hide()
					self.ejectWarningWindow = nil
				end
				window:hide()
			end
		})

		local token = 'DEVICE_REMOVAL_WARNING_INFO'
		if self.mountedDevices[devName].devType then
			token = token .. '_' .. self.mountedDevices[devName].devType
		end
	
		menu:setHeaderWidget( Textarea("help_text", self:string(token) ) )
		window:addWidget(menu)

		--Bug 15793, remove eject item from menu after bad eject
		self:removeMountedDevice(devName)
		
		self:tieAndShowWindow(window)
		return window
	end

end


function _unmountActions(self, devName, silent, force)

	local item = self:_getItemFromDevName(devName)
	if force then
		os.execute("umount -l /media/" .. devName)
	else
		os.execute("umount /media/" .. devName)
	end

end


function _runOnEjectHandlers(self, devName)

	log:info('running registered on eject handlers')
	for k, v in pairs(self.mmOnEjectHandlers) do
		log:info('calling handler for ', k)
		appletManager:callService(v.serviceMethod, devName, v.serviceMethodParams)
	end
end


-- _unmountingDrive
-- full screen popup that appears until unmounting is complete or failed
function _unmountDrive(self, devName, force)
	
	log:info('_unmountDrive() ', devName)

	local item = self:_getItemFromDevName(devName)


	-- require that we have an item.devPath to eject
	if not item.mountPath then
		log:warn("no mountPath to eject item")
		return EVENT_UNUSED
	end

	-- run the service handlers first
	self:_runOnEjectHandlers(devName)

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

	-- Bug: 15741 - Media ejection SD and USB unreliable
	-- Make sure this popup remains on screen until drive
	-- is successfully ejected or a timeout occurs.
	popup:setAllowScreensaver(false)
	popup:setAlwaysOnTop(true)
	popup:setAutoHide(false)
	popup:setTransparent(false)
	popup:ignoreAllInputExcept()

	self.popupUnmountWaiting = popup
	self:tieAndShowWindow(popup)
	return popup
end


function _mountingDriveTimer(self, devName)
	local mounted = false

	Task("mountingDrive", self, function()
		log:debug("mountingDriveTimeout=", self.mountingDriveTimeout)

		mounted = self:_checkDriveMounted(devName)

		if mounted then
			-- success
			log:debug("*** Device mounted sucessfully.")

			self:addMountedDevice(devName)

			self:_ejectWarning(devName)
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

		unmounted = not self:_checkDriveMounted(devName)

		if unmounted then
			-- success
			log:warn("*** Device ", devName, " unmounted sucessfully.")

			-- rmdir cleanup of /media/devName, as stale dirs appear to be a problem after umount
			if self:_mediaDirExists(devName) then
				lfs.rmdir("/media/" .. devName)
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
		self:removeMountedDevice(devName)
	end


	local window = Window("text_list", self:string("DEVICE_EJECTED"))

	-- Keep a reference so we can hide window when user removed SD card
	self.unmountSuccessWindow = window

	window:setAllowScreensaver(false)
	window:setButtonAction("rbutton", nil)
	window:setButtonAction("lbutton", nil)

	local menu = SimpleMenu("menu")

	menu:addItem({
		text = self:string("OK"),
		style = 'item',
		sound = "WINDOWSHOW",		
		callback = function ()
			Framework:pushAction("go_home")
			if self.ejectWarningWindow then
				self.ejectWarningWindow:hide()
				self.ejectWarningWindow = nil
			end
			window:hide()

			-- User clicked ok before removing SD card - no need to keep the reference
			self.unmountSuccessWindow = nil		
		end
	})

	menu:setHeaderWidget( Textarea("help_text", self:string(token) ) )

	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


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


function removeMountedDevice(self, devName)
	log:debug('removeMountedDevice()')
	if self.mountedDevices and self.mountedDevices[devName] and self.mountedDevices[devName].menuItem then
		log:debug('removing menu item for ', devName)
		jiveMain:removeItem(self.mountedDevices[devName].menuItem)
	else
		-- bug 15739: since self.mountedDevices can be freed from memory, try to remove the item by the home menu id, which is devName
		log:warn('attempt to remove item by id: ', devName)
		local id = 'mm_' .. devName
		jiveMain:removeItemById(id)
	end

	if self.mountedDevices and self.mountedDevices[devName] then
		self.mountedDevices[devName] = nil
	end
end


function mmConfirmEject(self, devName)
	log:info('mmConfirmEject(): ', devName)

	local item = self:_getItemFromDevName(devName)

	local titleToken   = 'EJECT_CONFIRM'
	local confirmToken = 'EJECT_CONFIRM_INFO'
	local ejectToken   = 'EJECT_REMOVABLE_MEDIA'

	if item and item.devType then
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
				text = self:string(ejectToken, item and item.devName),
				sound = "WINDOWSHOW",
				callback = function() 
					-- eject drive
					self:_unmountDrive(devName)
				end
			},
	})

	local headerTextStrings = {
		tostring(self:string(confirmToken, devName))
	}
	local extraHeaderText = _getExtraHeaderText(self, devName)
	for k, v in pairs(extraHeaderText) do
		table.insert(headerTextStrings, v)
	end
	local headerText = table.concat(headerTextStrings, "\n")
	menu:setHeaderWidget( Textarea("help_text", headerText ) )
	
	window:addWidget(menu)
	self.confirmEjectWindow = window
	self:tieAndShowWindow(window)
	return window
end


function _getExtraHeaderText(self, devName)
	log:info('compiling ejectWarningText table')
	local returnTable = {}
	for k, v in pairs(self.mmOnEjectHandlers) do
		local insertIt = true
		if v.ejectWarningText then
			if v.ejectWarningTextOnlyIfTrue and v.ejectWarningTextOnlyIfFalse then
				log:info('needs to return true for ejectWarningTextOnlyIfTrue and false for ejectWarningTextOnlyIfFalse to add this warning text')
				insertIt = appletManager:callService(v.ejectWarningTextOnlyIfTrue, devName) 
						and not appletManager:callService(v.ejectWarningTextOnlyIfFalse, devName)

			elseif v.ejectWarningTextOnlyIfTrue then
				log:info('ejectWarningTextOnlyIfTrue method needs to return true to add this warning text')
				insertIt = appletManager:callService(v.ejectWarningTextOnlyIfTrue, devName)

			elseif v.ejectWarningTextOnlyIfFalse then
				log:info('ejectTextOnlyIfFalse method needs to return false to add this menu item')
				insertIt = not appletManager:callService(v.ejectTextOnlyIfFalse, devName)

			else
				log:info('no conditional on this eject warning text, so add it: ', v.ejectWarningText)
			end

			if insertIt then
				log:info('---> add warning text ', v.ejectWarningText)
				table.insert(returnTable, tostring(v.ejectWarningText))

			else
				log:info('---> insertIt says false, so do not add ', v.ejectWarningText)

			end

		end

	end
	return returnTable

end


function _getItemFromDevName(self, devName)
	return self.mountedDevices and 
		self.mountedDevices[devName]
end


-- returns table of devNames for mounted devices
function mountedDriveCheck(self)
	local mountedDrives = {}

	local mounts = io.open("/proc/mounts", "r")
	
	if mounts == nil then
		log:error("/proc/mounts could not be opened")
		return mountedDrives
	end

	for line in mounts:lines() do
		local mountPoint = string.match(line, "/media/(%w*)")
		if mountPoint then
			log:debug('Mounted drive found at /media/', mountPoint)
			mountedDrives[mountPoint] = "/media/" .. mountPoint
		end
	end
	mounts:close()

	return mountedDrives
end


-- will return true if /media/<devName> is listed in the output of the mount command
function _checkDriveMounted(self, devName)
	local mountedDrives = self:mountedDriveCheck()
	
	if mountedDrives[devName] then
		return true
	end
	
	return false
end


function isReadOnlyMedia(self, devName)
	local mounts = io.open("/proc/mounts", "r")
	local isReadOnly = false
	
	if mounts == nil then
		log:error("/proc/mounts could not be opened")
		return nil
	end

	for line in mounts:lines() do
		if string.match(line, "/media/" .. devName) then
			if string.match(line, "[^%d%a]ro[^%d%a]") then
				log:debug('/media/', devName, ' is read-only')
				isReadOnly = true
				break
			else
				log:debug('/media/', devName, ' is NOT read-only')
				break
			end
		end
	end
	mounts:close()

	return isReadOnly
end

function isWriteableMedia(self, ...)
	return not self:isReadOnlyMedia(...)
end


function _mediaDirExists(self, devName)
	local dirExists = nil
	
	for file in lfs.dir("/media") do
		local dummy = string.match(file, devName)
		if dummy then
			log:info("media dir found: ", dummy)
			return true
		end
	end

	return false
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
		callback = function()
			-- push on media manager window for this device and hide this window
			self:showMediaManagerWindow(devName)
			window:hide()
		end,
	})

	menu:setHeaderWidget(Textarea("help_text", self:string("EJECT_WARNING_INFO")))

	window:addWidget(menu)
	self.ejectWarningWindow = window
	self:tieAndShowWindow(window)

	return window
end

function free(self)
	return false
end

--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
