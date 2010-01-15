
local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local jiveMain      = jiveMain
local jnt           = jnt
local squeezeos     = require("squeezeos_bsp")
local RequestHttp   = require("jive.net.RequestHttp")
local SocketHttp    = require("jive.net.SocketHttp")

module(...)
oo.class(_M, AppletMeta)

function jiveVersion(meta)
	return 1, 1
end

function registerApplet(meta)
	jiveMain:addItem(meta:menuItem('appletSetupTZ', 'advancedSettings', "TZ_TIMEZONE", function(applet, ...) applet:settingsShow(...) end))

	-- At register time, subscribe to network events
	-- if the timezone hasn't been set
	if not squeezeos.getTimezone() then
		jnt:subscribe(meta)
	end
end

function notify_serverConnected(meta)
	-- On server connect, if the timezone still hasn't
	-- been set, set it from SN's guess over http
	-- and unsubscribe if this succeeds
	if not squeezeos.getTimezone() then
		local socket = SocketHttp(jnt, jnt:getSNHostname(), 80, "tzguess")
		local req = RequestHttp(
			function(data) if data then
				log:debug("Got http data for TZ >>" .. data .. "<<")
				local success,err = squeezeos.setTimezone(data)
				if success then
					jnt:unsubscribe(meta)
				else
					log:warn("setTimezone() failed: ", err)
				end
			end end,
			'GET', '/public/tz'
		)
		socket:fetch(req)
	else
		jnt:unsubscribe(meta)
	end
end

--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

