


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

module(..., Framework.constants)
oo.class(_M, Applet)


function settingsShow(self)
	local window = Window("information", self:string("ABOUT_JIVE"), 'settingstitle')

	local version = JIVE_VERSION

	local about = {
		tostring(self:string("ABOUT_VERSION")),
		version,
		"",
		tostring(self:string("ABOUT_CREDITS")),
		"     Sean Adams",
		"     Maurice Alou",
		"     Ena Bi",
		"     Dean Blackketter",
		"     Fred Bould",
		"     Randy Buswell",
		"     François Campart",
		"     Jim Carlton",
		"     Caleb Crome",
		"     Matt Cuson",
		"     Kevin Deane-Freeman",
		"     Julius Dauz",
		"     Ryan Davidson",
		"     Remco Derksen",
		"     Noah DiJulio",
		"     Mike Dilley",
		"     Brian Dils",
		"     Ben Dooks",
		"     Dan Evans",
		"     Sam Feng",
		"     Mike Fieger",
		"     Eric Fields",
		"     Lukas Frey",
		"     Mickey Gee",
		"     Andy Grundman",
		"     Michael Herger",
		"     Dane Johnson",
		"     Raphael Juchli",
		"     Ben Klaas",
		"     Wallace Lai",
		"     Diane Lee",
		"     Ross Levine",
		"     Angela Martin",
		"     Matthew Martin",
		"     Pamela McCracken",
		"     Anoop Mehta",
		"     Felix Mueller",
		"     Laura Nelson",
		"     Chris Owens",
		"     Matt Parry",
		"     Pat Ransil",
		"     Dylan Rhodes",
		"     James Richardson",
		"     Seth Schulte",
		"     Robin Selden",
		"     Martin Sénéclauze",
		"     Adrian Smith",
		"     Steven Spies",
		"     David Stein",
		"     Fred Thomas",
		"     Richard Titmuss",
		"     Michael Valera",
		"     Julien Venetz",
		"     Tom Wadzinski",
		"     LaRon Walker",
		"     Matt Weldon",
		"     Matt Wise",
		"     Osama Zaidan",
		"     Jose Arcellana",
		"     Brandon Black",
		"     Xavier Caine",
		"     Ryan Davidson",
		"     Philippe Depallens",
		"     Steve Dusse",
		"     Ariel Fischer",
		"     Kelly Fry",
		"     David Gilmore",
		"     Scott Harrington",
		"     Jon Howell",
		"     Hersh Jagpal",
		"     Ismail Kose",
		"     Geetha Kurup",
		"     Jonathan Lee",
		"     Zach Miller",
		"     Timothy Nguyen",
		"     Buen Ortiz",
		"     Moumita Palit",
		"     Jason Pastewski",
		"     Eric Raeber",
		"     Pushkar Singh",
		"     Dana Smith",
		"     Jey Somaskanthan",
		"     Eric Tissot-Dupont",
		"     Quy Tran",
		"     Vasudeva Upadhya",
		"     Celil Urgan",
		"     Bradley Wall",
		"     Joe Wang",
		"     Dudley Wong",
		"     Joel Yau",
		"     Alan Young",
		"     Patrick Yu",
		"     Bradley D. Wall",
		"     Kunal Duggal",
		"",
		"",
		tostring(self:string("ABOUT_COPYRIGHT")),
		"",
	}

	window:addWidget(Textarea("text", table.concat(about, "\n")))

	self:tieAndShowWindow(window)
	return window
end



--[[

=head1 LICENSE

Copyright 2010 Logitech.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
