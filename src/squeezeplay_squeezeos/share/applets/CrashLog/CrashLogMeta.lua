

local oo            = require("loop.simple")

local lfs           = require("lfs")
local string        = require("string")

local AppletMeta    = require("jive.AppletMeta")

local Timer         = require("jive.ui.Timer")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function registerApplet(meta)
	meta:registerService("crashLog")

	meta.prompts = {}

	meta.timer = Timer(1000 * 10, -- wait 10 seconds after boot
		function()
			local count = 0

			for file in lfs.dir("/root") do
				if string.match(file, "^crashlog%.") then
					count = count + 1

					local prompt = meta.prompts[file] or true
					meta.prompts[file] = false

					appletManager:callService("crashLog", "/root/" .. file, prompt)
				end
			end

			if count > 0 then
				-- check every ten minutes
				meta.timer:setInterval(1000 * 60 * 10)
			else
				-- check every hour minutes
				meta.timer:setInterval(1000 * 60 * 60)
			end
		end)
	meta.timer:start()
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

