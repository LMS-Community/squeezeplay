
--[[
=head1 NAME

applets.AccountRegistration

=head1 DESCRIPTION

Applet to register account/player to MySB.com

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 

=cut
--]]


-- stuff we use
local ipairs, pairs, assert, io, string, tonumber = ipairs, pairs, assert, io, string, tonumber

local oo               = require("loop.simple")
local os               = require("os")

local Applet           = require("jive.Applet")
local RadioGroup       = require("jive.ui.RadioGroup")
local RadioButton      = require("jive.ui.RadioButton")
local Framework        = require("jive.ui.Framework")
local Label            = require("jive.ui.Label")
local Icon             = require("jive.ui.Icon")
local Group            = require("jive.ui.Group")
local Button           = require("jive.ui.Button")
local SimpleMenu       = require("jive.ui.SimpleMenu")
local Surface          = require("jive.ui.Surface")
local Task             = require("jive.ui.Task")
local Textarea         = require("jive.ui.Textarea")
local Window           = require("jive.ui.Window")
local Popup            = require("jive.ui.Popup")

local localPlayer      = require("jive.slim.LocalPlayer")
local slimServer       = require("jive.slim.SlimServer")

local DNS              = require("jive.net.DNS")
local Networking       = require("jive.net.Networking")

local debug            = require("jive.utils.debug")
local locale           = require("jive.utils.locale")
local string           = require("jive.utils.string")
local table            = require("jive.utils.table")

local appletManager    = appletManager

local jiveMain         = jiveMain
local jnt              = jnt

module(..., Framework.constants)
oo.class(_M, Applet)

-- service method for starting mysb.com registration flow
function startRegister(self)
	_startRegister(self)
end


-- we are connected when we have a pin and upgrade url
function _squeezenetworkConnected(self, squeezenetwork)
	return squeezenetwork:getPin() ~= nil and squeezenetwork:getUpgradeUrl() and squeezenetwork:isConnected() 
end


function _anySqueezeCenterWithUpgradeFound(self)
	local anyFound = false
	for _,server in appletManager:callService("iterateSqueezeCenters") do
		if server:isCompatible() and server:getUpgradeUrl() and not server:isSqueezeNetwork() then
			log:info("At least one compatible SC with an available upgrade found. First found: ", server)
			anyFound = true
			break
		end
	end

	return anyFound
end


function _startRegister(self)
	log:info("_startRegister")

	local settings = self:getSettings()
	if settings.registerDone then
		log:info("SqueezeNetwork registration complete")
		return
	end

	-- Bug 12786: Selecting a Network, then backing out
	--  and re-selecting will cause network errors
	self.registerRequest = false

	-- Find squeezenetwork server
	local squeezenetwork = false
	for name, server in slimServer:iterate() do
		if server:isSqueezeNetwork() then
			squeezenetwork = server
		end
	end

	if not squeezenetwork then
		log:error("no SqueezeNetwork instance")
		return
	end

	self:_registerRequest(squeezenetwork)

end


function _squeezenetworkWait(self, squeezenetwork)
	log:info("Looking for upgrade, waiting to connect to SqueezeNetwork and find any compatible SCs")

	-- Waiting popup
	local popup = Popup("waiting_popup")

	local icon  = Icon("icon_connecting")
	popup:addWidget(icon)
	popup:addWidget(Label("text", self:string("CONNECTING_TO_SN")))
	popup:addWidget(Label("subtext", self:string("MYSQUEEZEBOX_DOT_COM")))
	popup:setAllowScreensaver(false)
	popup:ignoreAllInputExcept()

	local timeout = 0
	--Wait until SN is connected before going to step 8. Also if SN isn't being found, use available SCs. Allow 10 seconds to go by to give all SCs a chacne to be discovered.
	popup:addTimer(1000, function()
		-- wait until we know if the player is linked
		if _squeezenetworkConnected(self, squeezenetwork) then
			_firmwareUpgrade(self, squeezenetwork)
		else
			log:info("SN not available, Waited: ", timeout + 1)
			--allow 10 seconds to go by before doing SC check to allow SCs to be discovered
			if timeout >= 9 and _anySqueezeCenterWithUpgradeFound(self) then
				_firmwareUpgrade(self, squeezenetwork)
			else
				log:info("Looking for compatible SCs with an upgrade, Waited: ", timeout + 1)
			end
		end


		timeout = timeout + 1

		--try for 30 seconds
		if timeout >= 30 then
			log:info("Can't find any SC or connect to SqueezeNetwork after ", timeout, " seconds")
			_squeezenetworkFailed(self, squeezenetwork)
		end
	end)

	self:tieAndShowWindow(popup)
end


function _squeezenetworkFailed(self, squeezenetwork)
	log:info("_squeezenetworkFailed")
	Task("dns", self, function()
		local serverip = squeezenetwork:getIpPort()

		log:info("Can't connect to SqueezeNetwork: ", serverip)

		local ip, err
		if DNS:isip(serverip) then
			ip = serverip
		else
			ip, err = DNS:toip(serverip)
		end

		-- some routers resolve all DNS addresses to the local
		-- network when the internet is down, we catch these here
		if ip then
			local n = string.split("%.", ip)
			n[1] = tonumber(n[1])
			n[2] = tonumber(n[2])

			-- local addresses
			if n[1] == 192 and n[2] == 168 then
				ip = nil
			elseif n[1] == 172 and n[2] >= 16 and n[2] <=31 then
				ip = nil
			elseif n[1] == 10 then
				ip = nil
			end

			-- test addresses, used by BT homehub on DNS failure
			if n[1] == 192 and n[2] >= 18 and n[2] <= 19 then
				ip = nil
			end
		end


		-- have we connected while looking up the DNS?
		if _squeezenetworkConnected(self, squeezenetwork) then
			log:info("SN now seen")
			return
		end		

		if squeezenetwork:isConnected() then
			-- we're connected, but don't have a PIN or Upgrade state
			log:error("SqueezeNetwork error. pin=", squeezenetwork:getPin(), " upgradeUrl=", squeezenetwork:getUpgradeUrl())
			_squeezenetworkError(self, squeezenetwork, "SN_SYSTEM_ERROR")
		elseif ip == nil then
			-- dns failed
			log:info("DNS failed for ", serverip)
			_squeezenetworkError(self, squeezenetwork, "SN_DNS_FAILED")
		else
			-- connection failed
			_squeezenetworkError(self, squeezenetwork, "SN_DNS_WORKED")
		end
	end):addTask()
end


function _squeezenetworkError(self, squeezenetwork, message)
	local window = Window("help_list", self:string("CANT_CONNECT"))
	window:setAllowScreensaver(false)

	local menu = SimpleMenu("menu")
	menu:addItem({
		text = (self:string("SN_TRY_AGAIN")),
		sound = "WINDOWSHOW",
		callback = function()
			_squeezenetworkWait(self, squeezenetwork)
			window:hide()
		end,
		weight = 1
	})

	window:addWidget(menu)
	menu:setHeaderWidget(Textarea("help_text", self:string(message)))

	-- help shows diagnostics
	window:setButtonAction("rbutton", "help")
	window:addActionListener("help", self, function()
		Framework:playSound("WINDOWSHOW")
		appletManager:callService("supportMenu")
	end)
	jiveMain:addHelpMenuItem(menu, self,    function()
							appletManager:callService("supportMenu")
						end)


	window:addTimer(1000, function()
		-- wait until we know if the player is linked
		if _squeezenetworkConnected(self, squeezenetwork) then
			_firmwareUpgrade(self, squeezenetwork)
			window:hide()
		end
	end)

	self:tieAndShowWindow(window)
end


function _firmwareUpgrade(self, squeezenetwork)
	log:info("_firmwareUpgrade")
	if not squeezenetwork:isConnected() then
		log:info("get SC from one of discovered SCs")
		appletManager:callService("firmwareUpgrade", nil)
		return
	end

	local url, force = squeezenetwork:getUpgradeUrl()
	local pin = squeezenetwork:getPin()

	log:info("squeezenetwork pin=", pin, " url=", url)

	if force then
		log:info("firmware upgrade from SN")
		appletManager:callService("firmwareUpgrade", squeezenetwork)
	end
end


function _registerRequest(self, squeezenetwork)
	if self.registerRequest then
		return
	end

	--defer setting self.registerRequest until first register command completes to avoid race condition where serverLinked occurs early in a
	--  "register or continue" situation since the server in that case is already linked
	local successCallback = function(requireAlreadyLinked)
		self.registerRequest = true
		self.registerRequestRequireAlreadyLinked = requireAlreadyLinked
	end

	log:info("registration on SN")
	appletManager:callService("squeezeNetworkRequest", { 'register', 0, 100, 'service:SN' }, true, successCallback )

	self.locked = true -- don't free applet
	-- XXX: it could be that the NetworkRegistration applet needs a notify_playerCurrent() method to deal with the registration being successful; the subscribe right here hints at that...
	jnt:subscribe(self)
end


function _getSqueezenetwork(self)
	local squeezenetwork = false
	for name, server in slimServer:iterate() do
		if server:isSqueezeNetwork() then
			squeezenetwork = server
		end
	end
	return squeezenetwork
end


function _setupDone(self, setupDone, registerDone)
	log:info("network setup complete")

	local settings = self:getSettings()

	settings.setupDone = setupDone
	self:storeSettings()

	-- FIXME: workaround until filesystem write issue resolved
	os.execute("sync")
end


function free(self)
	appletManager:callService("setDateTimeDefaultFormats")
	return not self.locked
end

-- XXX: this needs to be a service method registered in the meta file
function waitForSqueezenetwork(self)
	local squeezenetwork = self:_getSqueezenetwork()
	_squeezenetworkWait(self, squeezenetwork)
end


function _getSqueezenetwork(self)
        local squeezenetwork = false
        for name, server in slimServer:iterate() do
                if server:isSqueezeNetwork() then
                        squeezenetwork = server
                end
        end
        return squeezenetwork
end

--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

