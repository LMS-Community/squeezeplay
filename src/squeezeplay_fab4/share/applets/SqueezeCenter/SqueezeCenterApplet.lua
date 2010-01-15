
-- stuff we use
local oo                     = require("loop.simple")
local io                     = require("io")
local os                     = require("os")
local string                 = require("string")

local Applet                 = require("jive.Applet")
local Framework              = require("jive.ui.Framework")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local Popup                  = require("jive.ui.Popup")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Textarea               = require("jive.ui.Textarea")
local Timer                  = require("jive.ui.Timer")
local Window                 = require("jive.ui.Window")

local appletManager          = appletManager


module(..., Framework.constants)
oo.class(_M, Applet)


function settingsShow(self, menuItem)
	local window = Window("text_list", menuItem.text, 'settingstitle')
	
	local statusText = self:string(_getStatus())
	self.status = Textarea("help_text", statusText)
	

	local menu = SimpleMenu("menu", {
					{
						text = self:string("START"),
						sound = "WINDOWSHOW",
						callback = function()
								   self:_action("icon_connecting", "STARTING_SQUEEZECENTER", "STARTING_SQUEEZECENTER_TEXT", 5000, "start")
							   end
					},
					{
						text = self:string("STOP"),
						sound = "WINDOWSHOW",
						callback = function()
								   self:_action("icon_connecting", "STOPPING_SQUEEZECENTER", nil, 2000, "stop")
							   end
					},
					{
						text = self:string("STOP_RESCAN_START"),
						sound = "WINDOWSHOW",
						callback = function()
								   self:_action("icon_connected", "RESCAN_SQUEEZECENTER", "RESCAN_SQUEEZECENTER_TEXT", 10000, "rescan")
							   end
					},
				})

	menu:setHeaderWidget(self.status)
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	
	window:addTimer(5000, function() _updateStatus(self) end)
	
	return window
end

function _action(self, icon, text, subtext, time, action)

	-- Check validity of action
	if (action == 'start' and (_pidfor('slimserver.pl') or _pidfor('scanner.pl'))
		or action == 'stop' and not _pidfor('slimserver.pl')
		or action == 'rescan' and _pidfor('scanner.pl'))
	then
		return EVENT_UNUSED
	end

	local popup = Popup("waiting_popup")
	popup:addWidget(Icon(icon))
	popup:addWidget(Label("text", self:string(text)))
	
	if (subtext ~= nil) then popup:addWidget(Textarea("subtext", self:string(subtext))) end
	
	popup:showBriefly(time,
		function()
			_updateStatus(self)
		end,
		Window.transitionPushPopupUp,
		Window.transitionPushPopupDown
	)

	os.execute("/etc/init.d/squeezecenter " .. action);

end

function _updateStatus(self)
	local statusText = self:string(_getStatus())
	self.status:setValue(statusText)
end

function _getStatus()
	
	local sc = _pidfor('slimserver.pl')
	local scanner = _pidfor('scanner.pl')
	
	if (sc ~= nil) then return "STATUS_SQUEEZECENTER_RUNNING" end
	if (scanner ~= nil) then return "STATUS_SCANNER_RUNNING" end
	
	return "STATUS_NOTHING"

end

function _pidfor(process)
	local pid

	local pattern = "%s*(%d+).*" .. process

	log:warn("pattern is ", pattern)

	local cmd = io.popen("/bin/ps -o pid,command")
	for line in cmd:lines() do
		pid = string.match(line, pattern)
		if pid then break end
	end
	cmd:close()

	return pid
end

--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
