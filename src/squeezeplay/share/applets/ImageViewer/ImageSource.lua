
--[[
=head1 NAME

applets.ImageViewer.ImageSource - Base class for all Image sources

=head1 DESCRIPTION

Base class for all Image sources. Please derive from this class when extending Image Viewer

=head1 FUNCTIONS

=cut
--]]


-- stuff we use
local setmetatable, tonumber, tostring, ipairs, locale, assert = setmetatable, tonumber, tostring, ipairs, locale, assert
local require = require
local Event			= require("jive.ui.Event")
local io			= require("io")
local oo			= require("loop.simple")
local math			= require("math")
local table			= require("jive.utils.table")
local string		= require("jive.utils.string")
local Textarea		= require("jive.ui.Textarea")
local Window        = require("jive.ui.Window")
local Framework		= require("jive.ui.Framework")
local log 			= require("jive.utils.log").logger("applet.ImageViewer")
local jiveMain         = jiveMain

local EVENT_KEY_PRESS = jive.ui.EVENT_KEY_PRESS
local EVENT_MOUSE_PRESS = jive.ui.EVENT_MOUSE_PRESS

module(..., oo.class)


function __init(self, applet)
	log:info("init of ImageSource base")
	obj = oo.rawnew(self)
	obj.imgFiles = {}
	obj.imgReady = false
	obj.lstReady = false
	obj.applet = applet
	obj.currentImage = 0
	return obj
end

function popupMessage(self, title, msg)
	local popup = Window("text_list", title)
	local text = Textarea("text", msg)

	popup:addWidget(text)
	self.applet:applyScreensaverWindow(popup)
	popup:addListener(EVENT_KEY_PRESS | EVENT_MOUSE_PRESS,
			  function()
				popup:playSound("WINDOWHIDE")
				popup:hide()
			  end)

	self.applet:tieAndShowWindow(popup)
end

function _helpAction(self, window, titleText, bodyText, menu)
	if titleText or bobyText then
		local helpAction =      function()
						local window = Window("help_info", self.applet:string(titleText), "helptitle")
						window:setAllowScreensaver(false)

						-- no more help menu yet
						--[[
						window:setButtonAction("rbutton", "more_help")
						window:addActionListener("more_help", self, function()
							window:playSound("WINDOWSHOW")

							appletManager:callService("supportMenu")
						end)
						--]]

						local textarea = Textarea("text", self.applet:string(bodyText))
						window:addWidget(textarea)
						self.applet:tieAndShowWindow(window)

						window:playSound("WINDOWSHOW")
					end
					
		window:addActionListener("help", self, helpAction)
		if menu then
			jiveMain:addHelpMenuItem(menu, self, helpAction)
		end

	end

	window:setButtonAction("rbutton", "help")
end


function emptyListError(self)
	self:popupMessage(self.applet:string("IMAGE_VIEWER_ERROR"), self.applet:string("IMAGE_VIEWER_EMPTY_LIST"))
end

function listNotReadyError(self)
	self:popupMessage(self.applet:string("IMAGE_VIEWER_ERROR"), self.applet:string("IMAGE_VIEWER_LIST_NOT_READY"))
end

function imageReady(self)
	return self.imgReady
end

function listReady(self)
	return self.lstReady
end

function useAutoZoom(self)
	return true
end

--optionally, image sources can modify the icon that appears on the loading page, to, for instance, show a Flickr icon instead
function updateLoadingIcon(self, icon)
end

function nextImage(self, ordering)
	assert(false, "please implement in derived class")
end

function previousImage(self, ordering)
	assert(false, "please implement in derived class")
end

function getImage(self)
	assert(false, "please implement in derived class")
end

function getText(self)
	assert(false, "please implement in derived class")
end

function getMultilineText(self)
	return self:getText()
end

function getCurrentImagePath(self)
	return self.imgFiles[self.currentImage]
end

function getImageCount(self)
	return #self.imgFiles
end

function free(self)
end