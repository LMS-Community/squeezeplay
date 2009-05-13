
--[[
=head1 NAME

applets.ImageViewer.ImageSourceCard - Image source for Image Viewer

=head1 DESCRIPTION

Finds images from removable media

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 

=cut
--]]


-- stuff we use
local setmetatable, tonumber, tostring, ipairs, locale = setmetatable, tonumber, tostring, ipairs, locale

local Applet		= require("jive.Applet")
local appletManager	= require("jive.AppletManager")
local Event			= require("jive.ui.Event")
local io			= require("io")
local oo			= require("loop.simple")
local math			= require("math")
local table			= require("jive.utils.table")
local string		= require("jive.utils.string")
local lfs			= require('lfs')
local Textarea		= require("jive.ui.Textarea")
local Textinput     = require("jive.ui.Textinput")
local Window        = require("jive.ui.Window")

local Surface		= require("jive.ui.Surface")
local Process		= require("jive.net.Process")

local jnt = jnt

local log 		= require("jive.utils.log").addCategory("test", jive.utils.log.DEBUG)
local require = require
local ImageSource	= require("applets.ImageViewer.ImageSource")

module(...)
oo.class(_M, ImageSource)

function __init(self, applet)
	log:info("initialize ImageSourceCard")
	obj = oo.rawnew(self, ImageSource(applet))

	obj.imgFiles = {}
	obj:readImageList()

	return obj
end

function listNotReadyError(self)
	self:popupMessage(self.applet:string("IMAGE_VIEWER_ERROR"), self.applet:string("IMAGE_VIEWER_CARD_ERROR"))
end

function readImageList(self)
	-- find directories /media/*/images to parse
    for dir in lfs.dir("/media") do
        if lfs.attributes("/media/" .. dir .. "/images", "mode") == "directory" then

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
						local files = string.split("\n", chunk)
						for _, file in ipairs(files) do
							if string.find(file, "%pjpe*g")
								or string.find(file, "%ppng") 
								or string.find(file, "%pgif") 
								 then
									log:info(relPath .. "/" .. file)
									table.insert(self.imgFiles, relPath .. "/" .. file)
							end
						end
					end
					self.lstReady = true
					return 1
			end)
		end
	end
end

function getImage(self)
	if self.imgFiles[self.currentImage] != nil then
		local image = Surface:loadImage(self.imgFiles[self.currentImage])
		return image
	end
end

function nextImage(self, ordering)
	if #self.imgFiles == 0 then
		self:emptyListError()
		return
	end
	if ordering == "random" then
		self.currentImage = math.random(#self.imgFiles)
	else
		self.currentImage = self.currentImage + 1
		if self.currentImage > #imgFiles then
			self.currentImage = 1
		end
	end
	self.imgReady = true
end

function previousImage(self, ordering)
	if #self.imgFiles == 0 then
		self:emptyListError()
		return
	end
	if ordering == "random" then
		self.currentImage = math.random(#imgFiles)
	else
		self.currentImage = self.currentImage - 1
		if self.currentImage < 1 then
			self.currentImage = #self.imgFiles
		end
	end
	self.imgReady = true
end

function getText(self)
	return "",self.imgFiles[self.currentImage],""
end


function settings(self, window)

	local imgpath = self.applet:getSettings()["card.path"]

	local input = Textinput("textinput", imgpath,
		function(_, value)
			if #value < 4 then
				return false
			end

			log:debug("Input " .. value)
			self.applet:getSettings()["card.path"] = value

			window:playSound("WINDOWSHOW")
			window:hide(Window.transitionPushLeft)
			return true
		end)

    local help = Textarea("help_text", "IMAGE_VIEWER_CARD_PATH_HELP")

    window:addWidget(help)
    window:addWidget(input)

    return window
end

--[[

=head1 LICENSE

Copyright 2008 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

