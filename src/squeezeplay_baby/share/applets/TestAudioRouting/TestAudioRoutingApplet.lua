local assert, ipairs = assert, ipairs

-- stuff we use
local oo                     = require("loop.simple")
local io                     = require("io")
local os                     = require("os")
local string	             = require("jive.utils.string")

local Applet                 = require("jive.Applet")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local Checkbox               = require("jive.ui.Checkbox")
local Popup                  = require("jive.ui.Popup")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Textarea               = require("jive.ui.Textarea")
local Timer                  = require("jive.ui.Timer")
local Window                 = require("jive.ui.Window")
local Surface                = require("jive.ui.Surface")
local Framework              = require("jive.ui.Framework")

local decode                 = require("squeezeplay.decode")


module(..., Framework.constants)
oo.class(_M, Applet)


local _headphoneSenseTokens = {
	["0"] = "AUDIO_ROUTING_NO",
	["1"] = "AUDIO_ROUTING_YES",
	["3"] = "HEADPHONE_STATE_WITH_MIC",
}


function audioRoutingMenu(self)
	local window = Window("text_list", self:string("TEST_AUDIO_ROUTING"))

	local menu = SimpleMenu("menu")

	menu:addItem({
				text = self:string("ENABLE_LINE_IN_PASSTHROUGH"), 
				style = 'item_choice',
				check = Checkbox(
					"checkbox",
					function(object, isSelected)
						log:info("checkbox updated: ", isSelected)
						self:_setPassThroughState(isSelected )
					end,
					self:_getPassThroughState()
				)
			})

	self.lineInSenseLabel = Label("choice")
	menu:addItem({
			text = self:string("LINE_IN_SENSE"),
			check = self.lineInSenseLabel,
			style = 'item_choice',
		})

	self.headphoneSenseLabel = Label("choice", "")
	menu:addItem({
			text = self:string("HEADPHONE_SENSE"),
			check = self.headphoneSenseLabel,
			style = 'item_choice',
		})

	window:addWidget(menu)

	self:_reportSenseValues()
	menu:addTimer(1000, function()
		self:_reportSenseValues()
	end)

	self:tieAndShowWindow(window)
	return window
end


function _reportSenseValues(self)
	self.lineInSenseLabel:setValue(self:_getLineInSenseState())
	self.headphoneSenseLabel:setValue(self:_getHeadphoneSenseState())
end


function _getLineInSenseState(self)
	local result = self:_getAmixerValue("Line In Switch")
	if result:sub(1,2) == "on" then
		return self:string("AUDIO_ROUTING_YES")
	else
		return self:string("AUDIO_ROUTING_NO")
	end
end

function _getHeadphoneSenseState(self)
	local result = self:_getAmixerValue("Headphone Switch")
	local state = result:sub(1,1)

--	Headphone type detection does not work at the moment
--	return self:string(_headphoneSenseTokens[state])

	if state == "0" then
                return self:string("AUDIO_ROUTING_NO")
	else
                return self:string("AUDIO_ROUTING_YES")
	end
end

function _getPassThroughState(self)
	local result = self:_getAmixerValue("Line In Test")
	return result and result:sub(1,2) == "on"
end


function _getAmixerValue(self, name)
	local fh = assert(io.popen("amixer cget name=\"" .. name .."\"  | grep : | sed 's/^.*=\\([^,]*\\).*$/\\1/'"))
	local line = fh:read("*a")
	fh:close()

	return line
end


function _setPassThroughState(self, on)
	local state = "off"
	if on then
		state = "on"
	end
	os.execute("amixer cset name=\"Line In Test\" " .. state)
end

--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
