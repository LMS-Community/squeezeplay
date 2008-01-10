
-- FIXME at the moment the upgrade stores the kernel and filesystem
-- images in /tmp before writing to flash. when the bootloader and
-- kernel support safe upgrading the flash should be written to as
-- the images are downloaded.


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
local coroutine   = require("coroutine")

local RequestHttp = require("jive.net.RequestHttp")
local SocketHttp  = require("jive.net.SocketHttp")
local Process     = require("jive.net.Process")
local Framework   = require("jive.ui.Framework")

local debug       = require("jive.utils.debug")
local log         = require("jive.utils.log").logger("upgrade")

local jnt = jnt

module(..., oo.class)


function __init(self, url)
	local obj = oo.rawnew(self, {
				      url = url,
				      _mtd = {},
				      _size = {},
				      _checksum = "",
			      })

	log:warn("created object\n")
	return obj
end


-- perform the upgrade
function start(self, callback)
	local t, err

	if not callback then
		callback = function() end
	end

	callback(false, "UPDATE_DOWNLOAD", "")

	-- parse the flash devices
	t, err = self:parseMtd()
	if not t then
		log:warn("parseMtd failed")
		return nil, err
	end
			    
	-- parse the kernel version
	self._zImageExtraVersion = "zImage-P7"
	self._mtd[self._zImageExtraVersion] = self._mtd["zImage"]
	t, err = self:parseVersion()
	if not t then
		log:warn("parseVersion failed")
		return nil, err
	end
			    
	-- stream the firmware, and update the flash
	t, err = self:download(callback)
	if not t then
		log:warn("download Failed")
		return nil, err
	end

	callback(false, "UPDATE_VERIFY")

	-- checksum kernel
	t, err = self:checksum(self._zImageExtraVersion, "/tmp/")
	if not t then
		log:warn("file checksum failed")
		return nil, err
	end

	-- checksum cramfs
	t, err = self:checksum("root.cramfs", "/tmp/")
	if not t then
		log:warn("file checksum failed")
		return nil, err
	end

	callback(false, "UPDATE_WRITE")

	-- disable VOL+ on boot
	t, err = self:fw_setenv({ sw7 = "" })
	if not t then
		log:warn("fw_setenv failed")
		return nil, err
	end

	-- write images to flash
	t, err = self:flash(self._zImageExtraVersion)
	if not t then
		log:warn("flash kernel failed")
		return nil, err
	end

	t, err = self:flash("root.cramfs")
	if not t then
		log:warn("flash filesystem failed")
		return nil, err
	end

	callback(false, "UPDATE_VERIFY")

	-- checksum kernel
	t, err = self:checksum(self._zImageExtraVersion)
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

	log:warn("REBOOTING ...")
	os.execute("/bin/busybox reboot -f")

	return true
end


-- zip filter sink to process upgrade zip file
function upgradeSink(self)
	local fhsink = nil
	local action = nil
	local length = 0
	local part = nil

	return function(chunk)
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
			       log:warn("END OF ZIP FILE")
			       self.downloadClose = true
			       return nil
		       end

		       if type(chunk) == "table" then
			       -- new file
			       log:warn("GOT FILE ", chunk.filename)

			       if chunk.filename == self._zImageExtraVersion then
				       -- kernel
				       part = self._zImageExtraVersion

			       elseif chunk.filename == "root.cramfs" then
				       -- cramfs
				       part = "root.cramfs"

			       elseif chunk.filename == "upgrade.md5" then
				       -- md5 checksums
				       action = "checksum"

			       else
				       action = nil
			       end


			       -- open file handle
			       if part ~= nil then
				       action = "store"
				       length = 0

				       -- open file handle
				       -- FIXME erase and write flash here
				       local fh, err = io.open("/tmp/" .. part, "w+")
				       fhsink = ltn12.sink.file(fh, err)
			       end

			       return 1
		       end

		       -- should never get here
		       return nil
	       end
end


-- utility function to parse /dev/mtd
function parseMtd(self)
	log:warn("PARSEMTD")

	-- parse mtd to work out what partitions to use
	local fh, err = io.open("/proc/mtd")
	if fh == nil then
		return fh, err
	end

	local mtd = string.lower(fh:read("*all"))
	fh:close()

	self._mtd["zImage"] = string.match(mtd, "mtd(%d+):[^\n]*zimage[^\n]*\n")
	self._mtd["root.cramfs"] = string.match(mtd, "mtd(%d+):[^\n]*cramfs[^\n]*\n")
	self._mtd["yaffs"] = string.match(mtd, "mtd(%d+):[^\n]*yaffs[^\n]*\n")
	self._mtd["env"] = string.match(mtd, "mtd(%d+):[^\n]*env[^\n]*\n")

	for _, part in ipairs({"zImage", "root.cramfs", "yaffs", "env"}) do
		log:warn("mtd ", part, " ", self._mtd[part])

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

	log:warn("cmdline=", cmdline)
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

	log:warn("mtdset=", mtdset, " nextKernelblock=", self.nextKernelblock, " nextMtdset=", self.nextMtdset)

	Task:yield(true)

	return 1
end


-- parse kernel extraversion
function parseVersion(self)

	local fh, err = io.open("/proc/version")
	if fh == nil then
		return fh, err
	end

	local version = fh:read("*all")
	fh:close()

	local extraversion = string.match(version, "Linux version [%d%.]+(%-[^%s]+)") or ""

	-- backwards compatibility
	if extraversion == "-P4" then
		extraversion = ""
	end

	log:warn("extraversion=", extraversion)

	-- select kernel to use
	self._zImageExtraVersion = "zImage" .. extraversion
	self._mtd[self._zImageExtraVersion] = self._mtd["zImage"]

	Task:yield(true)

	return 1
end


-- update bootloader environment
function fw_setenv(self, variables)
	local cmd = { "/usr/sbin/fw_setenv" }

	for k,v in pairs(variables) do
		log:warn("k=", k, " v=", v)

		cmd[#cmd + 1] = k

		if v == nil then
			cmd[#cmd + 1] = '""'
		else
			cmd[#cmd + 1] = '"' .. v .. '"'
		end
	end

	local str = table.concat(cmd, " ")

	log:warn("fw_setenv: ", str)
	if os.execute(str) ~= 0 then
		return nil, "fw_setenv failed"
	end

	Task:yield(true)

	return 1
end


-- open the zip file or stream for processing
function download(self, callback)
	log:warn("self.url=", self.url)

	-- unzip the stream, and store the contents
	local sink = ltn12.sink.chain(zip.filter(), self:upgradeSink())

	local parsedUrl = url.parse(self.url)
	self.downloadBytes = 0

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
			callback(false, "UPDATE_DOWNLOAD", math.floor((self.downloadBytes / totalBytes) * 100) .. "%")

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

		while not self.downloadClose do
			local totalBytes = req:t_getResponseHeader("Content-Length")
			if totalBytes then
				callback(false, "UPDATE_DOWNLOAD", math.floor((self.downloadBytes / totalBytes) * 100) .. "%")
			end
			Task:yield(true)
		end

		return true
	else
		return false, "Unsupported url scheme"
	end
end


function nullProcessSink(chunk, err)
	if err then
		log:warn("process error:", err)
		return nil
	end
	return 1
end


-- flash the image from tmp file
function flash(self, part)
	local cmd, proc

	-- erase flash
	cmd = "/usr/sbin/flash_eraseall -q " .. self._mtd[part]
	log:warn("flash: ", cmd)

	proc = Process(jnt, cmd)
	proc:read(nullProcessSink)
	while proc:status() ~= "dead" do
		-- wait for the process to complete
		Task:yield()
	end

	-- write flash
	cmd = "/usr/sbin/nandwrite -qp " .. self._mtd[part] .. " " .. "/tmp/" .. part
	log:warn("flash: ", cmd)

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
	log:warn("checksum cmd: ", cmd)

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

	log:warn("md5check=", md5check, " md5flash=", md5flash, " ", md5check == md5flash)
	return md5check == md5flash, "PROBLEM_CHECKSUM_FAILED"
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
