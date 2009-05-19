
local ipairs, tostring = ipairs, tostring

-- stuff we use
local oo               = require("loop.simple")

local io               = require("io")
local lfs              = require("lfs")
local ltn12            = require("ltn12")
local os               = require("os")
local string           = require("string")

local Applet           = require("jive.Applet")
local System           = require("jive.System")
local SocketHttp       = require("jive.net.SocketHttp")
local RequestHttp      = require("jive.net.RequestHttp")
local Framework        = require("jive.ui.Framework")
local Label            = require("jive.ui.Label")
local SimpleMenu       = require("jive.ui.SimpleMenu")
local Surface          = require("jive.ui.Surface")
local Task             = require("jive.ui.Task")
local Textarea         = require("jive.ui.Textarea")
local Window           = require("jive.ui.Window")

local debug            = require("jive.utils.debug")
local log              = require("jive.utils.log").logger("applets.misc")
local jsonfilters      = require("jive.utils.jsonfilters")

local jnt = jnt
local JIVE_VERSION  = jive.JIVE_VERSION


module(..., Framework.constants)
oo.class(_M, Applet)


function crashLog(self, file, prompt)
	log:info("sending crash log: ", file)

	if prompt then
		self:crashLogPrompt(file)
	end
	self:crashLogSend(file)
end


function crashLogPrompt(self, file)
	local window = Window("help_list", self:string("CRASH_TITLE"))

	window:setAllowScreensaver(false)
	window:setAlwaysOnTop(true)
	window:setAutoHide(false)
	window:setButtonAction("rbutton", nil)

	local text = Textarea("help_text", self:string("CRASH_TEXT"))
	local menu = SimpleMenu("menu", {
		{
			text = self:string("CRASH_CONTINUE"),
			sound = "WINDOWHIDE",
			callback = function()
					   window:hide(Window.transitionPushLeft)
				   end
		},
	})

	window:addWidget(text)
	window:addWidget(menu)
	window:show(Window.transitionNone)
end


function crashLogSend(self, file)
	local data = {}

	data.mac = System:getMacAddress()
	data.uuid = System:getUUID()
	data.machine = System:getMachine()
	data.version = JIVE_VERSION
	data.logfile = file

	fh = io.open(file, "r")
	data.log = fh:read("*a")
	fh:close()

	local sent = false
	local source = ltn12.source.chain(
		function()
			if sent then
				return nil
			else
				sent = true
				return data
			end
		end, 
		jsonfilters.encode
	)

	local sink = function(data, err)
		if err then
			log:warn("crash log upload failed ", err)
			return
		end

		if not data then
			log:info("crash log upload done: ", file)
			os.remove(file)
		end
	end

	local url = "http://" .. jnt:getSNHostname() .. "/crashlog"

	-- send crash log
	local post = RequestHttp(sink, "POST", url, {
		t_bodySource = source
	})

        local uri  = post:getURI()
        local http = SocketHttp(jnt, uri.host, uri.port, uri.host)

        http:fetch(post)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
