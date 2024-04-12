
local ipairs, pairs, tostring = ipairs, pairs, tostring

-- stuff we use
local oo               = require("loop.simple")

local io               = require("io")
local lfs              = require("lfs")
local ltn12            = require("ltn12")
local os               = require("os")
local math             = require("math")
local string           = require("string")
local table            = require("jive.utils.table")

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
local jsonfilters      = require("jive.utils.jsonfilters")

local jnt = jnt
local JIVE_VERSION  = jive.JIVE_VERSION


module(..., Framework.constants)
oo.class(_M, Applet)

local logs = {}


function crashLog(self, file, prompt)
	local settings = self:getSettings()

	log:info("sending crash log: ", file, " sendLog=", settings.sendLog)

	logs[file] = true

	if self.prompt then
		-- prompt already open
	elseif settings.sendLog == nil then
		-- prompt if we should send logs
		self:crashLogPrompt(file)
	else
		_processLogs(self)
	end
end


function crashLogPrompt(self, file)
	local settings = self:getSettings()

	self.prompt = true

	local window = Window("help_list", self:string("CRASH_TITLE"))

	window:setAllowScreensaver(false)
	window:setAlwaysOnTop(true)
	window:setAutoHide(false)
	window:setButtonAction("rbutton", nil)

	local text = Textarea("help_text", self:string("CRASH_TEXT_QUESTION"))
	local menu = SimpleMenu("menu", {
--[[
		{
			text = self:string("CRASH_YES_SEND"),
			sound = "WINDOWHIDE",
			callback = function()
				settings.sendLog = true
				self:storeSettings()

				window:hide(Window.transitionPushLeft)

				self.prompt = false
				_processLogs(self)
			end
		},
--]]
		{
			text = self:string("CRASH_NO_NEVER_SEND"),
			sound = "WINDOWHIDE",
			callback = function()
				settings.sendLog = false
				self:storeSettings()

				window:hide(Window.transitionPushLeft)

				self.prompt = false
				_processLogs(self)
			end
		},
	})

	menu:setHeaderWidget(text)
	window:addWidget(menu)
	window:show(Window.transitionNone)
end


function _processLogs(self)
	local settings = self:getSettings()

	for file,queued in pairs(logs) do
		if settings.sendLog == true then
			if queued then
				_crashLogSend(self, file)
			end
		else
			_crashLogDontSend(self, file)
		end
	end
end


function _doneLog(self, file, success)
	logs[file] = nil
	if success then
		os.remove(file)
	end
end


function _crashLogSend(self, file)
	local data = {}

	logs[file] = false

	data.mac = System:getMacAddress()
	data.uuid = System:getUUID()
	data.machine = System:getMachine()
	data.version = JIVE_VERSION
	data.logfile = file
	data.reqid = string.format("%08x", Framework:getTicks())

	fh = io.open(file, "r")
	if not fh then
		_doneLog(self, file, true)
	end

	data.log = fh:read("*a")
	fh:close()


	-- parse log
	data.uptime = string.match(data.log, "up ([^/n]+), load average:")

	local patterns = {
		"SIGSEGV",
		"oom-killer",
		"(semaphore) %d+(:%d was not changed)",
		"Audio thread exited",
		"No such process",
	}

	for i,pattern in ipairs(patterns) do
		local match = { string.match(data.log, pattern) }
		if match[1] then
			data.failure = table.concat(match, " ")
			break
		end
	end

	-- upload
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
			return _doneLog(self, file, false)
		end

		if not data then
			log:info("crash log upload done: ", file)
			return _doneLog(self, file, true)
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


function _crashLogDontSend(self, file)
	log:info("crash log not sending: ", file)
	_doneLog(self, file, true)
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
