
--[[
=head1 NAME

applets.Slideshow.SlideshowApplet - Displays set of predefined images

=head1 DESCRIPTION

This applet was made for displaying a set of fixed images fullscreeen for in-store demos

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 

=cut
--]]


-- stuff we use
local setmetatable, tonumber, tostring, string = setmetatable, tonumber, tostring, string

local io                     = require("io")
local oo                     = require("loop.simple")
local math                   = require("math")
local string                 = require("string")
local table                  = require("jive.utils.table")

local Applet                 = require("jive.Applet")
local appletManager          = require("jive.AppletManager")
local Event                  = require("jive.ui.Event")
local Framework              = require("jive.ui.Framework")
local Icon                   = require("jive.ui.Icon")
local Surface                = require("jive.ui.Surface")
local Window                 = require("jive.ui.Window")
local Task                   = require("jive.ui.Task")
local Timer                  = require("jive.ui.Timer")
local Process                = require("jive.net.Process")

local log                    = require("jive.utils.log").addCategory("test", jive.utils.log.DEBUG)
local debug                  = require("jive.utils.debug")

local jnt = jnt

module(..., Framework.constants)
oo.class(_M, Applet)

local imgFiles = {}

function startSlideshow(self, menuItem)

	log:info("startSlideshow")

	self.screen_width, self.screen_height = Framework:getScreenSize()

	self.delay = self:getSettings()['delay']
	if not self.delay then
		self.delay = 5
	end
	self.delay = self.delay * 1000
	
	local i = 1

	-- for development
	--local imageDir = '/Users/bklaas/svk/jive/branches/7.0/jive/src/pkg/jive/share/applets/Slideshow/images'

	local imageDir = '/usr/share/jive/applets/Slideshow/images'
	local relPath = 'applets/Slideshow/images/'

	local cmd = 'ls ' .. imageDir .. '/*.*'
	-- filename search format:
	-- two or more digits, followed by an _, 
	-- followed by two or more alphanumeric chars, 
	-- followed by a file extension, e.g. ".png"
	local filePattern = '%d%d+_%a%a+%p%a%a%a'
        local proc = Process(jnt, cmd)
        proc:read(
                function(chunk, err)
                        if err then
                                log:warn("wft?? ", err)
                                return nil
                        end
                        if chunk ~= nil then
				for w in string.gmatch(chunk, filePattern) do
					log:info(w)
                                	table.insert(imgFiles, relPath .. w)
				end
                        end
			return 1
		end)

	self.whichImage = 1

	-- display the first one in the window. 100ms timer needed so ls processes is returned and imgFiles table is populated
	local timer = Timer(100, 
                            function()
                                    self:displaySlide()
	end, true)
                timer:start()

	Framework:addListener(EVENT_KEY_PRESS | EVENT_KEY_HOLD,
		function(event)
			return EVENT_CONSUME
		end
	)

	local squeezeboxJive = appletManager:loadApplet("SqueezeboxJive")
	if squeezeboxJive then
		squeezeboxJive:setBacklightTimeout(0)
		appletManager:freeApplet('SqueezeboxJive')
	end

end

function displaySlide(self)

	log:info(imgFiles[self.whichImage])
	local image = Surface:loadImage(imgFiles[self.whichImage])

	local window = Window('window')
	window:addWidget(Icon("icon", image))

	-- replace the window if it's already there
	if self.window then
		window:showInstead(Window.transitionFadeIn)
		self.window = window
	        local event = Event:new(EVENT_KEY_PRESS)
		Framework:dispatchEvent(self.window, event)
	-- otherwise it's new
	else
		self.window = window
		self.window:show()
	end

	-- no screensavers por favor
	self.window:setAllowScreensaver(false)

	-- show a new slide every <delay> seconds
	self.window:addTimer(self.delay, function() self:displaySlide() end)

	self.whichImage = self.whichImage + 1
	-- roll back to first image after getting through table
	if not imgFiles[self.whichImage] then
		self.whichImage = 1
	end

end

--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

