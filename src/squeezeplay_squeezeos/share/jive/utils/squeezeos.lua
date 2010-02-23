-----------------------------------------------------------------------------
-- squeezeos.lua
-----------------------------------------------------------------------------

--[[
=head1 NAME

jive.util.squeezeos - some squeezeos specific system utilities

=head1 DESCRIPTION

Assorted utility functions for system process handling etc.

=cut
--]]

local os        = require("os")
local io        = require("io")
local string    = require("string")
local squeezeos = require("squeezeos_bsp")


module(...)


function processRunning(self, process)
	local pid = self:pidfor(process)

	if (pid ~= nil) then
		return true
	end
	
	return false
end


function pidfor(self, process)
	local pidfile = "/var/run/" .. process .. ".pid"
	local pid     = self:_readPidFile(pidfile)

	if pid and squeezeos.kill(pid, 0) == 0 then
		return pid, pidfile
	end
	
	local cmd = io.popen("/bin/ps -o pid,command")

	if not cmd then
		return nil
	end

	local pattern = "%s*(%d+).*" .. process .. "$"

	for line in cmd:lines() do
		pid = string.match(line, pattern)
		if pid then break end
	end
	cmd:close()

	return pid
end


function kill(self, process)
	local pid, pidfile = self:pidfor(process)
	
	if pid then
		squeezeos.kill(pid, 15)
	end
	
	if pidfile then
		os.remove(pidfile)
	end
end

function killByPidFile(self, file)
	local pid = self:_readPidFile(file)

	if pid then
		squeezeos.kill(pid, 15)
	end
	os.remove(file)
end


function _readPidFile(self, file)
	local fh = io.open(file, "r")

	if fh == nil then
		return
	end

	local pid = fh:read("*all")
	fh:close()
	
	return pid
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

