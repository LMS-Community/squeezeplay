
-- stuff we use
local pairs = pairs

local oo                     = require("loop.simple")
local string                 = require("string")
local squeezeos              = require("squeezeos_bsp")

local Applet                 = require("jive.Applet")
local System                 = require("jive.System")
local RadioGroup             = require("jive.ui.RadioGroup")
local RadioButton            = require("jive.ui.RadioButton")
local Framework              = require("jive.ui.Framework")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Window                 = require("jive.ui.Window")

module(..., Framework.constants)
oo.class(_M, Applet)

-- A smaller 75-entry subset of the Olson DB that Andy found somewhere,
--  which is what SN has been using for timezone guessing.  These are
--  in a database in SN, and we might need to update this list if that
--  changes in the future (and re-verify that squeezeos's /usr/share/zoneinfo
--  contains files for any new entries).
-- Order is important here, these are ordered the same as the menu ordering
--  in the SN DB.
local timezones = {
	{ strid = "TZ_PACIFIC_APIA", olson = "Pacific/Apia" },
	{ strid = "TZ_PACIFIC_HONOLULU", olson = "Pacific/Honolulu" },
	{ strid = "TZ_PACIFIC_PITCAIRN", olson = "Pacific/Pitcairn" },
	{ strid = "TZ_AMERICA_ANCHORAGE", olson = "America/Anchorage" },
	{ strid = "TZ_AMERICA_LOS_ANGELES", olson = "America/Los_Angeles" },
	{ strid = "TZ_AMERICA_PHOENIX", olson = "America/Phoenix" },
	{ strid = "TZ_AMERICA_DENVER", olson = "America/Denver" },
	{ strid = "TZ_AMERICA_CHIHUAHUA", olson = "America/Chihuahua" },
	{ strid = "TZ_AMERICA_REGINA", olson = "America/Regina" },
	{ strid = "TZ_AMERICA_MEXICO_CITY", olson = "America/Mexico_City" },
	{ strid = "TZ_AMERICA_CHICAGO", olson = "America/Chicago" },
	{ strid = "TZ_AMERICA_INDIANAPOLIS", olson = "America/Indianapolis" },
	{ strid = "TZ_AMERICA_BOGOTA", olson = "America/Bogota" },
	{ strid = "TZ_AMERICA_NEW_YORK", olson = "America/New_York" },
	{ strid = "TZ_AMERICA_CARACAS", olson = "America/Caracas" },
	{ strid = "TZ_AMERICA_SANTIAGO", olson = "America/Santiago" },
	{ strid = "TZ_AMERICA_HALIFAX", olson = "America/Halifax" },
	{ strid = "TZ_AMERICA_ST_JOHNS", olson = "America/St_Johns" },
	{ strid = "TZ_AMERICA_BUENOS_AIRES", olson = "America/Buenos_Aires" },
	{ strid = "TZ_AMERICA_GODTHAB", olson = "America/Godthab" },
	{ strid = "TZ_AMERICA_SAO_PAULO", olson = "America/Sao_Paulo" },
	{ strid = "TZ_AMERICA_NORONHA", olson = "America/Noronha" },
	{ strid = "TZ_ATLANTIC_CAPE_VERDE", olson = "Atlantic/Cape_Verde" },
	{ strid = "TZ_ATLANTIC_AZORES", olson = "Atlantic/Azores" },
	{ strid = "TZ_AFRICA_CASABLANCA", olson = "Africa/Casablanca" },
	{ strid = "TZ_EUROPE_LONDON", olson = "Europe/London" },
	{ strid = "TZ_AFRICA_LAGOS", olson = "Africa/Lagos" },
	{ strid = "TZ_EUROPE_BERLIN", olson = "Europe/Berlin" },
	{ strid = "TZ_EUROPE_PARIS", olson = "Europe/Paris" },
	{ strid = "TZ_EUROPE_SARAJEVO", olson = "Europe/Sarajevo" },
	{ strid = "TZ_EUROPE_BELGRADE", olson = "Europe/Belgrade" },
	{ strid = "TZ_AFRICA_JOHANNESBURG", olson = "Africa/Johannesburg" },
	{ strid = "TZ_ASIA_JERUSALEM", olson = "Asia/Jerusalem" },
	{ strid = "TZ_EUROPE_ISTANBUL", olson = "Europe/Istanbul" },
	{ strid = "TZ_EUROPE_HELSINKI", olson = "Europe/Helsinki" },
	{ strid = "TZ_AFRICA_CAIRO", olson = "Africa/Cairo" },
	{ strid = "TZ_EUROPE_BUCHAREST", olson = "Europe/Bucharest" },
	{ strid = "TZ_AFRICA_NAIROBI", olson = "Africa/Nairobi" },
	{ strid = "TZ_ASIA_RIYADH", olson = "Asia/Riyadh" },
	{ strid = "TZ_EUROPE_MOSCOW", olson = "Europe/Moscow" },
	{ strid = "TZ_ASIA_BAGHDAD", olson = "Asia/Baghdad" },
	{ strid = "TZ_ASIA_TEHRAN", olson = "Asia/Tehran" },
	{ strid = "TZ_ASIA_MUSCAT", olson = "Asia/Muscat" },
	{ strid = "TZ_ASIA_TBILISI", olson = "Asia/Tbilisi" },
	{ strid = "TZ_ASIA_KABUL", olson = "Asia/Kabul" },
	{ strid = "TZ_ASIA_KARACHI", olson = "Asia/Karachi" },
	{ strid = "TZ_ASIA_YEKATERINBURG", olson = "Asia/Yekaterinburg" },
	{ strid = "TZ_ASIA_CALCUTTA", olson = "Asia/Calcutta" },
	{ strid = "TZ_ASIA_KATMANDU", olson = "Asia/Katmandu" },
	{ strid = "TZ_ASIA_COLOMBO", olson = "Asia/Colombo" },
	{ strid = "TZ_ASIA_DHAKA", olson = "Asia/Dhaka" },
	{ strid = "TZ_ASIA_NOVOSIBIRSK", olson = "Asia/Novosibirsk" },
	{ strid = "TZ_ASIA_RANGOON", olson = "Asia/Rangoon" },
	{ strid = "TZ_ASIA_BANGKOK", olson = "Asia/Bangkok" },
	{ strid = "TZ_ASIA_KRASNOYARSK", olson = "Asia/Krasnoyarsk" },
	{ strid = "TZ_AUSTRALIA_PERTH", olson = "Australia/Perth" },
	{ strid = "TZ_ASIA_TAIPEI", olson = "Asia/Taipei" },
	{ strid = "TZ_ASIA_SINGAPORE", olson = "Asia/Singapore" },
	{ strid = "TZ_ASIA_HONG_KONG", olson = "Asia/Hong_Kong" },
	{ strid = "TZ_ASIA_IRKUTSK", olson = "Asia/Irkutsk" },
	{ strid = "TZ_ASIA_TOKYO", olson = "Asia/Tokyo" },
	{ strid = "TZ_ASIA_SEOUL", olson = "Asia/Seoul" },
	{ strid = "TZ_ASIA_YAKUTSK", olson = "Asia/Yakutsk" },
	{ strid = "TZ_AUSTRALIA_DARWIN", olson = "Australia/Darwin" },
	{ strid = "TZ_AUSTRALIA_ADELAIDE", olson = "Australia/Adelaide" },
	{ strid = "TZ_PACIFIC_GUAM", olson = "Pacific/Guam" },
	{ strid = "TZ_AUSTRALIA_BRISBANE", olson = "Australia/Brisbane" },
	{ strid = "TZ_ASIA_VLADIVOSTOK", olson = "Asia/Vladivostok" },
	{ strid = "TZ_AUSTRALIA_HOBART", olson = "Australia/Hobart" },
	{ strid = "TZ_AUSTRALIA_SYDNEY", olson = "Australia/Sydney" },
	{ strid = "TZ_ASIA_MAGADAN", olson = "Asia/Magadan" },
	{ strid = "TZ_PACIFIC_NORFOLK", olson = "Pacific/Norfolk" },
	{ strid = "TZ_PACIFIC_FIJI", olson = "Pacific/Fiji" },
	{ strid = "TZ_PACIFIC_AUCKLAND", olson = "Pacific/Auckland" },
	{ strid = "TZ_PACIFIC_TONGATAPU", olson = "Pacific/Tongatapu" },
}

function settingsShow(self, menuItem)
	local current_tz = squeezeos.getTimezone()
	local radio_group = RadioGroup()
	local menu_list = {}
	local tz_selected_index

	for k,tzdata in pairs(timezones) do
		local enableme = false
		if tzdata.olson == current_tz then
			tz_selected_index = k
			enableme = true
		end
		menu_list[k] = {
			text = self:string(tzdata.strid),
			style = "item_choice",
			check = RadioButton(
				"radio",
				radio_group,
				function()
					local success,err = squeezeos.setTimezone(tzdata.olson)
					if not success then
						log:warn("setTimezone() failed: ", err)
					end
				end,
				enableme
			)
		}
	end


	self.window = Window("help_list", menuItem.text, "text")
	self.menu = SimpleMenu("menu", menu_list)

	if tz_selected_index then self.menu:setSelectedIndex(tz_selected_index) end

	self.window:addWidget(self.menu)
	self:tieAndShowWindow(self.window)
	return self.window
end

--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
