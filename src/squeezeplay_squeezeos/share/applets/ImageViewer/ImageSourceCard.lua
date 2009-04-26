
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

local log 		= require("jive.utils.log").addCategory("test", jive.utils.log.DEBUG)

local jnt = jnt

-- our class
module(..., oo.class)
--oo.class(_M, Applet)

local imgFiles = {}

function __init(self)

	log:info("initialize ImageSourceCard")

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
       			                 	table.insert(imgFiles, relPath .. "/" .. file)
							end
						end
					end
					return 1
			end)
	
		end
	end

	self.currentImage = 1
	return self
end

function getImage(self)
	local image = Surface:loadImage(imgFiles[self.currentImage])
	return image
end

function nextImage(self, ordering)
	if ordering == "random" then
		self.currentImage = math.random(#imgFiles)
	else
		self.currentImage = self.currentImage + 1
		if self.currentImage > #imgFiles then
			self.currentImage = 1
		end
	end
end

function previousImage(self, ordering)
	if ordering == "random" then
		self.currentImage = math.random(#imgFiles)
	else
		self.currentImage = self.currentImage - 1
		if self.currentImage > 1 then
			self.currentImage = #imgFiles
		end
	end
end

function getText(self)
	return "",imgFiles[self.currentImage],""
end

--[[
function settings(self, caller, menuItem)

    local window = Window("text_list", menuItem.text, 'settingstitle')

	local imgpath = caller:getSettings()["card.path"]

	local input = Textinput("textinput", imgpath,
		function(_, value)
			if #value < 4 then
				return false
			end

			log:debug("Input " .. value)
			caller:getSettings()["card.path"] = value

			window:playSound("WINDOWSHOW")
			window:hide(Window.transitionPushLeft)
			return true
		end)

    local help = Textarea("help_text", "IMAGE_VIEWER_CARD_PATH_HELP")

    window:addWidget(help)
    window:addWidget(input)

    caller:tieAndShowWindow(window)
    return window
end
--]]

--[[

=head1 LICENSE

Copyright 2008 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

