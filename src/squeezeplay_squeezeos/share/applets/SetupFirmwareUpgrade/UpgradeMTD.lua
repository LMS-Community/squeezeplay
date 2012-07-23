

local ipairs, pairs, tonumber, tostring, type = ipairs, pairs, tonumber, tostring, type

local oo          = require("loop.base")
local io          = require("io")
local os          = require("os")
local math        = require("math")
local table       = require("jive.utils.table")
local zip         = require("zipfilter")
local ltn12       = require("ltn12")
local string      = require("string")
local url         = require("socket.url")
local http        = require("socket.http")

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


function __init(self)
	local obj = oo.rawnew(self, {
				      _mtd = {},
				      _size = {},
				      _checksum = "",
				      _boardVersion = "",
			      })

	return obj
end


-- perform the upgrade
function start(self, url, mtd, callback)
	local t, err

	self.url = url

	if not callback then
		callback = function() end
	end

	callback(false, "UPDATE_DOWNLOAD", "")

	-- parse the board revision
	t, err = self:parseCpuInfo()
	if not t then
		log:warn("parseCpuInfo failed")
		return nil, err
	end

	-- parse the flash devices
	t, err = self:parseMtd()
	if not t then
		log:warn("parseMtd failed")
		return nil, err
	end
			    
	-- disable VOL+ on boot
	t, err = self:fw_setenv({ sw7 = "" })
	if not t then
		log:warn("fw_setenv failed")
		return nil, err
	end

	-- erase flash
	t, err = self:flashErase("zImage")
	if not t then
		log:warn("flash kernel failed")
		return nil, err
	end

	t, err = self:flashErase("root.cramfs")
	if not t then
		log:warn("flash filesystem failed")
		return nil, err
	end
			    
	-- stream the firmware, and update the flash
	t, err = self:download(callback)
	if not t then
		log:warn("download Failed err=", err)
		return nil, err
	end

	callback(false, "UPDATE_VERIFY")

	-- checksum kernel
	t, err = self:checksum("zImage")
	if not t then
		log:warn("flash checksum failed")
		return nil, err
	end

	-- checksum cramfs
	t, err = self:checksum("root.cramfs")
	if not t then
		log:warn("flash checksum failed")
		return nil, err
	end

	-- switch running kernel and filesystem and enable VOL+ on boot
	t, err = self:fw_setenv({ kernelblock = self.nextKernelblock,
				  mtdset = self.nextMtdset,
				  sw7 = "echo Booting last image; blink; setenv kernelblock " .. self.thisKernelblock .. "; setenv mtdset " .. self.thisMtdset .. "; boot",
				  -- fix for bug 6322
				  sw6 = "echo Factory reset; blink; nande b00 1400000; blink"
			  })
	if not t then
		log:warn("fw_setenv failed")
		return nil, err
	end

	callback(true, "UPDATE_REBOOT")

	-- two second delay
	local t = Framework:getTicks()
	while (t + 2000) > Framework:getTicks() do
		Task:yield(true)
	end

	appletManager:callService("reboot")

	return true
end


function processSink(self, prog)
	local fh, err = io.popen(prog, "w")

	if fh == nil then
		return function()
			return false, err
		end
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


-- zip filter sink to process upgrade zip file
function upgradeSink(self)
	local fhsink = nil
	local action = nil
	local length = 0
	local part = nil

	return function(chunk, err)
		       if err then
			       log:info("sinkErr=", err)
			       self.sinkErr = err
			       return 0
		       end

		       Task:yield(true)

		       if type(chunk) == "string" then
			       self.downloadBytes = self.downloadBytes + #chunk

			       if action == "store" then
				       -- write content to fhsink
				       local t, err = fhsink(chunk)
				       if not t then
					       log:warn("FLASH err=", err)
					       return nil
				       end

				       length = length + #chunk

			       elseif action == "checksum" then
				       -- store checksum
				       self._checksum = self._checksum .. chunk

			       elseif action == "board.version" then
			               self._boardVersion = self._boardVersion .. chunk
			       end

			       return 1
		       end

		       if fhsink then
			       -- end of file, close the sink
			       self._size[part] = length
			       part = nil

			       fhsink(nil)
			       fhsink = nil
		       end

		       if chunk == nil then
			       -- end of zip file
			       self.downloadClose = true
			       return nil
		       end

		       if type(chunk) == "table" then
			       -- new file
			       if string.match(chunk.filename, "^zImage") then
				       -- kernel
				       part = "zImage"

			       elseif chunk.filename == "root.cramfs" then
				       -- cramfs
				       part = "root.cramfs"

			       elseif chunk.filename == "upgrade.md5" then
				       -- md5 checksums
				       action = "checksum"

			       elseif chunk.filename == "board.version" then
			               action = "board.version"

			       else
				       action = nil
			       end


			       -- open file handle
			       if part ~= nil then
			               if not self:verifyPlatformRevision() then
				               self.sinkErr = "Incompatible firmware"
				               return nil
				       end

				       action = "store"
				       length = 0

				       -- open file handle
					local cmd = "/usr/sbin/nandwrite -qp " .. self._mtd[part] .. " -"
					log:info("flash: ", cmd)

					fhsink = self:processSink(cmd)
			       end

			       return 1
		       end

		       -- should never get here
		       return nil
	       end
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
			self._platform = string.lower(string.match(line, ".+:%s+([^%s]+)"))
		elseif string.match(line, "Revision") then
			self._revision = tonumber(string.match(line, ".+:%s+([^%s]+)"))
		end

	end
	fh:close()

	return 1
end


function verifyPlatformRevision(self)
	for platform, revision in string.gmatch(self._boardVersion, "(%a+):(%d+)") do
		platform = string.lower(platform)
		revision = tonumber(revision)

		if string.match(platform, self._platform)
			and revision == self._revision then
				return true
		end
	end

	-- backwards compatibility for initial jive boards
	if self._boardVersion == ""
		and self._platform == "jive"
		and self._revision == 0 then
		return true
	end

	log:warn("Firmware is not compatible with ", self._platform, ":", self._revision)

	return false
end


-- utility function to parse /dev/mtd
function parseMtd(self)
	-- parse mtd to work out what partitions to use
	local fh, err = io.open("/proc/mtd")
	if fh == nil then
		return fh, err
	end

	local mtd = string.lower(fh:read("*all"))
	fh:close()

	self._mtd["zImage"] = string.match(mtd, "mtd(%d+):[^\n]*zimage[^\n]*\n")
	self._mtd["root.cramfs"] = string.match(mtd, "mtd(%d+):[^\n]*cramfs[^\n]*\n")
	self._mtd["jffs2"] = string.match(mtd, "mtd(%d+):[^\n]*jffs2[^\n]*\n")
	self._mtd["env"] = string.match(mtd, "mtd(%d+):[^\n]*env[^\n]*\n")

	for _, part in ipairs({"zImage", "root.cramfs", "jffs2", "env"}) do
		if self._mtd[part] == nil then
			return nil, "PROBLEM_PARSE_MTD"
		else
			self._mtd[part] = "/dev/mtd/" .. self._mtd[part]
		end
	end

	-- parse cmdline to work out which image is running
	local fh, err = io.open("/proc/cmdline")
	if fh == nil then
		return fh, err
	end

	local cmdline = string.lower(fh:read("*all"))
	fh:close()

	local mtdset = string.match(cmdline, "mtdset=(%d+)")
	mtdset = tonumber(mtdset) or 0

	if mtdset == 0 then
		self.thisKernelblock = "c"
		self.thisMtdset = "0"
		self.nextKernelblock = "580"
		self.nextMtdset = "1"
	else
		self.thisKernelblock = "580"
		self.thisMtdset = "1"
		self.nextKernelblock = "c"
		self.nextMtdset = "0"
	end

	log:info("mtdset=", mtdset, " nextKernelblock=", self.nextKernelblock, " nextMtdset=", self.nextMtdset)

	Task:yield(true)

	return 1
end


-- update bootloader environment
function fw_setenv(self, variables)
	local cmd = { "/usr/sbin/fw_setenv" }

	for k,v in pairs(variables) do
		cmd[#cmd + 1] = k

		if v == nil then
			cmd[#cmd + 1] = '""'
		else
			cmd[#cmd + 1] = '"' .. v .. '"'
		end
	end

	local str = table.concat(cmd, " ")

	log:info("fw_setenv: ", str)
	if os.execute(str) ~= 0 then
		return nil, "fw_setenv failed"
	end

	Task:yield(true)

	return 1
end


-- open the zip file or stream for processing
function download(self, callback)
	log:info("self.url=", self.url)

	-- unzip the stream, and store the contents
	local sink = ltn12.sink.chain(zip.filter(), self:upgradeSink())

	local parsedUrl = url.parse(self.url)
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
			callback(false, "UPDATE_DOWNLOAD", math.floor((self.downloadBytes / totalBytes) * 100))

			Task:yield()
			if not t then
				return not err, err
			end
		end 

	elseif parsedUrl.scheme == "http" then
		self.downloadClose = false

		local req = RequestHttp(sink, 'GET', self.url, { stream = true })
		local uri  = req:getURI()

		local http = SocketHttp(jnt, uri.host, uri.port, uri.host)
		http:fetch(req)

		while not self.sinkErr and not self.downloadClose do
			local totalBytes = req:t_getResponseHeader("Content-Length")
			if totalBytes then
				callback(false, "UPDATE_DOWNLOAD", math.floor((self.downloadBytes / totalBytes) * 100))
			end
			Task:yield(true)
		end
	else
		return false, "Unsupported url scheme"
	end

	if self.sinkErr then
		log:info("sinkErr=", self.sinkErr)
		return false, self.sinkErr
	end

	return true
end


function nullProcessSink(chunk, err)
	if err then
		log:warn("process error:", err)
		return nil
	end
	return 1
end


-- flash the image from tmp file
function flashErase(self, part)
	local cmd, proc

	-- erase flash
	cmd = "/usr/sbin/flash_eraseall -q " .. self._mtd[part]
	log:info("flash: ", cmd)

	proc = Process(jnt, cmd)
	proc:read(nullProcessSink)
	while proc:status() ~= "dead" do
		-- wait for the process to complete
		Task:yield()
	end

	return 1
end


-- checksum flash partition
function checksum(self, part, dir)
	if self._checksum == "" then
		log:error("Firmware checksum not found")
		return nil, "PROBLEM_NO_CHECKSUM"
	end

	local md5check = string.match(self._checksum,
				      "(%x+)%s+" .. string.gsub(part, "[%-]", "%%%1"))

	local cmd
	if dir then
		cmd = "md5sum " .. dir .. part
	else
		cmd = "/usr/sbin/nanddump -obl " .. self._size[part] .. " " .. self._mtd[part] .. " | md5sum"
	end
	log:info("checksum cmd: ", cmd)

	local md5flash = {}

	local proc = Process(jnt, cmd)
	proc:read(
		function(chunk, err)
			if err then
				log:warn("md5sum error ", err)
				return nil
			end
			if chunk ~= nil then
				table.insert(md5flash, chunk)
			end
			return 1			
		end)

	while proc:status() ~= "dead" do
		-- wait for the process to complete
		Task:yield()
	end
	md5flash = string.match(table.concat(md5flash), "(%x+)%s+.+")

	log:info("md5check=", md5check, " md5flash=", md5flash, " ", md5check == md5flash)
	return md5check == md5flash, "PROBLEM_CHECKSUM_FAILED"
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
