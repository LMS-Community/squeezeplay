


-- stuff we use
local assert, getmetatable, ipairs, pcall, setmetatable, tonumber, tostring = assert, getmetatable, ipairs, pcall, setmetatable, tonumber, tostring

local oo                     = require("loop.simple")

local string                 = require("string")
local table                  = require("jive.utils.table")
local io                     = require("io")

local Applet                 = require("jive.Applet")
local Framework              = require("jive.ui.Framework")
local Label                  = require("jive.ui.Label")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Textarea               = require("jive.ui.Textarea")
local Window                 = require("jive.ui.Window")
local Popup                  = require("jive.ui.Popup")

local log                    = require("jive.utils.log").logger("applets.setup")

module(...)
oo.class(_M, Applet)


function settingsShow(self)
	local window = Window("window", self:string("ABOUT_JIVE"), 'settingstitle')

	local fh = io.open("/etc/jive.version", "r")
	local version = fh:read("*a")
	fh:close()

	local fh = io.popen("/sbin/ifconfig eth0")
	local ifconfig = fh:read("*a")
	fh:close()

	local hwaddr = string.match(ifconfig, "HWaddr%s+([%x:]+)")

	log:warn("ifconfig=", ifconfig)
	log:warn("hwaddr=", hwaddr)

	local about = {
		tostring(self:string("ABOUT_VERSION")),
		version,
		"",
		tostring(self:string("ABOUT_MAC_ADDRESS", hwaddr)),
		"",
		tostring(self:string("ABOUT_CREDITS")),
		"     Dean Blackketter",
		"     Fred Bould",
		"     Caleb Crome",
		"     Noah DiJulio",
		"     Ben Dooks",
		"     Lukas Frey",
		"     Andy Grundman",
		"     Raphael Juchli",
		"     Ben Klaas",
		"     Martin Sénéclauze",
		"     Adrian Smith",
		"     Fred Thomas",
		"     Richard Titmuss",
		"",
		"",
		tostring(self:string("ABOUT_COPYRIGHT")),
		tostring(self:string("ABOUT_ALL_RIGHTS_RESERVED")),
	}

	window:addWidget(Textarea("textarea", table.concat(about, "\n")))

	self:tieAndShowWindow(window)
	return window
end



--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
