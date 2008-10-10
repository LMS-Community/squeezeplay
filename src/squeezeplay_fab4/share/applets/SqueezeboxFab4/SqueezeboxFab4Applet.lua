
local print = print

-- board specific driver
local fab4_bsp               = require("fab4_bsp")

local oo                     = require("loop.simple")
local io                     = require("io")
local string                 = require("string")

local Framework              = require("jive.ui.Framework")

local debug                  = require("jive.utils.debug")
local log                    = require("jive.utils.log").logger("applets.setup")

local jnt                    = jnt


module(..., Framework.constants)
oo.class(_M, Applet)


function init(self)
	-- FIXME uuid
	local uuid = "00000000000000000000000000000000"

	-- read device mac
	local f = io.popen("/sbin/ifconfig eth0")
	if f then
	 	local ifconfig = f:read("*all")
		f:close()

		mac = string.match(ifconfig, "HWaddr%s(%x%x:%x%x:%x%x:%x%x:%x%x:%x%x)")
	end

	jnt:setUUID(uuid, mac)
end
