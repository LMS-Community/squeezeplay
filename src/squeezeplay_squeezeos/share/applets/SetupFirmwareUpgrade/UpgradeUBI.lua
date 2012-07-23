

local assert, error, pairs, pcall, tonumber, type = assert, error, pairs, pcall, tonumber, type

local oo          = require("loop.base")
local io          = require("io")
local os          = require("os")
local math        = require("math")
local table       = require("jive.utils.table")
local zip         = require("zipfilter")
local ltn12       = require("ltn12")
local string      = require("string")
local url         = require("socket.url")
local md5         = require("md5")

local RequestHttp = require("jive.net.RequestHttp")
local SocketHttp  = require("jive.net.SocketHttp")
local Process     = require("jive.net.Process")
local Framework   = require("jive.ui.Framework")
local Task        = require("jive.ui.Task")

local debug       = require("jive.utils.debug")
local log         = require("jive.utils.log").logger("applet.SetupFirmware")

local jnt = jnt
local appletManager = appletManager

module(..., oo.class)


function _percent(x, y)
	return math.min(100, math.floor((x/y) * 100))
end

function __init(self)
	local obj = oo.rawnew(self, {
		_mtd = mtd,
		_file = {},
		_size = {},
		_checksum = "",
		_boardVersion = "",
	})

	return obj
end


-- perform the upgrade
function start(self, url, mtd, callback)
	self._url = url
	self._mtd = mtd
	self._callback = callback

	return Task:pcall(_upgrade, self)
end


function _upgrade(self)

	self._callback(false, "UPDATE_DOWNLOAD", "")

	-- parse the board revision
	t, err = self:parseCpuInfo()
	if not t then
		log:warn("parseCpuInfo failed")
		return nil, err
	end

	-- parse the current root volume
	t, err = self:parseCmdLine()
	if not t then
		log:warn("parseCmdLine failed")
		return nil, err
	end 

	if self._backup then
		log:info("upgrading main image")

		-- this path means that the system now won't boot normally,
		-- however this is unavoidable without storing a third image
		-- on flash
		self:rmvol("kernel")
		self:rmvol("cramfs")
	else
		-- remove old image
		self:rmvol("kernel_bak")
		self:rmvol("cramfs_bak")
	end

	-- remove any failed upgrades
	self:rmvol("kernel_upg")
	self:rmvol("cramfs_upg")

	-- wait for udev
	self:udevtrigger()

	-- write new volume contents
	self:download()

	self._callback(false, "UPDATE_VERIFY")

	-- check the correct ubi volumes exist
	local oldvol = self:parseUbi()
	assert(oldvol.kernel_upg)
	assert(oldvol.cramfs_upg)


	-- verify new volumes
	self:parseMtd()
	self.verifyBytes = 0
	self.verifySize = self._size["kernel_upg"] + self._size["cramfs_upg"]
	self:checksum("kernel_upg")
	self:checksum("cramfs_upg")

	-- automically rename volumes
	if self._backup then
		self:renamevol({
			["kernel_upg"] = "kernel",
			["cramfs_upg"] = "cramfs",
		})
	else
		self:renamevol({
			["kernel"] = "kernel_bak",
			["kernel_upg"] = "kernel",
			["cramfs"] = "cramfs_bak",
			["cramfs_upg"] = "cramfs",
		})
	end

	-- check the volume rename worked
	local newvol = self:parseUbi()
	assert(newvol.kernel)
	assert(newvol.cramfs)
	if self._backup then
		assert(newvol.kernel ~= oldvol.kernel_bak)
		assert(newvol.cramfs ~= oldvol.cramfs_bak)
	else
		assert(newvol.kernel ~= oldvol.kernel)
		assert(newvol.cramfs ~= oldvol.cramfs)
	end

	-- reboot
	self._callback(true, "UPDATE_REBOOT")

	-- two second delay
	local t = Framework:getTicks()
	while (t + 2000) > Framework:getTicks() do
		Task:yield(true)
	end

	appletManager:callService("reboot")

	return true
end


-- utility function to parse /proc/cmdline
function parseCmdLine(self)
	local fh, err = io.open("/proc/cmdline")
	if fh == nil then
		return fh, err
	end

	local t = fh:read("*all")
	fh:close()

	local rootfs = string.lower(string.match(t, "root.+:([%w_]+)"))
	self._backup = (rootfs == "cramfs_bak")

	return true
end


-- utility function to parse /dev/cpuinfo
function parseCpuInfo(self)
	local fh, err = io.open("/proc/cpuinfo")
	if fh == nil then
		return fh, err
	end

	while true do
		local line = fh:read()
		if line == nil then
			break
		end

		if string.match(line, "Hardware") then
			self._platform = string.lower(string.match(line, ".+:%s+(.+)"))
		elseif string.match(line, "Revision") then
			self._revision = tonumber(string.match(line, ".+:%s+(.+)"))
		end

	end
	fh:close()

	return 1
end


function verifyPlatformRevision(self)
	for platform, revision in string.gmatch(self._boardVersion, "(%w+):(%d+)") do
		platform = string.lower(platform)
		revision = tonumber(revision)

		if string.find(self._platform, platform)
			and revision == self._revision then
				return true
		end
	end

	log:warn("Firmware is not compatible with ", self._platform, ":", self._revision)

	return false
 end

-- utility function to parse /dev/mtd
function parseMtd(self)
	local mtd = {}

	-- parse mtd to work out what partitions to use
	local fh, err = io.open("/proc/mtd")
	if fh == nil then
		error(err, 0)
	end

	for line in fh:lines() do
		local partno, name = string.match(line, "mtd(%d+):.*\"([^\"]+)\"")
		if partno then
			mtd[name] = "/dev/mtd/" .. partno
		end
	end

	fh:close()

	self._mtd = mtd
end

function parseUbi(self)
	local ubi = {}

	-- parse mtd to work out what partitions to use
	local fh, err = assert(io.popen("/usr/sbin/ubinfo /dev/ubi0 -a"))

	local volid = false
	for line in fh:lines() do
		if string.match(line, "Volume ID:") then
			volid = string.match(line, "Volume ID:%s+(%d+)")
		elseif string.match(line, "Name:") then
			volname = string.match(line, "Name:%s+([^%s]+)")

			ubi[volname] = volid
			volid = false
		end
	end
	fh:close()

	return ubi
end


-- wait for udev to create device nodes
function udevtrigger(self)
	-- sometimes the devices nodes are not created correctly,
	-- manually triggering udev corrects this
	local cmd = "/sbin/udevtrigger --subsystem-match=ubi"
	log:info(cmd)

	proc = Process(jnt, cmd)
	proc:read(nullProcessSink)
	while proc:status() ~= "dead" do
		-- wait for the process to complete
		Task:yield()
	end

	-- wait for udev to settle before continuing
	local cmd = "/sbin/udevsettle"
	log:info(cmd)

	proc = Process(jnt, cmd)
	proc:read(nullProcessSink)
	while proc:status() ~= "dead" do
		-- wait for the process to complete
		Task:yield()
	end
end


-- zip filter sink to process upgrade zip file
function upgradeSink(self)
	local _fhsink = nil
	local _action = nil

	return function(chunk, err)
		if err then
			log:error("upgrade sink: ", err)
			self.sinkErr = err
			return 0
		end

		Task:yield(true)

		if type(chunk) == "string" then
			self.downloadBytes = self.downloadBytes + #chunk

			if _action == "store" then
				if not _fhsink then
					log:error("_fhsink not defined")
					self.sinkErr = "Something went wrong... _fhsink not defined"
					return nil
				end
			
				-- write content to fhsink
				local t, err = _fhsink(chunk)
				if not t then
					log:error("FLASH err=", err)
					self.sinkErr = "FLASH err=" .. err
					return nil
				end

			elseif _action == "checksum" then
				-- store checksum
				self._checksum = self._checksum .. chunk

			elseif _action == "board.version" then
				self._boardVersion = self._boardVersion .. chunk

			end
			return 1
		end

		if _fhsink then
			-- end of file, close the sink
			_fhsink(nil)
			_fhsink = nil
		end

		if chunk == nil then
			-- end of zip file
			self.downloadClose = true
			return nil
		end

		if type(chunk) == "table" then
			-- new file
			local filename = chunk.filename

			if string.match(filename, "^zImage") or
				string.match(filename, "^Image") then
				if not self:verifyPlatformRevision() then
					self.sinkErr = "Incompatible firmware"
					return nil
				end

				_action = "store"
				_fhsink, err = self:updatevol("kernel_upg", filename, chunk.uncompressed_size)
				if not _fhsink then
					self.sinkErr = err
					return nil
				end

			elseif filename == "root.cramfs" then
				if not self:verifyPlatformRevision() then
					self.sinkErr = "Incompatible firmware"
					return nil
				end

				_action = "store"
				_fhsink = self:updatevol("cramfs_upg", filename, chunk.uncompressed_size)
				if not _fhsink then
					self.sinkErr = err
					return nil
				end

			elseif filename == "upgrade.md5" then
				_action = "checksum"

			elseif chunk.filename == "board.version" then
				_action = "board.version"

			else
				-- ignore file
				_action = nil
			end

			return 1
		end

		-- should never get here
		return nil
	end
end


-- open the zip file or stream for processing
function download(self)
	log:info("Firmware url=", self._url)

	-- unzip the stream, and store the contents
	local sink = ltn12.sink.chain(zip.filter(), self:upgradeSink())

	local parsedUrl = url.parse(self._url)
	self.downloadBytes = 0
	self.sinkErr = false

	local t, err
	if parsedUrl.scheme == "file" then
		local file = io.open(parsedUrl.path)

		local totalBytes = file:seek("end")
		file:seek("set", 0)

		local source = function()
			            local chunk = file:read(0x16000)
			            if not chunk then file:close() end
			            return chunk
			        end

		while true do
			local t, err = ltn12.pump.step(source, sink)
			self._callback(false, "UPDATE_DOWNLOAD", _percent(self.downloadBytes, totalBytes))

			Task:yield()
			if not t then
				if err then
					error(err, 0)
				else
					return
				end
			end
		end 

	elseif parsedUrl.scheme == "http" then
		self.downloadClose = false

		local req = RequestHttp(sink, 'GET', self._url, { stream = true })
		local uri  = req:getURI()

		local http = SocketHttp(jnt, uri.host, uri.port, uri.host)
		http:fetch(req)

		while not self.sinkErr and not self.downloadClose do
			local totalBytes = req:t_getResponseHeader("Content-Length")
			if totalBytes then
				self._callback(false, "UPDATE_DOWNLOAD", _percent(self.downloadBytes, totalBytes))
			end
			Task:yield(true)
		end
	else
		error("Unsupported url scheme", 0)
	end

	if self.sinkErr then
		error(self.sinkErr, 0)
	end
end


-- create and update a ubi volume. returns a sink to the ubi volume.
function updatevol(self, volume, filename, size)

	self._file[volume] = filename
	self._size[volume] = size

	-- make volume
	local cmd = "/usr/sbin/ubimkvol /dev/ubi0 -N " .. volume .. " -s " .. size
	log:info(cmd)

	proc = Process(jnt, cmd)
	proc:read(nullProcessSink)
	while proc:status() ~= "dead" do
		-- wait for the process to complete
		Task:yield()
	end

	-- wait for udev
	self:udevtrigger()

	-- update volume
	local cmd = "/usr/sbin/ubiupdatevol /dev/ubi/" .. volume .. "/vol -s " .. size .. " -"
	log:info(cmd)

	local fh, err = io.popen(cmd, "w")
	if fh == nil then
		error(err, 0)
	end
	
	return function(chunk, err)
		if chunk then
			return fh:write(chunk)
		else
			fh:close()
			return false
		end
	end
end


function renamevol(self, volumes)
	local cmd = { "/usr/sbin/ubirename /dev/ubi0 " }
	for old, new in pairs(volumes) do
		table.insert(cmd, old)
		table.insert(cmd, new)
	end
	cmd = table.concat(cmd, " ")
	log:info(cmd)

	proc = Process(jnt, cmd)
	proc:read(nullProcessSink)
	while proc:status() ~= "dead" do
		-- wait for the process to complete
		Task:yield()
	end
end


function nullProcessSink(chunk, err)
	if err then
		log:warn("process error:", err)
		return nil
	end
	return 1
end


-- remove a ubi volume
function rmvol(self, volume)
	if not self._mtd[volume] then
		return true
	end

	-- remove volume
	local cmd = "/usr/sbin/ubirmvol /dev/ubi0 -N " .. volume
	log:info(cmd)

	proc = Process(jnt, cmd)
	proc:read(nullProcessSink)
	while proc:status() ~= "dead" do
		-- wait for the process to complete
		Task:yield()
	end

	return true
end


-- checksum flash partition
function checksum(self, volume)
	local checksum = {}
	for md5, file in string.gmatch(self._checksum, "(%x+)%s+([^%s]+)") do	
		 checksum[file] = md5
	end

	local filename = self._file[volume]
	local size = self._size[volume]

	local md5check = checksum[filename]

	assert(filename)
	assert(size)
	assert(md5check)

	local file = assert(io.open(self._mtd[volume], "r"))
	local digest = md5.new()

	local len = 0
	while len < size do
		local n = 4096
		if n > (size - len) then
			n = (size - len)
		end

		local c = file:read(n)
		assert(c) -- we should never reach eof

		len = len + n
		digest:update(c)

		self.verifyBytes = self.verifyBytes + n
		self._callback(false, "UPDATE_VERIFY", _percent(self.verifyBytes, self.verifySize))

		Task:yield()
	end
	file:close()

	local md5flash = digest:digest()

	log:info("md5check=", md5check, " md5flash=", md5flash, " ", md5check == md5flash)
	assert(md5check == md5flash, "Firmware checksum failed for " .. volume)
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
