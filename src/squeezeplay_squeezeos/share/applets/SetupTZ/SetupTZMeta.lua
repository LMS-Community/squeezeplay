
local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local jiveMain      = jiveMain
local jnt           = jnt
local RequestHttp   = require("jive.net.RequestHttp")
local SocketHttp    = require("jive.net.SocketHttp")

module(...)
oo.class(_M, AppletMeta)

function jiveVersion(meta)
	return 1, 1
end

function registerApplet(meta)
	jiveMain:addItem(meta:menuItem('appletSetupTZ', 'advancedSettings', "TZ_TIMEZONE", function(applet, ...) applet:settingsShow(...) end))
	meta:registerService("setTimezone")
	meta:registerService("getTimezone")

	-- At register time, don't bother with all the subscription
	-- magic unless the TZ is unset
	local current_tz = appletManager:callService("getTimezone")
	if not current_tz or current_tz == "Factory" then
		jnt:subscribe(meta)
	end
end

function notify_serverConnected(meta)
	-- But the TZ could have been set by the user between then
	-- and now, so recheck again anyways, and unsubcribe if
	-- either it has become validly set somehow, or we manage
	-- to get a setting from SN
	local current_tz = appletManager:callService("getTimezone")
	if not current_tz or current_tz == "Factory" then
		local socket = SocketHttp(jnt, jnt:getSNHostname(), 80, "tzguess")
		local req = RequestHttp(
			function(data) if data then
				log:debug("Got http data for TZ >>" .. data .. "<<")
				if appletManager:callService("setTimezone", data) then
					jnt:unsubscribe(meta)
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

