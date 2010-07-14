
-- stuff we use
local tostring, unpack, pairs = tostring, unpack, pairs

local oo                     = require("loop.simple")
local io                     = require("io")
local os                     = require("os")
local math                   = require("math")
local string                 = require("string")

local Applet                 = require("jive.Applet")
local System                 = require("jive.System")
local Checkbox               = require("jive.ui.Checkbox")
local Framework              = require("jive.ui.Framework")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local Popup                  = require("jive.ui.Popup")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Textarea               = require("jive.ui.Textarea")
local Timer                  = require("jive.ui.Timer")
local Window                 = require("jive.ui.Window")
local Networking             = require("jive.net.Networking")

local jnt                    = jnt

module(..., Framework.constants)
oo.class(_M, Applet)


function settingsShow(self, menuItem)
	local sshEnabled = _fileMatch("/etc/inetd.conf", "^ssh")

	local window = Window("help_list", menuItem.text, 'settingstitle')
	local menu = SimpleMenu("menu", {
					{
						text = self:string("SSH_ENABLE"),
						style = 'item_choice',
						check = Checkbox("checkbox",
								function(_, isSelected)
									if isSelected then
										self:_enableSSH()
									else
										self:_disableSSH()
									end
								end,
								sshEnabled
							)
					},
				})

	window:addWidget(menu)

	self.window = window
	self.menu = menu
	if sshEnabled then
		self:_addHelpInfo()
	end

	self:tieAndShowWindow(window)
	return window
end


function _addHelpInfo(self)
	local ipaddr = _getIPAddress()
	local password = "1234"

	log:warn("ipaddr = ", ipaddr)
	log:warn("password = ", password)

	self.howto = Textarea("help_text", self:string("SSH_HOWTO", tostring(password), tostring(ipaddr)))
	self.menu:setHeaderWidget(self.howto)

	self.window:focusWidget(self.menu)

end


function _enableSSH(self, window)

	self:_addHelpInfo()
	self.menu:reLayout()

	-- enable SSH
	_fileSub("/etc/inetd.conf", "^#ssh", "ssh")
	_sighup("/usr/sbin/inetd")

	-- set root password
	--_passwd("root", password)
end


function _disableSSH(self, window)
	self.howto = nil

	-- disable SSH
	_fileSub("/etc/inetd.conf", "^ssh", "#ssh")
	_sighup("/usr/sbin/inetd")
end


function _getIPAddress()
	local ip_address, ip_subnet
	local ifObj = Networking:activeInterface()

	if ifObj then
		ip_address, ip_subnet = ifObj:getIPAddressAndSubnet()
	end

	return ip_address or "?.?.?.?"
end


function _randomPassword()
	local password = {}

	for i = 1,8 do
		local n = math.random(62)
		if n < 10 then
			n = n + 48
		elseif n < 36 then
			n = n + 87
		else
			n = n + 29
		end

		password[#password + 1] = n
	end

	return string.char(unpack(password))
end


function _fileMatch(file, pattern)
	local fi = io.open(file, "r")

	for line in fi:lines() do
		if string.match(line, pattern) then
			fi:close()
			return true
		end

	end
	fi:close()

	return false
end


function _fileSub(file, pattern, repl)
	local data = ""

	local fi = io.open(file, "r")
	for line in fi:lines() do
		line = string.gsub(line, pattern, repl)
		data = data .. line .. "\n"
	end
	fi:close()

	System:atomicWrite(file, data)
end


function _sighup(process)
	local pid

	local pattern = "%s*(%d+).*" .. process

	log:warn("pattern is ", pattern)

	local cmd = io.popen("/bin/ps -o pid,command")
	for line in cmd:lines() do
		pid = string.match(line, pattern)
		if pid then break end
	end
	cmd:close()

	if pid then
		log:warn("kill -hup ", pid)
		os.execute("kill -hup " .. pid)
	else
		log:error("cannot hup ", process)
	end
end


function _passwd(user, password)
--	os.execute("/usr/bin/chpasswd " .. user .. ":" .. password, "w")
	os.execute("echo " .. user .. ":" .. password .. "| /usr/sbin/chpasswd " , "w")
-- A check of the return of the command should be done here
-- Return is : Password for 'root' changed
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
