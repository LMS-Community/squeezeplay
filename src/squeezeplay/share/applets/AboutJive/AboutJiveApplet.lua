


-- stuff we use
local assert, getmetatable, ipairs, pcall, setmetatable, tonumber, tostring = assert, getmetatable, ipairs, pcall, setmetatable, tonumber, tostring

local oo                     = require("loop.simple")

local string                 = require("string")
local table                  = require("jive.utils.table")
local io                     = require("io")

local Applet                 = require("jive.Applet")
local System                 = require("jive.System")
local Framework              = require("jive.ui.Framework")
local Label                  = require("jive.ui.Label")
local Textarea               = require("jive.ui.Textarea")
local Window                 = require("jive.ui.Window")
local Popup                  = require("jive.ui.Popup")
local jnt                    = jnt

local JIVE_VERSION           = jive.JIVE_VERSION

local debug                  = require("jive.utils.debug")
local log                    = require("jive.utils.log").logger("applets.setup")

module(...)
oo.class(_M, Applet)


function settingsShow(self)
	local window = Window("information", self:string("ABOUT_JIVE"), 'settingstitle')

	local version = JIVE_VERSION

	local uptime = System:getUptime()

	local ut = {}
	if uptime.days > 0 then
		ut[#ut + 1] = tostring(self:string("UPTIME_DAYS", uptime.days))
	end
	if uptime.hours > 0 then
		ut[#ut + 1] = tostring(self:string("UPTIME_HOURS", uptime.hours))
	end
	ut[#ut + 1] = tostring(self:string("UPTIME_MINUTES", uptime.minutes))
	ut = table.concat(ut, " ")

	local about = {
		tostring(self:string("ABOUT_VERSION")),
		version,
		"",
		tostring(self:string("ABOUT_MAC_ADDRESS", System:getMacAddress()) or ""),
		"",
		tostring(self:string("UPTIME")),
		ut,
		"",
		tostring(self:string("ABOUT_CREDITS")),
		"     Sean Adams",
		"     Maurice Alou",
		"     Ena Bi",
		"     Dean Blackketter",
		"     Fred Bould",
		"     Randy Buswell",
		"     Jim Carlton",
		"     Caleb Crome",
		"     Kevin Deane-Freeman",
		"     Julius Dauz",
		"     Noah DiJulio",
		"     Mike Dilley",
		"     Brian Dils",
		"     Ben Dooks",
		"     Dan Evans",
		"     Sam Feng",
		"     Mike Fieger",
		"     Lukas Frey",
		"     Mickey Gee",
		"     Andy Grundman",
		"     Michael Herger",
		"     Raphael Juchli",
		"     Ben Klaas",
		"     Wallace Lai",
		"     Diane Lee",
		"     Ross Levine",
		"     Angela Martin",
		"     Matthew Martin",
		"     Anoop Mehta",
		"     Felix Mueller",
		"     Chris Owens",
		"     James Richardson",
		"     Seth Schulte",
		"     Robin Selden",
		"     Martin Sénéclauze",
		"     Adrian Smith",
		"     Steven Spies",
		"     David Stein",
		"     Fred Thomas",
		"     Richard Titmuss",
		"     Julien Venetz",
		"     Tom Wadzinski",
		"     Matt Weldon",
		"     Matt Wise",
		"     Osama Zaidan",
		"",
		"",
		tostring(self:string("ABOUT_COPYRIGHT")),
	}

	window:addWidget(Textarea("text", table.concat(about, "\n")))

	self:tieAndShowWindow(window)
	return window
end



--[[

=head1 LICENSE

Copyright 2007 Logitech.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENSE file for details.

=cut
--]]
