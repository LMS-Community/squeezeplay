


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
		"     Adrian Smith",
		"     Alan Young",
		"     Andy Grundman",
		"     Angela Martin",
		"     Anoop Mehta",
		"     Ariel Fischer",
		"     Ben Dooks",
		"     Ben Klaas",
		"     Bradley Wall",
		"     Brandon Black",
		"     Brian Dils",
		"     Buen Ortiz",
		"     Caleb Crome",
		"     Celil Urgan",
		"     Chris Owens",
		"     Dan Evans",
		"     Dana Smith",
		"     Dane Johnson",
		"     David Gilmore",
		"     David Stein",
		"     Dean Blackketter",
		"     Diane Lee",
		"     Dudley Wong",
		"     Dylan Rhodes",
		"     Ena Bi",
		"     Eric Fields",
		"     Eric Raeber",
		"     Eric Tissot-Dupont",
		"     Felix Mueller",
		"     François Campart",
		"     Fred Bould",
		"     Fred Thomas",
		"     Geetha Kurup",
		"     Hersh Jagpal",
		"     Ismail Hakki Kose",
		"     James Richardson",
		"     Jason Pastewski",
		"     Jey Somaskanthan",
		"     Jim Carlton",
		"     Joe Wang",
		"     Joel Yau",
		"     Jon Howell",
		"     Jonathan Lee",
		"     Jose Arcellana",
		"     Julien Venetz",
		"     Julius Dauz",
		"     Kelly Fry",
		"     Kevin Deane-Freeman",
		"     Kunal Duggal",
		"     LaRon Walker",
		"     Laura Nelson",
		"     Lukas Frey",
		"     Martin Sénéclauze",
		"     Matt Cuson",
		"     Matt Parry",
		"     Matt Weldon",
		"     Matt Wise",
		"     Matthew Martin",
		"     Maurice Alou",
		"     Michael Herger",
		"     Michael Valera",
		"     Mickey Gee",
		"     Mike Dilley",
		"     Mike Fieger",
		"     Moumita Palit",
		"     Noah DiJulio",
		"     Osama Zaidan",
		"     Pamela McCracken",
		"     Pat Ransil",
		"     Patrick Yu",
		"     Philippe Depallens",
		"     Pushkar Singh",
		"     Quy Tran",
		"     Randy Buswell",
		"     Raphael Juchli",
		"     Remco Derksen",
		"     Richard Titmuss",
		"     Robin Selden",
		"     Ross Levine",
		"     Ryan Davidson",
		"     Sam Feng",
		"     Scott Harrington",
		"     Sean Adams",
		"     Seth Schulte",
		"     Steve Dusse",
		"     Steven Spies",
		"     Timothy Nguyen",
		"     Tom Wadzinski",
		"     Vasudeva Upadhya",
		"     Wallace Lai",
		"     Xavier Caine",
		"     Zach Miller",
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
