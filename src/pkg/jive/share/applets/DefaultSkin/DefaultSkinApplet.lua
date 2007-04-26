
--[[
=head1 NAME

applets.DefaultSkin.DefaultSkinApplet - The default Jive skin.

=head1 DESCRIPTION

This applet implements the default Jive skin. It can
be used as a model to provide alternate skins for Jive.

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 
DefaultSkinApplet overrides the following methods:

=cut
--]]


-- stuff we use
local oo                     = require("loop.simple")

local Applet                 = require("jive.Applet")
local Font                   = require("jive.ui.Font")
local Framework              = require("jive.ui.Framework")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local Menu                   = require("jive.ui.Menu")
local RadioButton            = require("jive.ui.RadioButton")
local RadioGroup             = require("jive.ui.RadioGroup")
local Surface                = require("jive.ui.Surface")
local Textarea               = require("jive.ui.Textarea")
local Window                 = require("jive.ui.Window")

local table                  = require("jive.utils.table")
local debug                  = require("jive.utils.debug")
local autotable              = require("jive.utils.autotable")

local EVENT_ACTION           = jive.ui.EVENT_ACTION
local EVENT_CONSUME          = jive.ui.EVENT_CONSUME
local EVENT_WINDOW_POP       = jive.ui.EVENT_WINDOW_POP
local LAYER_FRAME            = jive.ui.LAYER_FRAME
local LAYER_CONTENT_ON_STAGE = jive.ui.LAYER_CONTENT_ON_STAGE

local jus                    = jive.ui.style
local appletManager          = appletManager


module(...)
oo.class(_M, Applet)


-- Define useful variables for this skin
local imgpath = "applets/DefaultSkin/images/"
local fontpath = "fonts/"

local screenWidth, screenHeight = Framework:getScreenSize()

local wallpapers = {
	["Chapple_1.jpg"] = "Chapple_1.jpg",
	["Clearly-Ambiguous_1.jpg"] = "Clearly-Ambiguous_1.jpg",
	["Clearly-Ambiguous_2.jpg"] = "Clearly-Ambiguous_2.jpg",
	["Clearly-Ambiguous_3.jpg"] = "Clearly-Ambiguous_3.jpg",
	["Clearly-Ambiguous_4.jpg"] = "Clearly-Ambiguous_4.jpg",
	["Clearly-Ambiguous_5.jpg"] = "Clearly-Ambiguous_5.jpg",
	["Clearly-Ambiguous_6.jpg"] = "Clearly-Ambiguous_6.jpg",
	["dotDOTdot_1.jpg"] = "dotDOTdot_1.jpg",
	["Los-Cardinalos_1.jpg"] = "Los-Cardinalos_1.jpg",
	["Orin-Optiglot_1.jpg"] = "Orin-Optiglot_1.jpg",
}

local backgroundLicense = "The background images are under a Creative Commons Attribution license. See http://creativecommons.org/licenses/by/3.0/.\n\nThe Credits\n Chapple\n Scott Robinson\n dotDOTdot\n Los Cardinalos\n Orin Optiglot\n"

--[[

=head2 applets.DefaultSkin.DefaultSkinApplet:displayName()

Overridden to return the string "Default Skin"

=cut
--]]
function displayName(self)
	return "Default Skin"
end


--[[

=head2 applets.DefaultSkin.DefaultSkinApplet:defaultSettings()

Overridden to return the default wallpaper selected.

=cut
--]]
function defaultSettings(self)
	return { 
		wallpaper = "Clearly-Ambiguous_6.jpg",
	}
end


-- wallpaperSettings
-- The meta hooks this function to allow the user to select
-- a wallpaper
function wallpaperSetting(self, menu_item)
	local window = Window(self:displayName(), menu_item:getValue())
	local menu = Menu("menu")
	window:addWidget(menu)

	local wallpaper = self:getSettings()["wallpaper"]
	
	local group = RadioGroup()
	
	for name, file in table.pairsByKeys(wallpapers) do
	
		menu:addItem(
			Label(
				"label", 
				name, 
				RadioButton(
					"radio", 
					group, 
					function()
						self:_setBackground(file)
					end,
					wallpaper == file
				)
			)
		)
	end

	local credits = Label("label", "License")
	credits:addListener(EVENT_ACTION,
		function()
			local window = Window("window", "License")
			window:addWidget(Textarea("textarea", backgroundLicense))
			window:show()
			return EVENT_CONSUME
		end
	)
	menu:addItem(credits)

	-- Store the applet settings when the window is closed
	window:addListener(EVENT_WINDOW_POP,
		function()
			self:storeSettings()
		end
	)

	return window
end


function _setBackground(self, wallpaper)
	-- set the new wallpaper, or use the existing setting
	if wallpaper then
		self:getSettings()["wallpaper"] = file
	else
		wallpaper = self:getSettings()["wallpaper"]
	end

	-- In this skin the background is make up of multiple images, we compoiste
	-- them here once instead of every time the screen is drawn
	srf = Surface:newRGB(Framework:getScreenSize())
	local bg_image = Surface:loadImage("applets/DefaultSkin/wallpaper/" .. wallpaper)
	local bg_border = Surface:loadImage(imgpath .. "/border.png")
	bg_image:blit(srf, 0, 0)
	bg_border:blit(srf, 0, 0)

	Framework:setBackground(srf)
end


-- define a local function to make it easier to create icons.
local function _icon(var, x, y, img)
	var.x = x
	var.y = y
	var.img = Surface:loadImage(imgpath .. img)
	var.layer = LAYER_FRAME
end


-- returns a closure that can change the menu appearence if it is
-- scrollable.
local function _menuScrollable(value, scrollableValue)
	return function(label)
		local menu = label:getParent()
		if (menu:isScrollable()) then
			return scrollableValue
		else
			return value
		end
	end
end


-- skin
-- The meta arranges for this to be called to skin Jive.
function skin(self)
	local s = jus

	-- display splash screen
	local splashImage = Surface:loadImage(imgpath .. "splash_squeezebox_jive.png")
	local splashWindow = Window("splash")
	splashWindow:addWidget(Icon("splash", splashImage))
	splashWindow:showBriefly(5000, nil,
				 splashWindow.transitionNone,
				 splashWindow.transitionNone)
	Framework:updateScreen()


	-- Iconbar definitions, each icon needs an image and x,y

	-- play/stop/pause
	_icon(s.icon_playmode_off, 9, 290, "icon_mode_off.png")
	_icon(s.icon_playmode_stop, 9, 290, "icon_mode_off.png")
	_icon(s.icon_playmode_play, 9, 290, "icon_mode_play.png")
	_icon(s.icon_playmode_pause, 9, 290, "icon_mode_pause.png")

	-- repeat off/repeat track/repeat playlist
	_icon(s.icon_repeat_off, 41, 290, "icon_repeat_off.png")
	_icon(s.icon_repeat_0, 41, 290, "icon_repeat_off.png")
	_icon(s.icon_repeat_1, 41, 290, "icon_repeat_1.png")
	_icon(s.icon_repeat_2, 41,	290, "icon_repeat_1.png")

	-- shuffle off/shuffle album/shuffle playlist
	_icon(s.icon_shuffle_off, 75, 290, "icon_shuffle_off.png")
	_icon(s.icon_shuffle_0, 75, 290, "icon_shuffle_off.png")
	_icon(s.icon_shuffle_1, 75, 290, "icon_shuffle_1.png")
	_icon(s.icon_shuffle_2, 75, 290, "icon_shuffle_1.png")

	-- time
	s.icon_time.x = 179
	s.icon_time.y = 298
	s.icon_time.layer = LAYER_FRAME
	s.icon_time.font = Font:load(fontpath .. "FreeSansBold.ttf", 12)
	s.icon_time.fg = { 0xff, 0xff, 0xff }


	-- Window background
	self:_setBackground()


	-- Window title, this is a Label
	-- black text with a background image
	s.title.x = 3
	s.title.y = 4
	s.title.w = screenWidth - 3
	s.title.padding = 7
	s.title.paddingRight = 8
	s.title.layer = LAYER_FRAME

	s.title.font = Font:load(fontpath .. "FreeSansBold.ttf", 20)
	s.title.fg = { 0x00, 0x00, 0x00 }
	s.title.bgImg = Surface:loadImage(imgpath .. "titlebox.png")
	s.title.textW = 200


	-- Menu with three basic styles, Unselected, Selected and Loading
	-- First define the dimesions of the menu
	s.menu.x = 3
	s.menu.y = 37
	s.menu.h = 248
	s.menu.w = 234
	s.menu.padding = 2
	s.menu.itemHeight = 27

	-- Menu scrollbar
	s.menu.scrollbar.x = 228
	s.menu.scrollbar.y = 40
	s.menu.scrollbar.w = 18
	s.menu.scrollbar.h = 242
	s.menu.scrollbar.horizontal = 0
	s.menu.scrollbar.bgImg = 
		_menuScrollable(nil,
				Surface:loadImage(imgpath .. "scrollbar_bkground.png")
			)
	s.menu.scrollbar.cap1 = 
		_menuScrollable(nil,
				Surface:loadImage(imgpath .. "scrollbar_bodytop.png")
			)
	s.menu.scrollbar.img = 
		_menuScrollable(nil,
				Surface:loadImage(imgpath .. "scrollbar_bodymid.png")
			)
	s.menu.scrollbar.cap2 = 
		_menuScrollable(nil,
				Surface:loadImage(imgpath .. "scrollbar_bodybottom.png")
			)
	s.menu.scrollbar.layer = LAYER_CONTENT_ON_STAGE
	
	-- Then the menu item styles:
	-- Unselected menu items, white text, no background image
	s.menu.label.w = _menuScrollable(234, 224)
	s.menu.label.h = 27
	s.menu.label.padding = 8
	s.menu.label.textW = 200
	s.menu.label.font = Font:load(fontpath .. "FreeSansBold.ttf", 16)
	s.menu.label.fg = { 0xff, 0xff, 0xff }
	s.menu.label.sh = { 0x00, 0x00, 0x00 }

	-- choice
	s.menu.label.choice.font = Font:load(fontpath .. "FreeSansBold.ttf", 16)
	s.menu.label.choice.fg = { 0xff, 0xff, 0xff }

	-- Selected menu items, black text, background image and icon
	s.menu.selected.label.w = _menuScrollable(234, 224)
	s.menu.selected.label.h = 27
	s.menu.selected.label.padding = 8
	s.menu.selected.label.textW = 200
	s.menu.selected.label.font = Font:load(fontpath .. "FreeSansBold.ttf", 16)
	s.menu.selected.label.fg = { 0x00, 0x00, 0x00 }
	s.menu.selected.label.icon.img = Surface:loadImage(imgpath .. "selection_right.png")
	s.menu.selected.label.bgImg =
		_menuScrollable(
			Surface:loadImage(imgpath .. "menu_selection_box1.png"),
			Surface:loadImage(imgpath .. "menu_selection_box2.png")
		)

	-- choice
	s.menu.selected.label.choice.font = Font:load(fontpath .. "FreeSansBold.ttf", 16)
	s.menu.selected.label.choice.fg = { 0x00, 0x00, 0x00 }

	-- Loading menu items, as selected but with an animated icon
	s.loading.selected.label.w = _menuScrollable(234, 224)
	s.loading.selected.label.h = 27
	s.loading.selected.label.padding = 8
	s.loading.selected.label.textW = 200
	s.loading.selected.label.font = Font:load(fontpath .. "FreeSansBold.ttf", 16)
	s.loading.selected.label.fg = { 0x00, 0x00, 0x00 }
	s.loading.selected.label.icon.img = Surface:loadImage(imgpath .. "selection_wait.png")
	s.loading.selected.label.icon.frameRate = 5
	s.loading.selected.label.icon.frameWidth = 10
	s.loading.selected.label.bgImg = Surface:loadImage(imgpath .. "menu_selection_box1.png")
	s.loading.selected.label.bgImg = 
		_menuScrollable(
			Surface:loadImage(imgpath .. "menu_selection_box1.png"),
			Surface:loadImage(imgpath .. "menu_selection_box2.png")
		)


	-- Text areas
	s.textarea.x = 3
	s.textarea.y = 37
	s.textarea.h = 242
	s.textarea.w = 224
	s.textarea.padding = 8
	s.textarea.font = Font:load(fontpath .. "FreeSans.ttf", 16)
	s.textarea.fg = { 0xFF, 0xFF, 0xFF }
	s.textarea.align = "left"
	
	-- Text area scrollbar
	s.textarea.scrollbar.x = 228
	s.textarea.scrollbar.y = 40
	s.textarea.scrollbar.w = 18
	s.textarea.scrollbar.h = 242
	s.textarea.scrollbar.horizontal = 0
	s.textarea.scrollbar.bgImg = Surface:loadImage(imgpath .. "scrollbar_bkground.png")
	s.textarea.scrollbar.cap1 = Surface:loadImage(imgpath .. "scrollbar_bodytop.png")
	s.textarea.scrollbar.img = Surface:loadImage(imgpath .. "scrollbar_bodymid.png")
	s.textarea.scrollbar.cap2 = Surface:loadImage(imgpath .. "scrollbar_bodybottom.png")
	s.textarea.scrollbar.layer = LAYER_CONTENT_ON_STAGE


	-- Checkbox
	s.checkbox.imgOn = Surface:loadImage(imgpath .. "checkbox_on.png")
	s.checkbox.imgOff = Surface:loadImage(imgpath .. "checkbox_off.png")


	-- Radio button
	s.radio.imgOn = Surface:loadImage(imgpath .. "radiobutton_on.png")
	s.radio.imgOff = Surface:loadImage(imgpath .. "radiobutton_off.png")


	-- Help menu
	s.menuhelp.menu.h = 184
	s.menuhelp.help.x = 3
	s.menuhelp.help.y = 216
	s.menuhelp.help.h = screenHeight - 216
	s.menuhelp.help.w = 234
	s.menuhelp.help.padding = 12
	s.menuhelp.help.font = Font:load(fontpath .. "FreeSans.ttf", 16)
	s.menuhelp.help.fg = { 0xFF, 0xFF, 0xFF }
	s.menuhelp.help.bgImg = Surface:loadImage(imgpath .. "helpbox.png")
	s.menuhelp.help.textAlign = "left"



	-- Special styles for specific window types

	-- Jive Home Window

	-- Here we add an icon to the window title. This uses a function
	-- that is called at runtime, so for example the icon could change
	-- based on time of day
	s["Jive Home"].title.icon.img = 
		function(widget)
			return Surface:loadImage(imgpath .. "icon_home.png")
		end



	-- SlimBrowser applet

	-- Volume popup
	s.volume.popup = true
	s.volume.background.img = Surface:loadImage(imgpath .. "popup_volume_bkgrd.png");

	s.volume.label.x = 39
	s.volume.label.y = 142
	s.volume.label.w = 150
	s.volume.label.h = 20
	s.volume.label.fg = { 0x00, 0x00, 0x00 }
	s.volume.label.font = Font:load(fontpath .. "FreeSans.ttf", 15)
	s.volume.label.textAlign = "center"

	s.volume.slider.x = 37
	s.volume.slider.y = 176
	s.volume.slider.w = 161
	s.volume.slider.h = 20
	s.volume.slider.horizontal = 1
	s.volume.slider.cap1 = Surface:loadImage(imgpath .. "popup_volume_leftbody.png");
	s.volume.slider.img = Surface:loadImage(imgpath .. "popup_volume_midbody.png");
	s.volume.slider.cap2 = Surface:loadImage(imgpath .. "popup_volume_rightbody.png");


	-- Use the style to modify the format for the different menus

	-- Album
	s.slimbrowser.album.menu.format = function(menu, item)
						  local text = item["album"]
						  if item["artist"] then
							  text = text .. "\n" .. item["artist"]
						  end
						  
						  return text
					  end

	-- Browse Albums view have bigger menu items with artwork and smaller text
	s.slimbrowser.album.menu.x = 4
	s.slimbrowser.album.menu.y = 35
	s.slimbrowser.album.menu.h = 248
	s.slimbrowser.album.menu.w = 234
	s.slimbrowser.album.menu.padding = 2
	s.slimbrowser.album.menu.itemHeight = 62
	
	s.slimbrowser.album.menu.label.w = _menuScrollable(234, 224)
	s.slimbrowser.album.menu.label.h = 60
	s.slimbrowser.album.menu.label.padding = 8
	s.slimbrowser.album.menu.label.font = Font:load(fontpath .. "FreeSansBold.ttf", 13)
	s.slimbrowser.album.menu.label.lineHeight = 15
	s.slimbrowser.album.menu.label.icon.img = Surface:loadImage(imgpath .. "menu_album_noartwork.png")
	s.slimbrowser.album.menu.label.textAlign = "top-right"
	s.slimbrowser.album.menu.label.iconAlign = "top-left"
	s.slimbrowser.album.menu.label.textW = 147

	-- Selected items have a background image
	s.slimbrowser.album.menu.selected.label.w = _menuScrollable(234, 224)
	s.slimbrowser.album.menu.selected.label.h = 60
	s.slimbrowser.album.menu.selected.padding = 8
	s.slimbrowser.album.menu.selected.label.font = Font:load(fontpath .. "FreeSansBold.ttf", 13)
	s.slimbrowser.album.menu.selected.label.lineHeight = 15
	s.slimbrowser.album.menu.selected.label.icon.img = Surface:loadImage(imgpath .. "menu_album_noartwork.png")
	s.slimbrowser.album.menu.selected.label.bgImg = 
		_menuScrollable(
			Surface:loadImage(imgpath .. "menu_album_selection_box1.png"),
			Surface:loadImage(imgpath .. "menu_album_selection_box2.png")
		)
	s.slimbrowser.album.menu.selected.label.textAlign = "top-right"
	s.slimbrowser.album.menu.selected.label.iconAlign = "top-left"
	s.slimbrowser.album.menu.selected.label.textW = 147
	
	-- Loading items have an animated icon
	s.slimbrowser.album.loading.selected.label.w = _menuScrollable(234, 224)
	s.slimbrowser.album.loading.selected.label.h = 60
	s.slimbrowser.album.loading.selected.padding = 8
	s.slimbrowser.album.loading.selected.label.font = Font:load(fontpath .. "FreeSansBold.ttf", 13)
	s.slimbrowser.album.loading.selected.label.lineHeight = 15
	s.slimbrowser.album.loading.selected.label.icon.img = Surface:loadImage(imgpath .. "selection_wait.png")
	s.slimbrowser.album.loading.selected.label.icon.frameRate = 5
	s.slimbrowser.album.loading.selected.label.icon.frameWidth = 10
	s.slimbrowser.album.loading.selected.label.bgImg = 
		_menuScrollable(
			Surface:loadImage(imgpath .. "menu_album_selection_box1.png"),
			Surface:loadImage(imgpath .. "menu_album_selection_box2.png")
		)
	s.slimbrowser.album.loading.selected.label.textAlign = "top-right"
	s.slimbrowser.album.loading.selected.label.iconAlign = "top-left"
	s.slimbrowser.album.loading.selected.label.textW = 147

	-- Now Playing
	s.slimbrowser.status.menu.format = function(menu, item)
						  local text = item["title"]
						  if item["album"] then
							  text = text .. "\n" .. item["album"]
						  end
						  if item["artist"] then
							  text = text .. "\n" .. item["artist"]
						  end

						  return text
					  end

	-- Status view have bigger menu items with artwork and smaller text
	s.slimbrowser.status.menu.x = 4
	s.slimbrowser.status.menu.y = 35
	s.slimbrowser.status.menu.h = 248
	s.slimbrowser.status.menu.w = 234
	s.slimbrowser.status.menu.padding = 2
	s.slimbrowser.status.menu.itemHeight = 62

	s.slimbrowser.status.menu.label.w = _menuScrollable(234, 224)
	s.slimbrowser.status.menu.label.h = 60
	s.slimbrowser.status.menu.label.padding = 8
	s.slimbrowser.status.menu.label.font = Font:load(fontpath .. "FreeSans.ttf", 13)
	s.slimbrowser.status.menu.label.icon.img = Surface:loadImage(imgpath .. "menu_album_noartwork.png")
	s.slimbrowser.status.menu.label.lineHeight = 15
	s.slimbrowser.status.menu.label.textAlign = "top-right"
	s.slimbrowser.status.menu.label.iconAlign = "top-left"
	s.slimbrowser.status.menu.label.textW = 147

	-- Selected items have a background image
	s.slimbrowser.status.menu.selected.label.w = _menuScrollable(234, 224)
	s.slimbrowser.status.menu.selected.label.h = 60
	s.slimbrowser.status.menu.selected.padding = 8
	s.slimbrowser.status.menu.selected.label.font = Font:load(fontpath .. "FreeSans.ttf", 13)
	s.slimbrowser.status.menu.selected.label.icon.img = Surface:loadImage(imgpath .. "menu_album_noartwork.png")
	s.slimbrowser.status.menu.selected.label.lineHeight = 15
	s.slimbrowser.status.menu.selected.label.bgImg = 
		_menuScrollable(
			Surface:loadImage(imgpath .. "menu_album_selection_box1.png"),
			Surface:loadImage(imgpath .. "menu_album_selection_box2.png")
		)
	s.slimbrowser.status.menu.selected.label.textAlign = "top-right"
	s.slimbrowser.status.menu.selected.label.iconAlign = "top-left"
	s.slimbrowser.status.menu.selected.label.textW = 147

	-- Current item is different
	s.slimbrowser.status.current.label.w = _menuScrollable(234, 224)
	s.slimbrowser.status.current.label.h = 60
	s.slimbrowser.status.current.label.padding = 8
	s.slimbrowser.status.current.label.font = Font:load(fontpath .. "FreeSansBold.ttf", 13)
	s.slimbrowser.status.current.label.lineHeight = 15
	s.slimbrowser.status.current.label.textAlign = "top-right"
	s.slimbrowser.status.current.label.iconAlign = "top-left"
	s.slimbrowser.status.current.label.textW = 147

	-- Current selected is also different
	s.slimbrowser.status.current.selected.label.w = _menuScrollable(234, 224)
	s.slimbrowser.status.current.selected.label.h = 60
	s.slimbrowser.status.current.selected.label.padding = 8
	s.slimbrowser.status.current.selected.label.font = Font:load(fontpath .. "FreeSansBold.ttf", 13)
	s.slimbrowser.status.current.selected.label.icon.img = Surface:loadImage(imgpath .. "menu_album_noartwork.png")
	s.slimbrowser.status.current.selected.label.lineHeight = 15
	s.slimbrowser.status.current.selected.label.bgImg = 
		_menuScrollable(
			Surface:loadImage(imgpath .. "menu_album_selection_box1.png"),
			Surface:loadImage(imgpath .. "menu_album_selection_box2.png")
		)
	s.slimbrowser.status.current.selected.label.textAlign = "top-right"
	s.slimbrowser.status.current.selected.label.iconAlign = "top-left"
	s.slimbrowser.status.current.selected.label.textW = 147
	


	-- Flickr applet
	s.flickr.font = Font:load(fontpath .. "FreeSans.ttf", 10)
	
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

