
--[[
=head1 NAME

applets.ImageViewer.ImageViewerApplet - Slideshow of images from /media/*/images directory

=head1 DESCRIPTION

Finds images from removable media and displays them as a slideshow

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 

=cut
--]]


-- stuff we use
local setmetatable, tonumber, tostring, string, ipairs = setmetatable, tonumber, tostring, string, ipairs

local io                     = require("io")
local oo                     = require("loop.simple")
local math                   = require("math")
local table                  = require("jive.utils.table")
local strings                = require("jive.utils.strings")
local lfs                    = require('lfs')

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

        for dir in lfs.dir("/media") do
                if lfs.attributes("/media/" .. dir .. "/images", "mode") == "directory" then

	--[[ for development purposes
		local imageDir = '/Users/bklaas/svk/squeezeplay/7.4/private-branches/fab4/squeezeplay/src/squeezeplay/share/applets/ImageViewer/images'
		local relPath = 'applets/ImageViewer/images'
	--]]

			local imageDir = "/media/" .. dir .. "/images"
			local relPath = imageDir

			local cmd = 'cd ' .. imageDir .. ' && ls -1 *.*'
			-- filename search format:
			-- an image file extension, .png, .jpg, .gif
			local filePattern = '%w+.*%p%a%a%a'
			local proc = Process(jnt, cmd)
			proc:read(
				function(chunk, err)
					if err then
						return nil
					end
					if chunk ~=nil then
						local files = strings:split("\n", chunk)
						--for w in string.gmatch(chunk, filePattern) do
						for _, file in ipairs(files) do
							if string.find(file, "%pjpe*g")
								or string.find(file, "%ppng") 
								or string.find(file, "%pgif") 
								 then
       			                         		table.insert(imgFiles, relPath .. "/" .. file)
							end
						end
					end
					return 1
			end)
	
			self.nextImage = 1
	
		end
	end

	-- display the first one in the window. 100ms timer needed so ls processes is returned and imgFiles table is populated
	local timer = Timer(100, 
				function()
					self:displaySlide()
				end, 
			true)
	timer:start()
end

function free(self)
	self.window:hide()
	self.thisImage = 0
	self.nextImage = 1
	self.window = nil
	return true

end

function displaySlide(self)

	--log:info(imgFiles[self.nextImage])
	local image = Surface:loadImage(imgFiles[self.nextImage])
	
	local w, h = image:getSize()
	local screenWidth, screenHeight = Framework:getScreenSize()

	-- FIXME: do something with images that don't fit on screen nicely
	if screenHeight != h 
		or screenWidth != w then
	end

	local window = Window('window')
	window:addWidget(Icon("background", image))
	window:addListener(EVENT_MOUSE_DOWN | EVENT_KEY_PRESS | EVENT_KEY_HOLD | EVENT_IR_PRESS,
		function(event)
			local type = event:getType()
			local keyPress

			-- next slide on touch 
			if type == EVENT_MOUSE_DOWN then
				self:displaySlide()
				return EVENT_CONSUME
			end

			-- IR events
			if type == EVENT_IR_PRESS then
				-- exit applet on left arrow or home
				if event:isIRCode('arrow_left') or event:isIRCode('home') then
					self:free()
					return EVENT_CONSUME
				-- next slide on IR right, up, or center
				elseif event:isIRCode('arrow_right') or event:isIRCode('play') or event:isIRCode('arrow_up') then
					self:displaySlide()
					return EVENT_CONSUME
				-- previous slide is down arrow
				elseif event:isIRCode('arrow_down') then
					if self.previousImage == 0 then
						--bump
						window:playSound("BUMP")
						window:bumpRight()
						return EVENT_CONSUME
					else
						self.nextImage = self.previousImage
						self:displaySlide()
						return EVENT_CONSUME
					end
        			end
			end

			return EVENT_UNUSED
                end
	)

	-- replace the window if it's already there
	if self.window then
		window:showInstead(Window.transitionFadeIn)
		self.window = window
	-- otherwise it's new
	else
		self.window = window
		self.window:show()
	end

	-- no screensavers por favor
	self.window:setAllowScreensaver(false)

	self.thisImage     = self.nextImage
	self.nextImage     = self.nextImage + 1
	self.previousImage = self.thisImage - 1
	-- roll back to first image after getting through table
	if not imgFiles[self.nextImage] then
		self.nextImage = 1
	end

end

--[[

=head1 LICENSE

Copyright 2008 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

