
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
local setmetatable, tonumber, tostring, ipairs, locale, pairs = setmetatable, tonumber, tostring, ipairs, locale, pairs

local Applet		= require("jive.Applet")
local appletManager	= require("jive.AppletManager")
local Event			= require("jive.ui.Event")
local io			= require("io")
local oo			= require("loop.simple")
local math			= require("math")
local table			= require("jive.utils.table")
local string		= require("jive.utils.string")
local lfs			= require('lfs')
local Group			= require("jive.ui.Group")
local Keyboard		= require("jive.ui.Keyboard")
local Textarea		= require("jive.ui.Textarea")
local Textinput     = require("jive.ui.Textinput")
local Window        = require("jive.ui.Window")

local Surface		= require("jive.ui.Surface")
local Process		= require("jive.net.Process")

local jnt = jnt

local log 		= require("jive.utils.log").logger("applet.ImageViewer")
local require = require
local ImageSource	= require("applets.ImageViewer.ImageSource")

module(...)
oo.class(_M, ImageSource)

function __init(self, applet)
	log:info("initialize ImageSourceCard!!!!")
	obj = oo.rawnew(self, ImageSource(applet))

	obj.imgFiles = {}
	obj:readImageList()

	return obj
end

function listNotReadyError(self)
	self:popupMessage(self.applet:string("IMAGE_VIEWER_ERROR"), self.applet:string("IMAGE_VIEWER_CARD_ERROR"))
end

function scanFolder(self, folder)
	
	local dirstoscan = {}
	
	dirstoscan[folder] = false

	for nextfolder, done in pairs(dirstoscan) do
		
		if not done then
		
			for f in lfs.dir(nextfolder) do
			
				local fullpath = nextfolder .. "/" .. f
	
				if lfs.attributes(fullpath, "mode") == "directory" then

					-- push this directory on our list to be scanned
					-- exclude "." and ".."
					if f != "." and f != ".." then
						dirstoscan[fullpath] = false
					end

				elseif lfs.attributes(fullpath, "mode") == "file" then
					-- check for supported file type
					if string.find(string.lower(fullpath), "%pjpe*g")
							or string.find(string.lower(fullpath), "%ppng") 
							or string.find(string.lower(fullpath), "%pgif") then
						-- log:info(fullpath)
						table.insert(self.imgFiles, fullpath)
					end
				end
			
			end
			
			-- don't scan this folder twice - just in case
			table[nextfolder] = true
		end
	end
end


function readImageList(self)

	local imgpath = self.applet:getSettings()["card.path"]

	if lfs.attributes(imgpath, "mode") == "directory" then
		self:scanFolder(imgpath)
		self.lstReady = true
	else
		self:popupMessage(self.applet:string("IMAGE_VIEWER_ERROR"), self.applet:string("IMAGE_VIEWER_CARD_NOT_DIRECTORY"))
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
		if self.currentImage > #self.imgFiles then
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
		self.currentImage = math.random(#self.imgFiles)
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

	local textinput = Textinput("textinput", imgpath,
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
	local backspace = Keyboard.backspace()
	local group = Group('keyboard_textinput', { textinput = textinput, backspace = backspace } )

    window:addWidget(group)
	window:addWidget(Keyboard('keyboard', 'qwerty', textinput))
	window:focusWidget(group)

	self:_helpAction(window, "IMAGE_VIEWER_CARD_PATH", "IMAGE_VIEWER_CARD_PATH_HELP")

    return window
end

--[[

=head1 LICENSE

Copyright 2008 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

