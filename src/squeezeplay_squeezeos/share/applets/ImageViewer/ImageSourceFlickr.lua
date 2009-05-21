
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
local setmetatable, tonumber, tostring, ipairs = setmetatable, tonumber, tostring, ipairs

local io		= require("io")
local oo		= require("loop.simple")
local math		= require("math")
local table		= require("jive.utils.table")
local string	= require("jive.utils.string")
local lfs		= require('lfs')

local RadioButton	= require("jive.ui.RadioButton")
local RadioGroup	= require("jive.ui.RadioGroup")
local Surface		= require("jive.ui.Surface")
local Process		= require("jive.net.Process")
local Window		= require("jive.ui.Window")
local require = require
local log 		= require("jive.utils.log").logger("applet.ImageViewer")

local jnt = jnt

module(...)
oo.class(_M, ImageSource)

local imgFiles = {}

function __init(self)

	log:info("initialize ImageSourceFlickr")

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
function settings(self, menuItem)
	local window = Window("text_list", menuItem.text, 'settingstitle')
	window:addWidget(SimpleMenu("menu",
		{
			{
				text = self:string("IMAGE_VIEWER_FLICKR_DISPLAY"), 
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:defineDisplay(menuItem)
					return EVENT_CONSUME
				end
			},
			{
				text = self:string("IMAGE_VIEWER_FLICKR_FLICKR_ID"),
				sound = "WINDOWSHOW",
				callback = function(event, menuItem)
					self:defineFlickrId(menuItem)
					return EVENT_CONSUME
				end
			},
		}))

	self:tieAndShowWindow(window)
	return window
end

function defineDisplay(self, menuItem)
	local group = RadioGroup()

	local display = self:getSettings()["flickr.display"]
	
	local window = Window("text_list", menuItem.text, flickrTitleStyle)
	window:addWidget(SimpleMenu("menu",
		{
            {
                text = self:string("IMAGE_VIEWER_FLICKR_DISPLAY_OWN"),
		style = 'item_choice',
                check = RadioButton(
                    "radio",
                    group,
                    function()
                        self:setDisplay("own")
                    end,
                    display == "own"
	            ),
            },
            {
                text = self:string("IMAGE_VIEWER_FLICKR_DISPLAY_FAVORITES"),
		style = 'item_choice',
                check = RadioButton(
                    "radio",
                    group,
                    function()
                        self:setDisplay("favorites")
                    end,
                    display == "favorites"
	            ),
            },           
            {
                text = self:string("IMAGE_VIEWER_FLICKR_DISPLAY_CONTACTS"),
		style = 'item_choice',
                check = RadioButton(
                    "radio",
                    group,
                    function()
                        self:setDisplay("contacts")
                    end,
                    display == "contacts"
                ),
            },
 			{
				text = self:string("IMAGE_VIEWER_FLICKR_DISPLAY_INTERESTING"), 
				style = 'item_choice',
				check = RadioButton(
				   "radio", 
				   group, 
				   function() 
					   self:setDisplay("interesting") 
				   end,
				   display == "interesting"
				),
			},
			{ 
				text = self:string("IMAGE_VIEWER_FLICKR_DISPLAY_RECENT"), 
				style = 'item_choice',
				check = RadioButton(
				   "radio", 
				   group, 
				   function() 
					   self:setDisplay("recent") 
				   end,
				   display == "recent"
			   ),
			},
		}))

	self:tieAndShowWindow(window)
	return window
end

function defineFlickrId(self, menuItem)

    local window = Window("text_list", self:string("IMAGE_VIEWER_FLICKR_FLICKR_ID"), 'settingstitle')

	local flickrid = self:getSettings()["flickr.idstring"]
	if flickrid == nil then
		flickrid = " "
	end

	local input = Textinput("textinput", flickrid,
		function(_, value)
			if #value < 4 then
				return false
			end

			log:debug("Input " .. value)
			self:setFlickrIdString(value)

			window:playSound("WINDOWSHOW")
			window:hide(Window.transitionPushLeft)
			return true
		end)

    local help = Textarea("help_text", self:string("IMAGE_VIEWER_FLICKR_FLICKR_ID_HELP"))

    window:addWidget(help)
    window:addWidget(input)

    self:tieAndShowWindow(window)
    return window
end

function setDisplay(self, display)
	if self:getSettings()["flickr.id"] == "" and (display == "own" or display == "contacts" or display == "favorites") then
		self:popupMessage(self:string("IMAGE_VIEWER_FLICKR_ERROR"), self:string("IMAGE_VIEWER_FLICKR_INVALID_DISPLAY_OPTION"))
	else
		self:getSettings()["flickr.display"] = display
		self:storeSettings()
	end
end

function setFlickrId(self, flickrid)
	self:getSettings()["flickr.id"] = flickrid
	self:storeSettings()
end


function setFlickrIdString(self, flickridString)
	self:getSettings()["flickr.idstring"] = flickridString
	self:getSettings()["flickr.id"] = ""
	self:storeSettings()
	self:resolveFlickrIdByEmail(flickridString)
end
--]]


--[[

=head1 LICENSE

Copyright 2008 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

