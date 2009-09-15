
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

local next, pairs, type, package, string, tostring = next, pairs, type, package, string, tostring

local oo               = require("loop.simple")
local debug            = require("jive.utils.debug")

local os               = require("os")
local io               = require("io")
local zip              = require("zipfilter")
local ltn12            = require("ltn12")
local lfs              = require("lfs")

local Applet           = require("jive.Applet")
local SlimServer       = require("jive.slim.SlimServer")

local System           = require("jive.System")

local RequestHttp      = require("jive.net.RequestHttp")
local SocketHttp       = require("jive.net.SocketHttp")

local Window           = require("jive.ui.Window")
local SimpleMenu       = require("jive.ui.SimpleMenu")
local Checkbox         = require("jive.ui.Checkbox")
local RadioButton      = require("jive.ui.RadioButton")
local RadioGroup       = require("jive.ui.RadioGroup")
local Label            = require("jive.ui.Label")
local Popup            = require("jive.ui.Popup")
local Icon             = require("jive.ui.Icon")
local Textarea         = require("jive.ui.Textarea")
local Framework        = require("jive.ui.Framework")
local Task             = require("jive.ui.Task")

local debug            = require("jive.utils.debug")

local appletManager    = appletManager
local jiveMain         = jiveMain
local jnt              = jnt

local JIVE_VERSION     = jive.JIVE_VERSION
local EVENT_SHOW       = jive.ui.EVENT_SHOW

module(..., Framework.constants)
oo.class(_M, Applet)


function count(tab)
	local i = 0
	for _, _ in pairs(tab) do
		i = i + 1
	end
	return i
end

function menu(self, menuItem)

	self.window = Window("text_list", menuItem.text)
	self.title = menuItem.text

	-- find the applet directory
	for dir in package.path:gmatch("([^;]*)%?[^;]*;") do
		dir = dir .. "applets"
		local mode = lfs.attributes(dir, "mode")
		if mode == "directory" then
			self.appletdir = dir
			break
		end
	end

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
		self.server:userRequest(
			function(chunk, err)
				if err then
					log:debug(err)
				elseif chunk then
					self:menuSink(chunk.data)
				end
			end,
			false,
			{ "jiveapplets", "target:" .. System:getMachine(), "version:" .. string.match(JIVE_VERSION, "(%d%.%d)") }
		)
	end

	-- create animiation to show while we get data from the server
	local popup = Popup("waiting_popup")
	local icon  = Icon("icon_connecting")
	local label = Label("text", self:string("APPLET_FETCHING"))
	popup:addWidget(icon)
	popup:addWidget(label)
	self:tieAndShowWindow(popup)

	self.popup = popup
end


function menuSink(self, data)

	self:tieWindow(self.window)
	self.popup:hide()
	self.window:show()

	self.help = Textarea("help_text", self:string("HELP"))
	self.menu = SimpleMenu("menu")
	self.menu:setComparator(SimpleMenu.itemComparatorWeightAlpha)
	self.menu:setHeaderWidget(self.help)
	self.window:addWidget(self.menu)

	self.toremove = {}
	self.todownload = {}

	local installed = self:getSettings()
	local ip, port = self.server:getIpPort()

	local inrepos = {}

	if data.item_loop then

		for _,entry in pairs(data.item_loop) do

			if entry.relurl then
				entry.url = 'http://' .. ip .. ':' .. port .. entry.relurl
			end

			inrepos[entry.name] = 1

			if installed[entry.name] then
				if not appletManager:hasApplet(entry.name) then
					self.todownload[entry.name] = { url = entry.url, ver = entry.version }
				end
			end

			self.menu:addItem({
				text = entry.title,
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:_repoEntry(menuItem, entry)
				end,
				weight = 2
			})				  
		end

	end

	for name, _ in pairs(installed) do

		if appletManager:hasApplet(name) and not inrepos[name] then
			self.menu:addItem({
				text = name,
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:_nonRepoEntry(menuItem, name)
				end,
				weight = 2
			})
		end

	end

	if self.menu:numItems() > 0 then
		local item = {
			text = tostring(self:string("INSTALLREMOVE")) .. " (" .. count(self.todownload) .. "/" .. count(self.toremove) .. ")",
			sound = "WINDOWSHOW",
			callback = function(event, menuItem)
						   if next(self.todownload) or next(self.toremove) then
							   self:action()
						   else
							   self.window:bumpRight()
						   end
					   end,
			weight = 6
		}
		self.menu:addItem(item) 
		self.menu:addListener(EVENT_SHOW, 
			function(event)
				self.menu:setText(item, 
					tostring(self:string("INSTALLREMOVE")) .. " (" .. count(self.todownload) .. "/" .. count(self.toremove) .. ")")
			end
		)

	else
		self.menu:addItem( {
			text = self:string("NONE_FOUND"), 
			iconStyle = 'item_no_arrow',
			weight = 2
		})
	end
end


function _repoEntry(self, menuItem, entry)
	local window = Window("text_list", menuItem.text)
	local menu = SimpleMenu("menu")
	window:addWidget(menu)

	local items = {}
	local group = RadioGroup()

	if entry.desc then
		items[#items+1] = { 
			text = self:string("DESCRIPTION"),
			sound = "WINDOWSHOW",
			callback = function(event, menuItem)
						   local window = Window("text_list", entry.name)
						   window:addWidget(Textarea("text", entry.desc or ""))
						   self:tieAndShowWindow(window)
					   end
		}
	end

	if entry.creator or entry.email then
		local text = tostring(self:string("AUTHOR")) .. " :"
		if entry.creator and entry.email then
			text = text .. entry.creator .. " (" .. entry.email .. ")"
		else
			text = text .. (entry.creator or entry.email)
		end
		items[#items+1] = { 
			text  = text,
			style = "item_no_arrow"
		}
	end

	items[#items+1] = {
		text  = tostring(self:string("CURRENT")) .. " (" .. (self:getSettings()[entry.name] or " ") .. ")",
		style = 'item_choice',
		check = RadioButton(
			"radio", 
			group, 
			function()
				self.todownload[entry.name] = nil
				self.toremove[entry.name] = nil
			end,
			self.todownload[entry.name] == nil
		),
	}

	items[#items+1] = {
		text  = tostring(self:string("INSTALL")) .. " (" .. entry.version .. ")",
		style = 'item_choice',
		check = RadioButton(
			"radio", 
			group, 
			function()
				self.todownload[entry.name] = { url = entry.url, ver = entry.version }
				self.toremove[entry.name] = nil
			end,
			self.todownload[entry.name] ~= nil
		),
	}

	if self:getSettings()[entry.name] then
		items[#items+1] = {
			text = self:string("REMOVE"),
			style = 'item_choice',
			check = RadioButton(
				"radio", 
				group, 
				function()
					self.todownload[entry.name] = nil
					self.toremove[entry.name] = 1
				end
			),
		}
	end

	menu:setItems(items)
	self:tieAndShowWindow(window)
	return window
end


function _nonRepoEntry(self, menuItem, name)
	local window = Window("text_list", menuItem.text)
	local menu = SimpleMenu("menu")
	window:addWidget(menu)

	menu:addItem({
		text = self:string("REMOVE"), 
		style = 'item_choice',
		check = Checkbox(
			"checkbox",
			function(object, isSelected)
				self.toremove[name] = isSelected
			end,
			false
		)
	})

	self:tieAndShowWindow(window)
	return window
end


-- action changes
function action(self)
	-- generate animated downloading screen
	local icon = Icon("icon_connecting")
	local label = Label("text", self:string("DOWNLOADING"))
	self.animatewindow = Popup("waiting_popup")
	self.animatewindow:addWidget(icon)
	self.animatewindow:addWidget(label)
	self.animatewindow:show()

	self.task = Task("applet download", self, function()
												  self:_remove()
												  self:_download()
												  self:_finished(label)
											  end)

	self.task:addTask()
end


-- remove applets
function _remove(self)

	for applet, appletdata in pairs(self.toremove) do
		local dir = self.appletdir .. "/" .. applet .. "/"

		log:info("removing: ", dir)

		for file in lfs.dir(dir) do
			if file ~= "." and file ~= ".." then
				os.remove(dir .. "/" .. file)
			end
		end

		lfs.rmdir(dir)
	end
end


-- download each applet in turn
function _download(self)

	for applet, appletdata in pairs(self.todownload) do
		local dir = self.appletdir .. "/" .. applet .. "/"
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


-- called when download / removal is complete
function _finished(self, label)
	-- save new version numbers
	for applet, appletdata in pairs(self.toremove) do
		self:getSettings()[applet] = nil
	end
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
		log:info("RESTARTING JIVE...")
		appletManager:callService("reboot")
	else
		self.animatewindow:hide()
		self.window:removeWidget(self.menu)
		self.window:removeWidget(self.help)
		self.window:addWidget(Textarea("help_text", self:string("RESTART_APP")))
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
			log:info("extracting file: " .. filename)

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

