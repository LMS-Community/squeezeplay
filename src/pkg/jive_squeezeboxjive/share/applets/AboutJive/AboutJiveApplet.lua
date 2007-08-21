


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



module(...)
oo.class(_M, Applet)


function settingsShow(self)
	local window = Window("window", self:string("ABOUT_JIVE"))

	local fh = io.open("/etc/jive.version", "r")
	local version = fh:read("*a")
	fh:close()

	local about = {
		tostring(self:string("ABOUT_VERSION")),
		version,
		"",
		tostring(self:string("ABOUT_CREDITS")),
		"     Dean Blackketter",
		"     Caleb Crome",
		"     Martin Seneclauze",
		"     Fred Thomas",
		"     Richard Titmuss",
		"     Ben Klaas",
		"     Adrian Smith",
		"     Raphael Juchli",
		"     Lukas Frey",
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
