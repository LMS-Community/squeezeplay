

-----------------------------------------------------------------------------
-- Convention: functions/methods starting with t_ are executed in the thread
-----------------------------------------------------------------------------



-- stuff we use
local assert, getmetatable, ipairs, pairs, pcall, setmetatable, tonumber, tostring, type = assert, getmetatable, ipairs, pairs, pcall, setmetatable, tonumber, tostring, type

local oo                     = require("loop.simple")

local io                     = require("io")
local os                     = require("os")
local string                 = require("string")
local table                  = require("jive.utils.table")
local debug                  = require("jive.utils.debug")

local Applet                 = require("jive.Applet")
local Framework              = require("jive.ui.Framework")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local Button                 = require("jive.ui.Button")
local Group                  = require("jive.ui.Group")
local Keyboard               = require("jive.ui.Keyboard")
local Tile                   = require("jive.ui.Tile")
local RadioButton            = require("jive.ui.RadioButton")
local RadioGroup             = require("jive.ui.RadioGroup")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Surface                = require("jive.ui.Surface")
local Task                   = require("jive.ui.Task")
local Textarea               = require("jive.ui.Textarea")
local Textinput              = require("jive.ui.Textinput")
local Window                 = require("jive.ui.Window")
local Popup                  = require("jive.ui.Popup")

local Networking             = require("jive.net.Networking")

local log                    = require("jive.utils.log").logger("applets.setup")

local jnt                    = jnt

local LAYER_FRAME            = jive.ui.LAYER_FRAME
local LAYER_CONTENT_ON_STAGE = jive.ui.LAYER_CONTENT_ON_STAGE

local LAYOUT_NORTH           = jive.ui.LAYOUT_NORTH
local LAYOUT_EAST            = jive.ui.LAYOUT_EAST
local LAYOUT_SOUTH           = jive.ui.LAYOUT_SOUTH
local LAYOUT_WEST            = jive.ui.LAYOUT_WEST
local LAYOUT_CENTER          = jive.ui.LAYOUT_CENTER
local LAYOUT_NONE            = jive.ui.LAYOUT_NONE


-- configuration
local CONNECT_TIMEOUT = 30
local wirelessTitleStyle = 'setuptitle'

-- 01/27/09 - fm - WPS - begin
local WPS_WALK_TIMEOUT = 120		-- WPS walk timeout
-- 01/27/09 - fm - WPS - end


module(..., Framework.constants)
oo.class(_M, Applet)


function init(self)
	self.wlanIface = Networking:wirelessInterface(jnt)
	self.ethIface = Networking:wiredInterface(jnt)

	self.scanResults = {}
end


function setupRegionShow(self, setupNext, wlan)
	local window = Window("button", self:string("NETWORK_REGION"), wirelessTitleStyle)
	window:setAllowScreensaver(false)

	local region = wlan:getRegion()

	local menu = SimpleMenu("menu")

	for name in wlan:getRegionNames() do
		log:debug("region=", region, " name=", name)

		local item = {
			text = self:string("NETWORK_REGION_" .. name),
			style = 'buttonitem',
			sound = "WINDOWSHOW",
			callback = function()
					if region ~= name then
						wlan:setRegion(name)
					end
					self:getSettings()['region'] = name
                       			self:storeSettings()
					setupNext(wlan)
				   end
		}

		menu:addItem(item)
		if region == name then
			menu:setSelectedItem(item)
		end
	end


	local helpButton = Button( Label( 'helpTouchButton', self:string("NETWORK_CONNECTION_HELP")), function() self:helpWindow('NETWORK_REGION', 'NETWORK_REGION_HELP') end )
	window:addWidget(helpButton)
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function settingsRegionShow(self)
	local wlan = self.wlanIface

	local window = Window("window", self:string("NETWORK_REGION"), wirelessTitleStyle)
	window:setAllowScreensaver(false)

	local region = wlan:getRegion()

	local menu = SimpleMenu("menu")
	menu:setComparator(SimpleMenu.itemComparatorAlpha)

	local group = RadioGroup()
	for name in wlan:getRegionNames() do
		log:debug("region=", region, " name=", name)
		menu:addItem({
				     text = self:string("NETWORK_REGION_" .. name),
				     icon = RadioButton("radio", group,
							function() 
								self:getSettings()['region'] = name
		                        			self:storeSettings()
								wlan:setRegion(name) 
							end,
							region == name
						)
			     })
	end

	window:addWidget(Textarea("help", self:string("NETWORK_REGION_HELP")))
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function setupConnectionHelp(self)
	local window = Window("window", self:string("NETWORK_CONNECTION_HELP"), 'setuptitle')
	window:setAllowScreensaver(false)

	local textarea = Textarea("textarea", self:string("NETWORK_CONNECTION_HELP_BODY"))
	window:addWidget(textarea)
	self:tieAndShowWindow(window)

	return window
end


function setupConnectionType(self, setupNext)
	log:debug('setupConnectionType')

	assert(self.wlanIface or self.ethIface)

	-- short cut if only one interface is available
	if not self.wlanIface then
		setupNext(self.ethIface)
	elseif not self.ethIface then
		setupNext(self.wlanIface)
	end

	-- ask the user to choose
	local window = Window("button", self:string("NETWORK_CONNECTION_TYPE"), wirelessTitleStyle)
	window:setAllowScreensaver(false)

	local connectionMenu = SimpleMenu("menu")

	connectionMenu:addItem({
		style = 'buttonitem',
		text = (self:string("NETWORK_CONNECTION_TYPE_WIRELESS")),
		sound = "WINDOWSHOW",
		callback = function()
			setupNext(self.wlanIface)
		end,
		weight = 1
	})
	
	connectionMenu:addItem({
		style = 'buttonitem',
		text = (self:string("NETWORK_CONNECTION_TYPE_WIRED")),
		sound = "WINDOWSHOW",
		callback = function()
			setupNext(self.ethIface)
		end,
		weight = 2
	})
	
	local helpButton = Button( Label( 'helpTouchButton', self:string("NETWORK_CONNECTION_HELP")), function() self:setupConnectionHelp() end )

	window:addWidget(helpButton)
	window:addWidget(connectionMenu)

	self:tieAndShowWindow(window)
	return window
end

function settingsConnectionType(self)
	log:debug('setupConnectionType')

	self.setupNext = nil

	assert(self.wlanIface or self.ethIface)

	-- short cut if only one interface is available
	if not self.wlanIface then
		self:setupScanShow(self.ethIface, self:settingsNetworksShow(self.ethIface) )
	elseif not self.ethIface then
		self:setupRegionShow(function() self:settingsNetworksShow() end, self.wlanIface)
	end

	-- ask the user to choose
	local window = Window("button", self:string("NETWORK_CONNECTION_TYPE"), wirelessTitleStyle)
	window:setAllowScreensaver(false)

	local connectionMenu = SimpleMenu("menu")

	connectionMenu:addItem({
		style = 'buttonitem',
		text = (self:string("NETWORK_CONNECTION_TYPE_WIRELESS")),
		sound = "WINDOWSHOW",
		callback = function() 
				self:setupScanShow( 
					self.wlanIface, 
					function() 
						self:settingsNetworksShow(self.wlanIface) 
					end 
				) 
			end,
		weight = 1
	})
	
	connectionMenu:addItem({
		style = 'buttonitem',
		text = (self:string("NETWORK_CONNECTION_TYPE_WIRED")),
		sound = "WINDOWSHOW",
		callback = function() 
				self.setupNext = self:openNetwork(self.ethIface, self.ethIface:getName())
				self:setupScanShow( 
					self.ethIface, 
					function() 
						self:settingsNetworksShow(
							self.ethIface, 
							self.setupNext 
						) 
					end 
				) 
			end,
		weight = 2
	})
	
	local helpButton = Button( Label( 'helpTouchButton', self:string("NETWORK_CONNECTION_HELP")), function() self:setupConnectionHelp() end )

	window:addWidget(helpButton)
	window:addWidget(connectionMenu)

	self:tieAndShowWindow(window)
	return window
end


function _setCurrentSSID(self, ssid)
	if self.currentSSID == ssid then
		return
	end

	if self.currentSSID and self.scanResults[self.currentSSID] then
		local item = self.scanResults[self.currentSSID].item
		item.style = nil
		if self.scanMenu then
			self.scanMenu:updatedItem(item)
		end
	end

	self.currentSSID = ssid

	if self.currentSSID and self.scanResults[self.currentSSID] then
		local item = self.scanResults[self.currentSSID].item
		item.style = "checked"
		if self.scanMenu then
			self.scanMenu:updatedItem(item)
		end
	end
end


function _addNetwork(self, iface, ssid)
	local item = {
		text = iface:isWireless() and ssid or tostring(self:string("NETWORK_ETHERNET")),
		icon = Icon("icon"),
		sound = "WINDOWSHOW",
		callback = function()
			openNetwork(self, iface, ssid)
		end,
		weight = iface:isWireless() and 1 or 2
	}
		      
	self.scanResults[ssid] = {
		item = item,            -- menu item
		iface = iface,		-- interface
		-- flags = nil,         -- beacon flags
		-- bssid = nil,         -- bssid if know from scan
		-- id = nil             -- wpa_ctrl id if configured
	}

	if self.scanMenu then
		self.scanMenu:addItem(item)
	end
end


-- Scan on interface iface
function setupScanShow(self, iface, setupNext)
	local interfaces
	if iface == nil then
		interfaces = Networking:interfaces(jnt)
	else
		interfaces = { dummy = iface }
	end

	-- start scanning
	local ifaceCount = 0
	for name, iface in pairs(interfaces) do
		ifaceCount = ifaceCount + 1

		iface:scan(function()
			ifaceCount = ifaceCount - 1
			if ifaceCount == 0 then
				setupNext()
			end
		end)
	end

	local window = Popup("popupIcon")
	window:setAllowScreensaver(false)

        window:addWidget(Icon("iconConnecting"))
        window:addWidget(Label("text", self:string("NETWORK_FINDING_NETWORKS")))

	local status = Label("text2", self:string("NETWORK_FOUND_NETWORKS", 0))
	window:addWidget(status)

        window:addTimer(1000, function()
			local numNetworks = 0

			for name, iface in pairs(interfaces) do
				local results = iface:scanResults()
				for k, v in pairs(results) do
					numNetworks = numNetworks + 1
				end
			end

			status:setValue(self:string("NETWORK_FOUND_NETWORKS", tostring(numNetworks) ) )
		end)

	-- or timeout after 10 seconds if no networks are found
	window:addTimer(10000,
		function()
			ifaceCount = 0
			setupNext()
		end)

	self:tieAndShowWindow(window)
	return window
end


function setupNetworksShow(self, iface, setupNext)
	self.setupNext = setupNext

	if not iface:isWireless() then
		self.scanResults = {}
		self:_scanComplete(iface)

		return self:createAndConnect(iface, iface:getName() )
	end

	local window = self:_networksShow(
		iface,
		self:string("NETWORK_WIRELESS_NETWORKS"),
		self:string("NETWORK_SETUP_HELP")
	)
	window:setAllowScreensaver(false)

	return window
end


function settingsNetworksShow(self, iface, callback)
	local region = self:getSettings()['region']
	log:warn('region: ', region)

	-- if ethernet interface is passed to this method, connect it
	if iface and not iface:isWireless() then
		self.scanResults = {}
		self:_scanComplete(iface)

		return self:createAndConnect(iface, iface:getName() )
	end

	if not region then
		return self:setupRegionShow(
				function() 
					self:settingsNetworksShow() 
				end, 
				self.wlanIface
		)
	end

	self.setupNext = callback

	return setupScanShow(self,
		nil, -- all interfaces
		function()
			self:_networksShow(
				nil,
				self:string("NETWORK"),
				self:string("NETWORK_SETTINGS_HELP")
			)
		end,
		callback
	)
end


function _networksShow(self, iface, title, help)
	local interfaces

	if iface == nil then
		interfaces = Networking:interfaces(jnt)
	else
		interfaces = { dummy = iface }
	end

	local window = Window("window", title, wirelessTitleStyle)
	window:setAllowScreensaver(false)

	-- window to return to on completion of network settings
	self.topWindow = window

	self.scanMenu = SimpleMenu("menu")
	self.scanMenu:setComparator(SimpleMenu.itemComparatorWeightAlpha)

	self.scanResults = {}

	for name, iface in pairs(interfaces) do
		if iface:isWireless() then
			-- add hidden ssid menu
			-- XXXX hidden ssid menu will move to help?
			self.scanMenu:addItem({
				text = self:string("NETWORK_ENTER_ANOTHER_NETWORK"),
				sound = "WINDOWSHOW",
				callback = function()
					enterSSID(self, iface)
				end,
				weight = 3
			})
		end

		-- process existing scan results
		self:_scanComplete(iface)
	end

	-- schedule network scan 
	self.scanMenu:addTimer(5000,
		function()
			for name, iface in pairs(interfaces) do
				self:scan(iface)
			end
		end)

	local help = Textarea("help", help)
	window:addWidget(help)
	window:addWidget(self.scanMenu)

	self:tieAndShowWindow(window)
	return window
end


function scan(self, iface)
	iface:scan(function()
		_scanComplete(self, iface)
	end)
end


function _scanComplete(self, iface)
	local now = Framework:getTicks()

	local scanTable = iface:scanResults()

	local associated = self.currentSSID
	for ssid, entry in pairs(scanTable) do
		-- hide squeezebox ad-hoc networks
		if not string.match(ssid, "logitech[%-%+%*]squeezebox[%-%+%*](%x+)") then

			if not self.scanResults[ssid] then
				_addNetwork(self, iface, ssid)
			end

			-- always update the id, bssid and flags
			self.scanResults[ssid].id = entry.id
			self.scanResults[ssid].bssid = entry.bssid
			self.scanResults[ssid].flags = entry.flags

			if entry.associated then
				associated = ssid
			end

			local itemStyle
			if iface:isWireless() then
				itemStyle = "wirelessLevel" .. entry.quality
			else
				itemStyle = entry.link and "wiredEthernetLink" or "wiredEthernetNoLink"
			end

			local item = self.scanResults[ssid].item
			item.icon:setStyle(itemStyle)

			if self.scanMenu then
				self.scanMenu:updatedItem(item)
			end
		end
	end

	-- remove old networks
	for ssid, entry in pairs(self.scanResults) do
		if entry.iface == iface and not scanTable[ssid] then
			if self.scanMenu then
				self.scanMenu:removeItem(entry.item)
			end
			self.scanResults[ssid] = nil
		end
	end

	-- update current ssid 
	self:_setCurrentSSID(associated)
end


function _hideToTop(self, dontSetupNext)
	log:info('_hideToTop')
	if not self.setupNext then
		log:info('no setupNext callback, so hide windows up to the top')
		if Framework.windowStack[1] == self.topWindow then
			return
		end
	
		while #Framework.windowStack > 2 and Framework.windowStack[2] ~= self.topWindow do
			log:debug("hiding=", Framework.windowStack[2], " topWindow=", self.topWindow)
			Framework.windowStack[2]:hide(Window.transitionPushLeft)
		end
	
		Framework.windowStack[1]:hide(Window.transitionPushLeft)
	end

	-- we have successfully setup the network, so hide any open network
	-- settings windows before advancing during setup.
	if dontSetupNext ~= true and type(self.setupNext) == "function" then
		self.setupNext()
		return
	end
end


function openNetwork(self, iface, ssid)
	assert(iface and ssid, debug.traceback())
	if ( iface and not iface:isWireless() ) or ssid == self.currentSSID then
		-- current network, show status
		if type(self.setupNext) == "function" then
			return self.setupNext()
		else
			return networkStatusShow(self, iface)
		end

	elseif self.scanResults[ssid] and
		self.scanResults[ssid].id ~= nil then
		-- known network, give options
		-- XXXX
		return connectOrDelete(self, iface, ssid)

	else
		-- unknown network, enter password, include check for WPS
		return enterPassword(self, iface, ssid, true)
	end
end


function enterSSID(self, iface)
	assert(iface, debug.traceback())

	local window = Window("window", self:string("NETWORK_NETWORK_NAME"), wirelessTitleStyle)
	window:setAllowScreensaver(false)

	local textinput = Textinput("textinput", "",
				    function(widget, value)
					    if #value == 0 then
						    return false
					    end

					    widget:playSound("WINDOWSHOW")
					    -- include check for WPS
					    enterPassword(self, iface, value, true)

					    return true
				    end
			    )

	local helpButton = Button( Label( 'helpTouchButton', self:string("NETWORK_CONNECTION_HELP")), function() self:helpWindow('NETWORK_NETWORK_NAME', 'NETWORK_NETWORK_NAME_HELP') end )

	window:addWidget(textinput)
	window:addWidget(helpButton)
	window:addWidget(Keyboard("keyboard", 'qwerty'))
	window:focusWidget(textinput)

	self:tieAndShowWindow(window)
	return window
end


function enterPassword(self, iface, ssid, checkWPS)
	assert(iface and ssid, debug.traceback())

	if self.scanResults[ssid] == nil then
		return chooseEncryption(self, iface, ssid)
	end
	local flags = self.scanResults[ssid].flags

	log:debug("ssid is: ", ssid, " flags are: ", flags)

	if flags == "" then
		self.encryption = "none"
		return createAndConnect(self, iface, ssid)

	elseif string.find(flags, "ETH") then
		self.encryption = "none"
		return createAndConnect(self, iface, ssid)

-- 01/27/09 - fm - WPS - begin
	elseif checkWPS and string.find(flags, "WPS") then
		self.encryption = "wpa2"
		return chooseWPS(self, iface, ssid)
-- 01/27/09 - fm - WPS - end

	elseif string.find(flags, "WPA2%-PSK") then
		self.encryption = "wpa2"
		return enterPSK(self, iface, ssid)

	elseif string.find(flags, "WPA%-PSK") then
		self.encryption = "wpa"
		return enterPSK(self, iface, ssid)

	elseif string.find(flags, "WEP") then
		return chooseWEPLength(self, iface, ssid)

	elseif string.find(flags, "WPA%-EAP") or string.find(flags, "WPA2%-EAP") then
		local window = Window("window", self:string("NETWORK_CONNECTION_PROBLEM"))
		window:setAllowScreensaver(false)

		local menu = SimpleMenu("menu",
					{
						{
							text = self:string("NETWORK_GO_BACK"),
							sound = "WINDOWHIDE",
							callback = function()
									   window:hide()
								   end
						},
					})

		local help = Textarea("help", self:string("NETWORK_UNSUPPORTED_TYPES_HELP"))
--"WPA-EAP and WPA2-EAP are not supported encryption types.")

		window:addWidget(help)
		window:addWidget(menu)

		self:tieAndShowWindow(window)		
		return window

	else
		return chooseEncryption(self, iface, ssid)

	end
end


function chooseEncryption(self, iface, ssid)
	assert(iface and ssid, debug.traceback())

	local window = Window("window", self:string("NETWORK_WIRELESS_ENCRYPTION"), wirelessTitleStyle)
	window:setAllowScreensaver(false)

	local menu = SimpleMenu("menu",
				{
					{
						text = self:string("NETWORK_NO_ENCRYPTION"),
						sound = "WINDOWSHOW",
						callback = function()
								   self.encryption = "none"
								   createAndConnect(self, iface, ssid)
							   end
					},
					{
						text = self:string("NETWORK_WEP_64"),
						sound = "WINDOWSHOW",
						callback = function()
								   self.encryption = "wep40"
								   enterWEPKey(self, iface, ssid)
							   end
					},
					{
						text = self:string("NETWORK_WEP_128"),
						sound = "WINDOWSHOW",
						callback = function()
								   self.encryption = "wep104"
								   enterWEPKey(self, iface, ssid)
							   end
					},
					{
						text = self:string("NETWORK_WPA"),
						sound = "WINDOWSHOW",
						callback = function()
								   self.encryption = "wpa"
								   enterPSK(self, iface, ssid)
							   end
					},
					{
						text = self:string("NETWORK_WPA2"),
						sound = "WINDOWSHOW",
						callback = function()
								   self.encryption = "wpa2"
								   enterPSK(self, iface, ssid)
							   end
					},
				})

	local helpButton     = Button( Label( 'helpTouchButton', self:string("NETWORK_CONNECTION_HELP")), function() self:helpWindow('NETWORK_WIRELESS_ENCRYPTION', 'NETWORK_WIRELESS_ENCRYPTION_HELP') end )
	window:addWidget(helpButton)
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function helpWindow(self, title, token)
	local window = Window("window", self:string(title), wirelessTitleStyle)
	window:setAllowScreensaver(false)
	window:addWidget(Textarea("textarea", self:string(token)))

	self:tieAndShowWindow(window)
	return window
end


function chooseWEPLength(self, iface, ssid)
	assert(iface and ssid, debug.traceback())

	local window = Window("button", self:string("NETWORK_WIRELESS_ENCRYPTION"), wirelessTitleStyle)
	window:setAllowScreensaver(false)

	local menu = SimpleMenu("menu",
				{
					{
						text = self:string("NETWORK_WEP_64"),
						style = 'buttonitem',
						sound = "WINDOWSHOW",
						callback = function()
								   self.encryption = "wep40"
								   enterWEPKey(self, iface, ssid)
							   end
					},
					{
						text = self:string("NETWORK_WEP_128"),
						style = 'buttonitem',
						sound = "WINDOWSHOW",
						callback = function()
								   self.encryption = "wep104"
								   enterWEPKey(self, iface, ssid)
							   end
					},
				})

	local helpButton     = Button( Label( 'helpTouchButton', self:string("NETWORK_CONNECTION_HELP")), function() self:helpWindow('NETWORK_WIRELESS_ENCRYPTION', 'NETWORK_WIRELESS_ENCRYPTION_HELP') end )
	window:addWidget(helpButton)
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function enterWEPKey(self, iface, ssid)
	assert(iface and ssid, debug.traceback())

	local window = Window("window", self:string("NETWORK_WIRELESS_KEY"), wirelessTitleStyle)
	window:setAllowScreensaver(false)

	local v
	-- set the initial value
	if self.encryption == "wep40" then
		v = Textinput.textValue("0000000000", 10, 10)
	else
		v = Textinput.textValue("00000000000000000000000000", 26, 26)
	end

	local textinput = Textinput("textinput", v,
				    function(widget, value)
					    self.key = value:getValue()

					    widget:playSound("WINDOWSHOW")
					    createAndConnect(self, iface, ssid)

					    return true
				    end
			    )

	local keyboard = Keyboard('keyboard', 'hex')
	local helpButton     = Button( Label( 'helpTouchButton', self:string("NETWORK_CONNECTION_HELP")), function() self:helpWindow('NETWORK_WIRELESS_KEY', 'NETWORK_WIRELESS_KEY_HELP') end )

	window:addWidget(textinput)
	window:addWidget(helpButton)
	window:addWidget(keyboard)
	window:focusWidget(textinput)

	self:tieAndShowWindow(window)
	return window
end


function enterPSK(self, iface, ssid)
	assert(iface and ssid, debug.traceback())

	local window = Window("window", self:string("NETWORK_WIRELESS_PASSWORD"), wirelessTitleStyle)
	window:setAllowScreensaver(false)

	local v = Textinput.textValue(self.psk, 8, 63)
	local textinput = Textinput("textinput", v,
				    function(widget, value)
					    self.psk = tostring(value)

					    widget:playSound("WINDOWSHOW")
					    createAndConnect(self, iface, ssid)

					    return true
				    end,
				    self:string("ALLOWEDCHARS_WPA")
			    )
	local helpButton     = Button( Label( 'helpTouchButton', self:string("NETWORK_CONNECTION_HELP")), function() self:helpWindow('NETWORK_WIRELESS_PASSWORD', 'NETWORK_WIRELESS_PASSWORD_HELP') end )

	window:addWidget(helpButton)
	window:addWidget(textinput)
	window:addWidget(Keyboard('keyboard', 'qwerty'))
	window:focusWidget(textinput)



	self:tieAndShowWindow(window)
	return window
end


function _addNetworkTask(self, iface, ssid)
	assert(iface and ssid, debug.traceback())

	local option = {
		encryption = self.encryption,
		psk = self.psk,
		key = self.key
	}

	local id = iface:t_addNetwork(ssid, option)

	self.addNetwork = true
	if self.scanResults[ssid] then
		self.scanResults[ssid].id = id
	end
end


function _connectTimer(self, iface, ssid)
	assert(iface and ssid, debug.traceback())

	Task("networkConnect", self,
	     function()
		     log:debug("connectTimeout=", self.connectTimeout, " dhcpTimeout=", self.dhcpTimeout)

		     local status = iface:t_wpaStatus()

		     log:debug("wpa_state=", status.wpa_state)
		     log:debug("ip_address=", status.ip_address)

		     if not (status.wpa_state == "COMPLETED" and status.ip_address) then
			     -- not connected yet

			     self.connectTimeout = self.connectTimeout + 1
			     if self.connectTimeout ~= CONNECT_TIMEOUT then
				     return
			     end

			     -- connection timed out
			     self:connectFailed(iface, ssid, "timeout")
			     return
		     end
			    
		     if string.match(status.ip_address, "^169.254.") then
			     -- auto ip
			     self.dhcpTimeout = self.dhcpTimeout + 1
			     if self.dhcpTimeout ~= CONNECT_TIMEOUT then
				     return
			     end

			     -- dhcp timed out
			     self:failedDHCP(iface, ssid)
		     else
			     -- dhcp completed
			     self:connectOK(iface, ssid)
		     end
	     end):addTask()
end


function selectNetworkTask(self, iface, ssid)
	assert(iface and ssid, debug.traceback())

	iface:t_disconnectNetwork()

	if self.createNetwork == ssid then
		-- remove the network config
		self:_removeNetworkTask(iface, ssid)
	end

	if self.scanResults[ssid] == nil then
		-- ensure the network state exists
		_addNetwork(self, iface, ssid)
	end

	local id = self.scanResults[ssid].id

	if id == nil then
		-- create the network config
		self:_addNetworkTask(iface, ssid)
	end

	iface:t_selectNetwork(ssid)
end


function createAndConnect(self, iface, ssid)
	assert(iface and ssid, debug.traceback())

	log:debug("createAndConnect ", iface, " ", ssid)

	self.createNetwork = ssid
	connect(self, iface, ssid)
end

function attachWireMessage(self, iface, ssid, keepConfig)

	local window = Window("window", self:string("NETWORK_ATTACH_CABLE"))
        window:setAllowScreensaver(false)

	local textarea = Textarea('textarea', self:string("NETWORK_ATTACH_CABLE_DETAILED"))
	window:addWidget(textarea)

	window:addTimer(500,
		function(event)
			log:debug("Checking Link")
			 Task("wireConnect", self,
				function()
					local status = iface:t_wpaStatus()
					log:debug("link=", status.link)
					if status.link then
						log:debug("connected")
						window:hide()
						self:connect(iface, ssid, keepConfig)
					end
             			end
			):addTask()
		end
	)

	self:tieAndShowWindow(window)
end

function connect(self, iface, ssid, keepConfig)
	assert(iface and ssid, debug.traceback())

	self.connectTimeout = 0
	self.dhcpTimeout = 0

	if not iface:isWireless() then
		local status = iface:t_wpaStatus()
		if not status.link then
			return self:attachWireMessage(iface, ssid, keepConfig)
		end
	end

	if not keepConfig then
		self:_setCurrentSSID(nil)

		-- Select/add the network in a background task
		Task("networkSelect", self, selectNetworkTask):addTask(iface, ssid)
	end

	-- Progress window
	local window = Popup("popupIcon")

	local icon  = Icon("iconConnecting")
	icon:addTimer(1000,
		function()
			self:_connectTimer(iface, ssid)
		end)
	window:addWidget(icon)

	local name = self.scanResults[ssid].item.text
	window:addWidget(Label("text", self:string("NETWORK_CONNECTING_TO_SSID", name)))

	self:tieAndShowWindow(window)
	return window
end


function _connectFailedTask(self, iface, ssid)
	-- Stop trying to connect to the network
	iface:t_disconnectNetwork()

	if self.addNetwork then
		-- Remove failed network
		self:_removeNetworkTask(iface, ssid)
		self.addNetwork = nil
	end
end


function connectFailed(self, iface, ssid, reason)
	assert(iface and ssid, debug.traceback())

	log:debug("connection failed")

	-- Stop trying to connect to the network, if this network is
	-- being added this will also remove the network configuration
	Task("networkFailed", self, _connectFailedTask):addTask(iface, ssid)

	-- Message based on failure type
	local helpText = self:string("NETWORK_CONNECTION_PROBLEM_HELP")

	if reason == "psk" then
		helpText = tostring(helpText) .. " " .. tostring(self:string("NETWORK_PROBLEM_PASSWORD_INCORRECT"))
	end


	-- popup failure
	local window = Window("window", self:string("NETWORK_CONNECTION_PROBLEM"), wirelessTitleStyle)
	window:setAllowScreensaver(false)

	local menu = SimpleMenu("menu",
				{
					{
						text = self:string("NETWORK_TRY_AGAIN"),
						sound = "WINDOWHIDE",
						callback = function()
								   connect(self, iface, ssid)
								   window:hide(Window.transitionNone)
							   end
					},
					{
						text = self:string("NETWORK_TRY_DIFFERENT"),
						sound = "WINDOWSHOW",
						callback = function()
								   _hideToTop(self, true)
							   end
					},
					{
						text = self:string("NETWORK_GO_BACK"),
						sound = "WINDOWHIDE",
						callback = function()
								   window:hide()
							   end
					},
				})


	local help = Textarea("help", helpText)

	window:addWidget(help)
	window:addWidget(menu)

	self:tieWindow(window)
	window:show()

	return window
end


function connectOK(self, iface, ssid)
	assert(iface and ssid, debug.traceback())

	if ssid == nil then
		-- make sure we are still trying to connect
		return
	end

	log:debug("connection OK ", ssid)

	self:_setCurrentSSID(ssid)

	-- forget connection state
	self.encryption = nil
	self.psk = nil
	self.key = nil

	-- send notification we're on a new network
	jnt:notify("networkConnected")

	-- popup confirmation
	local window = Popup("popupIcon")
	window:addWidget(Icon("iconConnected"))

	local name = self.scanResults[ssid].item.text
	local text = Label("text", self:string("NETWORK_CONNECTED_TO", name))
	window:addWidget(text)

	window:addTimer(2000,
			function(event)
			log:debug("CALLING TIMER")
				window:hide()
				_hideToTop(self)
			end,
			true)

	window:addListener(EVENT_KEY_PRESS,
			   function(event)
				window:hide()
				_hideToTop(self)
				return EVENT_CONSUME
			   end)


	self:tieWindow(window)
	window:show()
	return window
end


function _parseip(str)
	local ip = 0
	for w in string.gmatch(str, "%d+") do
		ip = ip << 8
		ip = ip | tonumber(w)
	end
	return ip
end


function _ipstring(ip)
	local str = {}
	for i = 4,1,-1 do
		str[i] = string.format("%d", ip & 0xFF)
		ip = ip >> 8
	end
	str = table.concat(str, ".")
	return str
end


function _validip(str)
	local ip = _parseip(str)
	if ip == 0x00000000 or ip == 0xFFFFFFFF then
		return false
	else
		return true
	end
end


function _subnet(self)
	local ip = _parseip(self.ipAddress or "0.0.0.0")

	if ((ip & 0xC0000000) == 0xC0000000) then
		return "255.255.255.0"
	elseif ((ip & 0x80000000) == 0x80000000) then
		return "255.255.0.0"
	elseif ((ip & 0x80000000) == 0) then
		return "255.0.0.0"
	else
		return "0.0.0.0";
	end
end


function _gateway(self)
	local ip = _parseip(self.ipAddress or "0.0.0.0")
	local subnet = _parseip(self.ipSubnet or "255.255.255.0")

	return _ipstring(ip & subnet | 1)
end


function _sigusr1(process)
	local pid

	local pattern = "%s*(%d+).*" .. process

	local cmd = io.popen("/bin/ps")
	for line in cmd:lines() do
		pid = string.match(line, pattern)
		if pid then break end
	end
	cmd:close()

	if pid then
		log:debug("kill -usr1 ", pid)
		os.execute("kill -usr1 " .. pid)
	else
		log:error("cannot sigusr1 ", process)
	end
end


function failedDHCP(self, iface, ssid)
	assert(iface and ssid, debug.traceback())

	log:debug("self.encryption=", self.encryption)

	if self.encryption and string.match(self.encryption, "^wep.*") then
		-- use different error screen for WEP, the failure may
		-- be due to a bad WEP passkey, not DHCP.
		return failedDHCPandWEP(self, iface, ssid)
	else
		return failedDHCPandWPA(self, iface, ssid)
	end
end


function failedDHCPandWPA(self, iface, ssid)
	assert(iface and ssid, debug.traceback())

	local window = Window("window", self:string("NETWORK_ADDRESS_PROBLEM"), wirelessTitleStyle)
	window:setAllowScreensaver(false)

	local menu = SimpleMenu("menu",
				{
					{
						text = self:string("NETWORK_TRY_AGAIN"),
						sound = "WINDOWHIDE",
						callback = function()
								   -- poke udhcpto try again
								   _sigusr1("udhcpc")
								   connect(self, iface, ssid, true)
								   window:hide(Window.transitionNone)
							   end
					},
					{
						text = self:string("ZEROCONF_ADDRESS"),
						sound = "WINDOWSHOW",
						callback = function()
								   -- already have a self assigned address, we're done
								   connectOK(self, iface, ssid)
							   end
					},
					{
						text = self:string("STATIC_ADDRESS"),
						sound = "WINDOWSHOW",
						callback = function()
								   enterIP(self, iface, ssid)
							   end
					},
				})


	local help = Textarea("help", self:string("NETWORK_ADDRESS_HELP"))

	window:addWidget(help)
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function failedDHCPandWEP(self, iface, ssid)
	assert(iface and ssid, debug.traceback())

	local window = Window("window", self:string("NETWORK_CONNECTION_PROBLEM"), wirelessTitleStyle)
	window:setAllowScreensaver(false)

	local menu = SimpleMenu("menu",
				{
					{
						text = self:string("NETWORK_TRY_AGAIN"),
						sound = "WINDOWHIDE",
						callback = function()
								   -- poke udhcpto try again
								   _sigusr1("udhcpc")
								   connect(self, iface, ssid, true)
								   window:hide(Window.transitionNone)
							   end
					},



					{
						text = self:string("NETWORK_EDIT_WIRELESS_KEY"),
						sound = "WINDOWHIDE",
						callback = function()
								   window:hide()
							   end
					},



					{
						text = self:string("ZEROCONF_ADDRESS"),
						sound = "WINDOWSHOW",
						callback = function()
								   -- already have a self assigned address, we're done
								   connectOK(self, iface, ssid)
							   end
					},
					{
						text = self:string("STATIC_ADDRESS"),
						sound = "WINDOWSHOW",
						callback = function()
								   enterIP(self, iface, ssid)
							   end
					},
				})


	local help = Textarea("help", self:string("NETWORK_ADDRESS_HELP_WEP"))

	window:addWidget(help)
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end

function enterIP(self, iface, ssid)
	assert(iface and ssid, debug.traceback())

	local v = Textinput.ipAddressValue(self.ipAddress or "0.0.0.0")

	local window = Window("window", self:string("NETWORK_IP_ADDRESS"), wirelessTitleStyle)
	window:setAllowScreensaver(false)

	local textinput = Textinput("textinput", v,
				   function(widget, value)
					   value = value:getValue()
					   if not _validip(value) then
						   return false
					   end

					   self.ipAddress = value
					   self.ipSubnet = _subnet(self)

					   widget:playSound("WINDOWSHOW")
					   self:enterSubnet(iface, ssid)
					   return true
				   end)
	local keyboard = Keyboard("keyboard", "numeric")
	local helpButton = Button( Label( 'helpTouchButton', self:string("NETWORK_CONNECTION_HELP")), function() self:helpWindow('NETWORK_IP_ADDRESS', 'NETWORK_IP_ADDRESS_HELP') end )

	window:addWidget(helpButton)
	window:addWidget(textinput)
	window:addWidget(keyboard)
	window:focusWidget(textinput)

	self:tieAndShowWindow(window)
	return window
end


function enterSubnet(self, iface, ssid)
	assert(iface and ssid, debug.traceback())

	local v = Textinput.ipAddressValue(self.ipSubnet)

	local window = Window("window", self:string("NETWORK_SUBNET"), wirelessTitleStyle)
	window:setAllowScreensaver(false)

	local textinput = Textinput("textinput", v,
				   function(widget, value)
					   value = value:getValue()

					   self.ipSubnet = value
					   self.ipGateway = _gateway(self)

					   widget:playSound("WINDOWSHOW")
					   self:enterGateway(iface, ssid)
					   return true
				   end)
	local keyboard = Keyboard("keyboard", "numeric")
	local helpButton = Button( Label( 'helpTouchButton', self:string("NETWORK_CONNECTION_HELP")), function() self:helpWindow('NETWORK_SUBNET', 'NETWORK_SUBNET_HELP') end )

	window:addWidget(helpButton)
	window:addWidget(textinput)
	window:addWidget(keyboard)
	window:focusWidget(textinput)


	self:tieAndShowWindow(window)
	return window
end


function enterGateway(self, iface, ssid)
	assert(iface and ssid, debug.traceback())

	local v = Textinput.ipAddressValue(self.ipGateway)

	local window = Window("window", self:string("NETWORK_GATEWAY"), wirelessTitleStyle)
	window:setAllowScreensaver(false)

	local textinput = Textinput("textinput", v,
				   function(widget, value)
					   value = value:getValue()

					   if not _validip(value) then
						   return false
					   end

					   self.ipGateway = value
					   self.ipDNS = self.ipGateway

					   widget:playSound("WINDOWSHOW")
					   self:enterDNS(iface, ssid)
					   return true
				   end)

	local keyboard = Keyboard("keyboard", "numeric")
	local helpButton = Button( Label( 'helpTouchButton', self:string("NETWORK_CONNECTION_HELP")), function() self:helpWindow('NETWORK_GATEWAY', 'NETWORK_GATEWAY_HELP') end )

	window:addWidget(helpButton)
	window:addWidget(textinput)
	window:addWidget(keyboard)
	window:focusWidget(textinput)

	self:tieAndShowWindow(window)
	return window
end


function enterDNS(self, iface, ssid)
	assert(iface and ssid, debug.traceback())

	local v = Textinput.ipAddressValue(self.ipDNS)

	local window = Window("window", self:string("NETWORK_DNS"), wirelessTitleStyle)
	window:setAllowScreensaver(false)

	local textinput = Textinput("textinput", v,
				   function(widget, value)
					   value = value:getValue()

					   if not _validip(value) then
						   return false
					   end

					   self.ipDNS = value

					   widget:playSound("WINDOWSHOW")
					   self:setStaticIP(iface, ssid)
					   return true
				   end)
	local keyboard = Keyboard("keyboard", "numeric")
	local helpButton = Button( Label( 'helpTouchButton', self:string("NETWORK_CONNECTION_HELP")), function() self:helpWindow('NETWORK_DNS', 'NETWORK_DNS_HELP') end )

	window:addWidget(helpButton)
	window:addWidget(textinput)
	window:addWidget(keyboard)
	window:focusWidget(textinput)

	self:tieAndShowWindow(window)
	return window
end


function setStaticIP(self, iface, ssid)
	assert(iface and ssid, debug.traceback())

	log:debug("setStaticIP addr=", self.ipAddress, " subnet=", self.ipSubnet, " gw=", self.ipGateway, " dns=", self.ipDNS)

	Task("networkStatic", self,
	     function()
		     iface:t_setStaticIP(ssid, self.ipAddress, self.ipSubnet, self.ipGateway, self.ipDNS)
		     connectOK(self, iface, ssid)
	     end):addTask()
end


function _removeNetworkTask(self, iface, ssid)
	assert(iface and ssid, debug.traceback())

	iface:t_removeNetwork(ssid)

	if self.scanResults[ssid] then
		-- remove from menu
		local item = self.scanResults[ssid].item
		if self.scanMenu then
			self.scanMenu:removeItem(item)
		end

		-- clear entry
		self.scanResults[ssid] = nil
	end
end


function removeNetwork(self, iface, ssid)
	assert(iface and ssid, debug.traceback())

	-- forget the network
	Task("networkRemove", self, _removeNetworkTask):addTask(iface, ssid)

	-- popup confirmation
	local window = Popup("popupIcon")
	window:addWidget(Icon("iconConnected"))

	local text = Label("text", self:string("NETWORK_FORGOTTEN_NETWORK", ssid))
	window:addWidget(text)

	self:tieWindow(window)
	window:showBriefly(2000, function() _hideToTop(self) end)

	return window
end


function connectOrDelete(self, iface, ssid)
	assert(iface and ssid, debug.traceback())

	local window = Window("window", ssid, wirelessTitleStyle)
	window:setAllowScreensaver(false)

	local menu = SimpleMenu("menu",
				{
					{
						text = self:string("NETWORK_CONNECT_TO_NETWORK"), nil,
						sound = "WINDOWSHOW",
						callback = function()
								   connect(self, iface, ssid)
							   end
					},
					{
						text = self:string("NETWORK_FORGET_NETWORK"), nil,
						sound = "WINDOWSHOW",
						callback = function()
								   deleteConfirm(self, iface, ssid)
							   end
					},
				})

	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function deleteConfirm(self, iface, ssid)
	assert(iface and ssid, debug.traceback())

	local window = Window("window", self:string("NETWORK_FORGET_NETWORK"), wirelessTitleStyle)
	window:setAllowScreensaver(false)

	local menu = SimpleMenu("menu",
				{
					{
						text = self:string("NETWORK_FORGET_CANCEL"), nil,
						sound = "WINDOWHIDE",
						callback = function()
								   window:hide()
							   end
					},
					{
						text = self:string("NETWORK_FORGET_CONFIRM", ssid), nil,
						sound = "WINDOWSHOW",
						callback = function()
								   removeNetwork(self, iface, ssid)
							   end
					},
				})

	window:addWidget(Textarea("help", self:string("NETWORK_FORGET_HELP", ssid)))
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


local stateTxt = {
	[ "DISCONNECTED" ] = "NETWORK_STATE_DISCONNECTED",
	[ "INACTIVE" ] = "NETWORK_STATE_DISCONNECTED",
	[ "SCANNING" ] = "NETWORK_STATE_SCANNING",
	[ "ASSOCIATING" ] = "NETWORK_STATE_CONNECTING",
	[ "ASSOCIATED" ] = "NETWORK_STATE_CONNECTING",
	[ "4WAY_HANDSHAKE" ] = "NETWORK_STATE_HANDSHAKE",
	[ "GROUP_HANDSHAKE" ] = "NETWORK_STATE_HANDSHAKE",
	[ "COMPLETED" ] = "NETWORK_STATE_CONNECTED",
}


function networkStatusTask(self, iface, values)
	local status = iface:t_wpaStatus()

	if iface:isWireless() then
		local snr = iface:getSNR()
		local bitrate = iface:getTxBitRate()

		local wpa_state = stateTxt[status.wpa_state] or "NETWORK_STATE_UNKNOWN"

		local encryption = status.key_mgmt
		-- white lie :)
		if string.match(status.pairwise_cipher, "WEP") then
			encryption = "WEP"
		end

		-- update the ui
		values[1]:setValue(self:string(wpa_state))
		values[2]:setValue(tostring(status.ssid))
		values[3]:setValue(tostring(status.bssid))
		values[4]:setValue(tostring(encryption))
		values[5]:setValue(tostring(status.ip_address))
		values[6]:setValue(tostring(snr))
		values[7]:setValue(tostring(bitrate))
	else
		if status.link then
			values[1]:setValue(status.fullduplex and self:string("NETWORK_ETH_CONNECTED") or self:string("NETWORK_ETH_HALF_DUPLEX"))
			values[2]:setValue(self:string("NETWORK_ETH_MBPS", status.speed))
			values[3]:setValue(tostring(status.ip_address))
		else
			values[1]:setValue(self:string("NETWORK_ETH_NOT_CONNECTED"))
			values[2]:setValue("")
			values[3]:setValue("")
		end
	end
end


function networkStatusTimer(self, iface, values)
	local t = Task("networkStatus", self, networkStatusTask)
	t:addTask(iface, values)
end


function networkStatusShow(self, iface)
	local window = Window("window", self:string("NETWORK_STATUS"), wirelessTitleStyle)
	window:setAllowScreensaver(false)

	local values = {}
	for i=1,7 do
		values[i] = Label("value", "")
	end

	local items
	if iface:isWireless() then
		items = {
			{ text = self:string("NETWORK_STATE"), icon = values[1] },
			{ text = self:string("NETWORK_SSID"), icon = values[2] },
			{ text = self:string("NETWORK_BSSID"), icon = values[3] },
			{ text = self:string("NETWORK_ENCRYPTION"), icon = values[4] },
			{ text = self:string("NETWORK_IP_ADDRESS"), icon = values[5] },
			{ text = self:string("NETWORK_SNR"), icon = values[6] },
			{ text = self:string("NETWORK_BITRATE"), icon = values[7] },
		}
	else
		items = {
			{ text = self:string("NETWORK_ETH_STATUS"), icon = values[1] },
			{ text = self:string("NETWORK_ETH_SPEED"), icon = values[2] },
			{ text = self:string("NETWORK_IP_ADDRESS"), icon = values[3] },
		}
	end

	items[#items + 1] = {
		text = self:string("NETWORK_FORGET_NETWORK"), nil,
		sound = "WINDOWSHOW",
		callback = function()
			deleteConfirm(self, iface, self.currentSSID)
		end
	}

	-- FIXME format this nicely
	local menu = SimpleMenu("menu", items)
	window:addWidget(menu)

	self:networkStatusTimer(iface, values)
	window:addTimer(1000,
		function()
			self:networkStatusTimer(iface, values)
		end)

	self:tieAndShowWindow(window)
	return window
end


-- 01/27/09 - fm - WPS - begin
function setupWPSHelp(self)
	local window = Window("window", self:string("NETWORK_WPS_HELP"), 'setuptitle')
	window:setAllowScreensaver(false)

	local textarea = Textarea("textarea", self:string("NETWORK_WPS_HELP_BODY"))
	window:addWidget(textarea)
	self:tieAndShowWindow(window)

	return window
end


function chooseWPS(self, iface, ssid)
	log:debug('chooseWPS')

	local wpspin = iface:generateWPSPin()

	-- ask the user to choose
	local window = Window("window", self:string("NETWORK_WPS_METHOD"), wirelessTitleStyle)
	window:setAllowScreensaver(false)

	local connectionMenu = SimpleMenu("menu")

	connectionMenu:addItem({
		text = (self:string("NETWORK_WPS_METHOD_PBC")),
		sound = "WINDOWSHOW",
		callback = function()
			processWPS(self, iface, ssid, "pbc")
		end,
		weight = 1
	})

	connectionMenu:addItem({
		text = (self:string("NETWORK_WPS_METHOD_PIN", tostring(wpspin))),
		sound = "WINDOWSHOW",
		callback = function()
			processWPS(self, iface, ssid, "pin", wpspin)
		end,
		weight = 2
	})

-- TODO: Remove if we decide not to offer regular psk entry for WPS capable routers / APs
	connectionMenu:addItem({
		text = (self:string("NETWORK_WPS_METHOD_PSK")),
		sound = "WINDOWSHOW",
		callback = function()
			-- Calling regular enter password function (which determinds the
			--  encryption) but do not check flags for WPS anymore to prevent
			--  ending up in this function again
			enterPassword(self, iface, ssid, false)
		end,
		weight = 3
	})

	local helpButton = Button( Label( 'helpTouchButton', self:string("NETWORK_WPS_HELP")), function() self:setupWPSHelp() end )

	window:addWidget(helpButton)
	window:addWidget(connectionMenu)

	self:tieAndShowWindow(window)
	return window
end


function processWPS(self, iface, ssid, wpsmethod, wpspin)
	assert(iface and ssid and wpsmethod, debug.traceback())

	self.processWPSTimeout = 0

	-- Stop wpa_supplicant - cannot run while wpsapp is running
	iface:stopWPASupplicant()
	-- Remove wps.conf, (re-)start wpsapp
	iface:startWPSApp(wpsmethod, wpspin)

	-- Progress window
	local popup = Popup("popupIcon")
	popup:setAllowScreensaver(false)

	popup:addWidget(Icon("iconConnecting"))
	if wpsmethod == "pbc" then
		popup:addWidget(Label("text", self:string("NETWORK_WPS_PROGRESS_PBC")))
	else
		popup:addWidget(Label("text", self:string("NETWORK_WPS_PROGRESS_PIN", tostring(wpspin))))
	end

	local status = Label("text2", self:string("NETWORK_WPS_REMAINING_WALK_TIME", tostring(WPS_WALK_TIMEOUT)))
	popup:addWidget(status)

	popup:addTimer(1000, function()
			self:_timerWPS(iface, ssid)

			local remaining_walk_time = WPS_WALK_TIMEOUT - self.processWPSTimeout
			status:setValue(self:string("NETWORK_WPS_REMAINING_WALK_TIME", tostring(remaining_walk_time)))
		end)

	local _stopWPSAction = function(self, event)
		iface:stopWPSApp()
		iface:startWPASupplicant()
		popup:hide()
	end

	popup:addActionListener("back", self, _stopWPSAction)
	popup:addActionListener("disconnect_player", self, _stopWPSAction)
	popup:ignoreAllInputExcept({"back","disconnect_player"})

	self:tieAndShowWindow(popup)
	return popup
end


function _timerWPS(self, iface, ssid)
	assert(iface and ssid, debug.traceback())

	Task("networkWPS", self,
		function()
			log:debug("processWPSTimeout=", self.processWPSTimeout)

			local status = iface:t_wpsStatus()
			if not (status.wps_state == "COMPLETED") then
				self.processWPSTimeout = self.processWPSTimeout + 1
				if self.processWPSTimeout ~= WPS_WALK_TIMEOUT then
					return
				end

				-- WPS walk timeout
				self:processWPSFailed(iface, ssid, "timeout")
				return
			else
				-- Make sure wpa supplicant is running again
				iface:startWPASupplicant()

				-- Set credentials from WPS
				self.encryption = status.wps_encryption
				self.psk = status.wps_psk
				self.key = status.wps_key

				createAndConnect(self, iface, ssid)
			end

		end):addTask()
end


function processWPSFailed(self, iface, ssid, reason)
	assert(iface and ssid, debug.traceback())

	log:debug("processWPSFailed")

-- TODO: Remove later (should not be necessary)
	iface:stopWPSApp()

	iface:startWPASupplicant()

-- TODO: Add string according to reason
	-- Message based on failure type
	local helpText = self:string("NETWORK_WPS_PROBLEM_HELP")

	-- popup failure
	local window = Window("window", self:string("NETWORK_WPS_PROBLEM"), wirelessTitleStyle)
	window:setAllowScreensaver(false)

	local menu = SimpleMenu("menu",
				{
-- TODO: more options needed?
--					{
--						text = self:string("NETWORK_TRY_AGAIN"),
--						sound = "WINDOWHIDE",
--						callback = function()
--								   connect(self, iface, ssid)
--								   window:hide(Window.transitionNone)
--							   end
--					},
--					{
--						text = self:string("NETWORK_TRY_DIFFERENT"),
--						sound = "WINDOWSHOW",
--						callback = function()
--								   _hideToTop(self, true)
--							   end
--					},
					{
						text = self:string("NETWORK_GO_BACK"),
						sound = "WINDOWHIDE",
						callback = function()
								   window:hide()
							   end
					},
				})

	local help = Textarea("help", helpText)

	window:addWidget(help)
	window:addWidget(menu)

	self:tieWindow(window)
	window:show()

	return window
end
-- 01/27/09 - fm - WPS - end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
