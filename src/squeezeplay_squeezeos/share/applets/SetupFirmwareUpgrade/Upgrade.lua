
local oo          = require("loop.base")
local io          = require("io")
local string      = require("string")

local Task        = require("jive.ui.Task")

local UpgradeMTD  = require("applets.SetupFirmwareUpgrade.UpgradeMTD")
local UpgradeUBI  = require("applets.SetupFirmwareUpgrade.UpgradeUBI")

local debug       = require("jive.utils.debug")
local log         = require("jive.utils.log").logger("applet.SetupFirmware")


module(..., oo.class)


function __init(self)
	return oo.rawnew(self, {})
end


-- perform the upgrade
function start(self, url, callback)
	if not callback then
		callback = function() end
	end

	callback(false, "UPDATE_DOWNLOAD", "")

	-- parse the flash devices
	local mtd, err = self:parseMtd()
	if not mtd then
		log:error("parseMtd failed")
		return nil, err
	end

	Task:yield(true)

	local class
	if mtd.ubi then
		class = UpgradeUBI
	else
    		class = UpgradeMTD
	end

	local obj = (class)()
	return obj:start(url, mtd, callback)
end


-- utility function to parse /dev/mtd
function parseMtd()
	local mtd = {}

	-- parse mtd to work out what partitions to use
	local fh, err = io.open("/proc/mtd")
	if fh == nil then
		return fh, err
	end

	for line in fh:lines() do
		local partno, name = string.match(line, "mtd(%d+):.*\"([^\"]+)\"")
		if partno then
			mtd[name] = "/dev/mtd/" .. partno
		end
	end

	fh:close()

	return mtd
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
