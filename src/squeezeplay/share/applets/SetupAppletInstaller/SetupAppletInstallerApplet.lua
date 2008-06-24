
--[[
=head1 NAME

applets.SetupAppletInstaller.SetupAppletInsallerApplet

=head1 DESCRIPTION

Allows applets to be downloaded from SqueezeCenter to jive

SC responds to a query for 'jiveapplets' with a list of applets including name, version and a url for a zipfile
containing the applet.  Users may select which applets to download, they will then be downloaded and extracted
into the applet directory.

Assumptions:
- applet name returned by SC is used as the foldername for the applet
- the zip file downloaded contains files but not directories - all files are extracted into the applet directory
- the name of the applet returned by SC should match the files contained in the zip file, i.e. <name>Applet.lua and <name>Meta.lua

=cut
--]]

local next, pairs, type, package = next, pairs, type, package

local oo               = require("loop.simple")
local debug            = require("jive.utils.debug")

local os               = require("os")
local io               = require("io")
local zip              = require("zipfilter")
local ltn12            = require("ltn12")
local lfs              = require("lfs")

local Applet           = require("jive.Applet")
local SlimServer       = require("jive.slim.SlimServer")

local RequestHttp      = require("jive.net.RequestHttp")
local SocketHttp       = require("jive.net.SocketHttp")

local Window           = require("jive.ui.Window")
local SimpleMenu       = require("jive.ui.SimpleMenu")
local Checkbox         = require("jive.ui.Checkbox")
local Label            = require("jive.ui.Label")
local Popup            = require("jive.ui.Popup")
local Icon             = require("jive.ui.Icon")
local Textarea         = require("jive.ui.Textarea")
local Framework        = require("jive.ui.Framework")
local Task             = require("jive.ui.Task")

local log              = require("jive.utils.log").logger("applets.setup")

local debug            = require("jive.utils.debug")

local appletManager    = appletManager
local jiveMain         = jiveMain
local jnt              = jnt

module(...)
oo.class(_M, Applet)


function menu(self, menuItem)

	self.window = Window("window", menuItem.text)
	self.title = menuItem.text

	-- find a server
	local player = appletManager:callService("getCurrentPlayer")
	if player then
		self.server = player:getSlimServer()
	else
		for _, server in appletManager:callService("iterateSqueezeCenters") do
			self.server = server
			break
		end
	end

	-- ask about its applets
	if self.server then
		self.server:request(
			function(chunk, err)
				if err then
					log:debug(err)
				elseif chunk then
					self:menuSink(chunk.data)
				end
			end,
			false,
			{ "jiveapplets" }
		)
	end

	self:tieAndShowWindow(self.window)
end


function menuSink(self, data)

	self.help = Textarea("help", self:string("HELP"))
	self.menu = SimpleMenu("menu")
	self.menu:setComparator(SimpleMenu.itemComparatorWeightAlpha)
	self.window:addWidget(self.help)
	self.window:addWidget(self.menu)

	self.todownload = {}

	local installed = self:getSettings()
	local ip, port = self.server:getIpPort()

	for _,entry in pairs(data.item_loop) do

		local version
		local check = false
		local url

		if entry.relurl then
			url = 'http://' .. ip .. ':' .. port .. entry.relurl
		else
			url = entry.url
		end

		if installed[entry.applet] then
			version = installed[entry.applet] .. " > " .. entry.version
			if entry.version > installed[entry.applet] then
				self.todownload[entry.applet] = { url = url, ver = entry.version }
				check = true
			end
		else
			version = entry.version
			self.todownload[entry.applet] = { url = url, ver = entry.version }
			check = true
		end

		self.menu:addItem( {
			text = entry.name .. " [" .. version .. "]",
			icon = Checkbox("checkbox",
				function(object, isSelected)
					if isSelected then
						self.todownload[entry.applet] = { url = url, ver = entry.version }
					else
						self.todownload[entry.applet] = nil
					end
				end,
				check
			),
			weight = check and 2 or 4 
		})
	end

	if self.menu:numItems() > 0 then
		self.menu:addItem( {
			text = self:string("INSTALL"),
			sound = "WINDOWSHOW",
			callback = function(event, menuItem)
						   if next(self.todownload) then
							   self:startDownload()
						   else
							   self.window:bumpRight()
						   end
					   end,
			weight = 6
		})
	else
		self.menu:addItem( {
			text = self:string("NONE_FOUND"), 
			weight = 2
		})
	end
end


-- start the download
function startDownload(self)
	-- generate animated downloading screen
	local icon = Icon("iconConnecting")
	local label = Label("text", self:string("DOWNLOADING"))
	self.animatewindow = Popup("popupIcon")
	self.animatewindow:addWidget(icon)
	self.animatewindow:addWidget(label)
	self.animatewindow:show()

	-- find the applet directory
	local appletdir
	for dir in package.path:gmatch("([^;]*)%?[^;]*;") do
		dir = dir .. "applets"
		local mode = lfs.attributes(dir, "mode")
		if mode == "directory" then
			appletdir = dir
			break
		end
	end

	self.task = Task("applet download", self, function()
												  self:_download(appletdir)
												  self:_finished(label)
											  end)

	self.task:addTask()
end


-- download each applet in turn
function _download(self, appletdir)

	for applet, appletdata in pairs(self.todownload) do
		local dir = appletdir .. "/" .. applet .. "/"
		local sink = ltn12.sink.chain(zip.filter(), self:_zipSink(dir))

		log:info("downloading: ", appletdata.url, " to: ", dir)

		if lfs.attributes(dir) == nil then
			lfs.mkdir(dir)
		end

		self.fetched = false

		local req = RequestHttp(sink, 'GET', appletdata.url, { stream = true })
		local uri = req:getURI()

		local http = SocketHttp(jnt, uri.host, uri.port, uri.host)
		http:fetch(req)

		while not self.fetched do
			self.task:yield()
		end
	end
end


-- called when download complete
function _finished(self, label)
	-- save new version numbers
	for applet, appletdata in pairs(self.todownload) do
		self:getSettings()[applet] = appletdata.ver
	end
	self:storeSettings()

	-- FIXME: ideally we do something here to reload all applets or restart the app itself rather than rebooting

	if lfs.attributes("/bin/busybox") ~= nil then
		label:setValue(self:string("RESTART_JIVE"))
		-- two second delay
		local t = Framework:getTicks()
		while (t + 2000) > Framework:getTicks() do
			Task:yield(true)
		end
		log:warn("RESTARTING JIVE...")
		os.execute("/bin/busybox reboot -f")
	else
		self.animatewindow:hide()
		self.window:removeWidget(self.menu)
		self.window:removeWidget(self.help)
		self.window:addWidget(Textarea("help", self:string("RESTART_APP")))
	end
end


-- sink for writing out files once they have been unziped by zipfilter
function _zipSink(self, dir)
	local fh = nil

	return function(chunk)

		if chunk == nil then
			if fh then
				fh:close()
				fh = nil
				self.fetched = true
			end

		elseif type(chunk) == "table" then
			if fh then
				fh:close()
				fh = nil
			end

			local filename = dir .. chunk.filename
			log:warn("extracting file: " .. filename)

			fh = io.open(filename, "wb")

		else
			if fh == nil then
				return nil
			end

			fh:write(chunk)
		end

		return 1
	end
end

