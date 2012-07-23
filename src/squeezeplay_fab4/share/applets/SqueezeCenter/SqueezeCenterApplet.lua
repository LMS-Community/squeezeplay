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
local SlimServer             = require("jive.slim.SlimServer")

local appletManager          = appletManager
local jiveMain               = jiveMain


module(..., Framework.constants)
oo.class(_M, Applet)

function init(self)
	self.WIPE_TIMEOUT = 60
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
			self:_writeSCPrefsFile(scDrive)
		end

		log:debug('STARTUP (6)| Restart Server')
		self:restartServer(true)

	else
		-- nothing right now
	end

end


function _firstTableElement(self, t)
	for k, v in pairs(t) do
		return k, v 
	end
end


function mmSqueezeCenterMenu(self, devName)

	log:info('mmSqueezeCenterMenu: ', devName)
	-- we decide which menu to present based on whether this drive is the SC drive and whether SBS is running

	-- server is running
	if self:serverRunning() then
		-- and pointed to this devName
		if self:_scDrive() == devName then
			log:info('SBS running and pointed to this device')
			-- deliver status menu
			self:settingsShow()
		-- but not pointed to this devName
		else
			log:info('SBS running but not pointed to this device: ')
			self:switchServerToDifferentMedia(devName)
		end
	else
		-- present option to start it
		log:info('SBS not running')
		self:settingsShow()

	end
end


function switchServerToDifferentMedia(self, devName)

	self.devName = devName

	-- Squeezebox Server is Squeezebox Server in all langs, so no need to translate title text
	local window = Window("text_list", 'Squeezebox Server')
	
	window:setAllowScreensaver(false)
	local menu = SimpleMenu("menu")

	menu:setHeaderWidget( Textarea("help_text", self:string('SWITCH_MEDIA_HELP')))

	menu:addItem({
		text = self:string( 'SWITCH_MEDIA', self:mediaType(devName) ),
		sound = "WINDOWSHOW",
		callback = function()
			self:_writeSCPrefsFile(self.devName)
			
--[[ we should be able to just change the audiodir pref - don't know why it doesn't work...
			local server = SlimServer:getCurrentServer()
			server:request(function(chunk, err)
				debug.dump(chunk.data)
				log:debug(err)
			end, nil, {'pref', 'audiodir', '/media/' .. devName})
			window:hide()
--]]
			self:restartServer()
		end,
	})
	menu:addItem({
		text = self:string("CANCEL"),
		sound = "WINDOWHIDE",
		callback = function() 
			window:hide()
		end
	})

	window:addWidget(menu)
	
	self:tieAndShowWindow(window)
	return window
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
		
		if (subtext ~= nil) then 
			popup:addWidget(Textarea("subtext", self:string(subtext))) 
		end
		
		-- don't hide starting SC popup until scan.json file is detected
		if action == 'start' or action == 'restart' then

			local count = 0
			popup:addTimer(1000,
		                function()
					count = count + 1
					local scanData = self:_scanStatus()
		                        if count > 5 and ( scanData or count == 60) then
						popup:hide()
						Framework:pushAction("go_home")
					end
				end
			)
			popup:show()
                else
			popup:showBriefly(time,
				function()
					_updateStatus(self)
				end,
				Window.transitionPushPopupUp,
				Window.transitionPushPopupDown
			)
		end
	end

	if action == 'stop' then

		-- Guardian timer is in Fab4 applet to be resident
		appletManager:callService("SCGuardianTimer", action)

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

		-- Guardian timer is in Fab4 applet to be resident
		appletManager:callService("SCGuardianTimer", action)
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


function mmStopSqueezeCenter(self, devName)

	if devName == self:_scDrive() then
		log:warn('stopping server pointed to ', devName)
		self:_stopServer()

	else
		log:warn('devName ', devName, ' does not equal ', self.SCDrive)
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


function startSqueezeCenter(self)
	self:_startServerWindow()
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
	local command = "rm -rf /media/" .. scDrive .. "/.Squeezebox &"

	log:debug('remove .Squeezebox dir: ', command)
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
	local mountedDevices = appletManager:callService("mmGetMountedDevices")
	for k, v in pairs(mountedDevices) do
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
		for devName, item in pairs(mountedDevices) do
			log:warn('writing ', devName, ' to SC prefs file')
			self:_writeSCPrefsFile(devName)
			break --table is 1 element long, but breaking here can't hurt
		end
		-- XXX re-enable subtext after bug 16157 is fixed
		--self:_squeezecenterAction("icon_connecting", "STARTING_SQUEEZECENTER", "STARTING_SQUEEZECENTER_TEXT", 5000, "start")
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

		for devName, item in pairs(mountedDevices) do
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
					-- XXX re-enable subtext after bug 16157 is fixed
					--self:_squeezecenterAction("icon_connecting", "STARTING_SQUEEZECENTER", "STARTING_SQUEEZECENTER_TEXT", 5000, "start")
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


function _getItemFromDevName(self, devName)
	local mountedDevices = appletManager:callService("mmGetMountedDevices")
	return mountedDevices and 
		mountedDevices[devName]
end


function restartServer(self, silent)
	log:warn('Restarting squeezebox server')
	self:_squeezecenterAction("icon_connecting", "RESTARTING_SQUEEZECENTER", "PLEASE_WAIT", 5000, "restart", silent)

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


-- will return true if .Squeezebox is listed in the output of the ls command for scDrive
function squeezeboxDirPresent(self, scDrive)
	local present = false
	
	local scDriveLocation = "/media/" .. scDrive
	for f in lfs.dir(scDriveLocation) do
		present = string.match(f, "^\.Squeezebox")
		if present then
			log:info("squeezeboxDirPresent(), found it: ", present)
			break
		end
	end

	log:info(scDrive, "/.Squeezebox present: ", present)

	if present then
		return true
	end

	return false
end


-- will return true if /media/<devName> is listed in the output of the mount command
function checkDriveMounted(self, devName)
	local mountedDrives = self:mountedDriveCheck()
	
	if mountedDrives[devName] then
		return true
	end
	
	return false
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



--[[
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
--]]

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


--[[
	-- restart the server
	if item.SCDrive then
		log:warn('!! Writing prefs.json file and starting scan')
		self:_writeSCPrefsFile(devName)
		self:restartServer()
	end
--]]

function _writeSCPrefsFile(self, devName)

	if not devName then
		log:error('_writeSCPrefsFile requires devName ', devName)
		return
	end

	local exportTable = {
		audiodir = "/media/" .. devName, -- audiodir could be changed in the future to a user-configured subdir of the mounted drive
		mountpath = "/media/" .. devName,
		devName   = devName 
	}
	local forExport = json.encode(exportTable)
	
	local fh = io.open(self.prefsFile, "w")

	if fh == nil then
		return false
	end

	fh:write(forExport)
	fh:close()
end


function _scDrive(self)
	local prefsData = self:readSCPrefsFile()
	if prefsData and prefsData.devName then
		return prefsData.devName
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
