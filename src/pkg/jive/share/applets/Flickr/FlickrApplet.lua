
--[[
=head1 NAME

applets.Flickr.FlickrApplet - A screensaver displaying a Flickr photo stream.

=head1 DESCRIPTION

This screensaver displays random images every 10 seconds from the Flickr
picture website. It demonstrates using the network API in addition to
applet and screensavers concepts in Jive.

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 
FlickrApplet overrides the following methods:

=cut
--]]


-- stuff we use
local pairs, ipairs, tostring = pairs, ipairs, tostring

local math             = require("math")
local table            = require("table")
local socket           = require("socket")

local oo               = require("loop.simple")

local Applet           = require("jive.Applet")
local Font             = require("jive.ui.Font")
local Framework        = require("jive.ui.Framework")
local Icon             = require("jive.ui.Icon")
local Label            = require("jive.ui.Label")
local RadioButton      = require("jive.ui.RadioButton")
local RadioGroup       = require("jive.ui.RadioGroup")
local SimpleMenu       = require("jive.ui.SimpleMenu")
local Surface          = require("jive.ui.Surface")
local Window           = require("jive.ui.Window")
local SocketHttp       = require("jive.net.SocketHttp")
local RequestHttp      = require("jive.net.RequestHttp")
local json             = require("json")
                       
local log              = require("jive.utils.log").logger("applets.screensavers")

local EVENT_KEY_PRESS  = jive.ui.EVENT_KEY_PRESS
local EVENT_WINDOW_RESIZE = jive.ui.EVENT_WINDOW_RESIZE
local EVENT_CONSUME    = jive.ui.EVENT_CONSUME
local FRAME_RATE       = jive.ui.FRAME_RATE
local LAYER_FRAME      = jive.ui.LAYER_FRAME
local LAYER_CONTENT    = jive.ui.LAYER_CONTENT
local KEY_BACK         = jive.ui.KEY_BACK

local jnt              = jnt


module(...)
oo.class(_M, Applet)


local apiKey           = "18d9e492ca288b453a9cc6065c440d0c"
local transitionBoxOut


function openScreensaver(self, menuItem)

	self.photoQueue = {}

	local ok, err = self:displayNextPhoto()

	local label
	if ok then
		label = Label("label", self:string("SCREENSAVER_FLICKR_LOADING_PHOTO"))
	else
		label = Label("label", self:string("SCREENSAVER_FLICKR_ERROR") .. err)
	end
	
	self.window = self:_window(label)

	return self.window
end


function openSettings(self, menuItem)
	local window = Window("window", menuItem.text)
	window:addWidget(SimpleMenu("menu",
			{
				{
					text = "Display", 
					callback = function(event, menuItem)
							   self:displaySetting(menuItem):show()
							   return EVENT_CONSUME
						   end
				},
				{
					text = "Speed", 
					callback = function(event, menuItem)
							   self:timeoutSetting(menuItem):show()
							   return EVENT_CONSUME
						   end
				},
			}))

	return window
end


function displaySetting(self, menuItem)
	local group = RadioGroup()

	local display= self:getSettings()["display"]
	
	local window = Window("window", menuItem.text)
	window:addWidget(SimpleMenu("menu",
		{
			{
				text = "Interesting Photos", 
				icon = RadioButton(
						   "radio", 
						   group, 
						   function() 
							   self:setDisplay("interesting") 
						   end,
						   display == "interesting"
					   ),
			},
			{ 
				text = "Recent Photos", 
				icon = RadioButton(
						   "radio", 
						   group, 
						   function() 
							   self:setDisplay("recent") 
						   end,
						   display == "recent"
					   ),
			},
		}))

	return window
end


function timeoutSetting(self, menuItem)
	local group = RadioGroup()

	local timeout = self:getSettings()["timeout"]

	local window = Window("window", menuItem.text)
	window:addWidget(SimpleMenu("menu",
		{
			{
				text = self:string("SCREENSAVER_FLICKR_DELAY_10_SEC"),
				icon = RadioButton("radio", group, function() self:setTimeout(10000) end, timeout == 10000),
			},
			{ 
				text = self:string("SCREENSAVER_FLICKR_DELAY_20_SEC"),
				icon = RadioButton("radio", group, function() self:setTimeout(20000) end, timeout == 20000),
			},
			{ 
				text = self:string("SCREENSAVER_FLICKR_DELAY_30_SEC"),
				icon = RadioButton("radio", group, function() self:setTimeout(30000) end, timeout == 30000),
			},
			{
				text = self:string("SCREENSAVER_FLICKR_DELAY_1_MIN"),
				icon = RadioButton("radio", group, function() self:setTimeout(60000) end, timeout == 60000),
			},
		}))

	return window
end


function setDisplay(self, display)
	self:getSettings()["display"] = display
end


function setTimeout(self, timeout)
	self:getSettings()["timeout"] = timeout
end


function displayNextPhoto(self)

	-- fill photo queue if it's empty
	if #self.photoQueue == 0 then
		return self:_requestPhoto()
	end

	-- pick random photo from response
	local photo = table.remove(self.photoQueue, math.random(#self.photoQueue))

	local host, port, path = self:_getPhotoUrl(photo)
	log:info("photo URL: ", host, ":", port, path)

	-- request photo
	local http = SocketHttp(jnt, host, port, "flickr2")
	local req = RequestHttp(function(chunk, err)
					if chunk then
						local srf = Surface:loadImageData(chunk, #chunk)
						self:_loaded(photo, srf)
					end
				end,
				'GET',
				path)
	http:fetch(req)

	return true
end


function _requestPhoto(self)

	local method, args

	if self:getSettings()["display"] == "recent" then
		method = "flickr.photos.getRecent"
		args = { per_page = 1 }
	else
		method = "flickr.interestingness.getList"
		args = { per_page = 100 }
	end

	local host, port, path = self:_getRest(method, args)
	if host then
		log:info("getRecent URL: ", host, ":", port, path)

		local socket = SocketHttp(jnt, host, port, "flickr")
		local req = RequestHttp(
			function(chunk, err)
				self:_getPhotoList(chunk, err)
			end,
			'GET',
			path)
		socket:fetch(req)

		if self.timer then
			self.window:removeTimer(self.timer)
			self.timer = nil
		end
		return true
	else
		return false, port -- port is err!
	end
end


function _window(self, ...)
	local window = Window("flickr")

	-- black window background
	local w, h = window:getSize()
	local bg  = Surface:newRGBA(w, h)
	bg:filledRectangle(0, 0, w, h, 0x000000FF)
	window:addWidget(Icon("background", bg))

	for i, v in ipairs{...} do
		window:addWidget(v)
	end

	-- close the window on left
	window:addListener(EVENT_KEY_PRESS,
			   function(evt)
				   if evt:getKeycode() == KEY_BACK then
					   window:hide()
					   self.photoQueue = {}
				   end
			   end)

	window:addListener(EVENT_WINDOW_RESIZE,
			   function(evt)
				   local icon = self:_makeIcon(self.photo, self.photoSrf)
				   self.window:addWidget(icon)
			   end)

	return window
end


function _getPhotoList(self, chunk, err)
	-- FIXME error processing

	if chunk then

		log:debug("got chunk ", chunk)
		local obj = json.decode(chunk)

		-- add photos to queue
		for i,photo in ipairs(obj.photos.photo) do
			self.photoQueue[#self.photoQueue + 1] = photo
		end

		self:displayNextPhoto()
	end
end


function _makeIcon(self, photo, srf)
	-- reposition icon
	local sw, sh = Framework:getScreenSize()

	local w,h = srf:getSize()
	if w < h then
		srf = srf:rotozoom(0, sw / w, 1)
	else
		srf = srf:rotozoom(-90, sw / h, 1)
	end

	w,h = srf:getSize()
	local x, y = (sw - w) / 2, (sh - h) / 2

	local font = self.window:styleFont("font")

	-- draw 
	local txt1 = Surface:drawText(font, 0x00000000, photo.ownername)
	txt1:blit(srf, 5 - x, 5 - y)

	local txt2 = Surface:drawText(font, 0xFFFFFFFF, photo.ownername)
	txt2:blit(srf, 6 - x, 6 - y)

	if photo.title then
		local titleWidth = font:width(photo.title)

		local txt1 = Surface:drawText(font, 0x00000000, photo.title)
		txt1:blit(srf, sw - 5 + x - titleWidth, 5 - y)

		local txt2 = Surface:drawText(font, 0xFFFFFFFF, photo.title)
		txt2:blit(srf, sw - 6 + x - titleWidth, 6 - y)
	end

	local icon = Icon("image", srf)
	icon:setPosition(x, y)

	return icon
end


function _loaded(self, photo, srf)
	log:debug("photo loaded")

	self.photo = photo
	self.photoSrf = srf

	local icon = self:_makeIcon(photo, srf)

	self.window = self:_window(icon)
	self.window:showInstead(transitionBoxOut)

	-- start timer for next photo in timeout seconds
	local timeout = self:getSettings()["timeout"]
	self.timer = self.window:addTimer(timeout,
				     function()
					     self:displayNextPhoto()
				     end)
end


function _getRest(self, method, args)
	local url = {}	
	url[#url + 1] = "method=" .. method

	for k,v in pairs(args) do
		url[#url + 1] = k .. "=" .. v
	end

	url[#url + 1] = "api_key=" .. apiKey
	url[#url + 1] = "extras=owner_name"
	url[#url + 1] = "format=json"
	url[#url + 1] = "nojsoncallback=1"
	
	local ip, err = socket.dns.toip("api.flickr.com")

	if ip then
		return ip, 80, "/services/rest/?" .. table.concat(url, "&")
	else
		log:error(err)
		return nil, err
	end
end


function _getPhotoUrl(self, photo, size)
	local server = "farm" .. photo.farm .. ".static.flickr.com"
	local path = "/" .. photo.server .. "/" .. photo.id .. "_" .. photo.secret .. (size or "") .. ".jpg"

	return socket.dns.toip(server), 80, path
end


function transitionBoxOut(oldWindow, newWindow)
	local frames = FRAME_RATE * 2 -- 2 secs
	local screenWidth, screenHeight = Framework:getScreenSize()
	local incX = screenWidth / frames / 2
	local incY = screenHeight / frames / 2
	local x = screenWidth / 2
	local y = screenHeight / 2
	local i = 0

	return function(widget, surface)
		       local adjX = i * incX
		       local adjY = i * incY

		       newWindow:draw(surface, LAYER_FRAME)
		       oldWindow:draw(surface, LAYER_CONTENT)

		       surface:setClip(x - adjX, y - adjY, adjX * 2, adjY * 2)
		       newWindow:draw(surface, LAYER_CONTENT)

		       i = i + 1
		       if i == frames then
			       Framework:_killTransition()
		       end
	       end
end


-- applet skin
function skin(self, s)
	s.flickr.layout = Window.noLayout
	s.flickr.font = Font:load("fonts/FreeSans.ttf", 10)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

