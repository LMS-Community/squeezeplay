
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
local Audio                  = require("jive.ui.Audio")
local Font                   = require("jive.ui.Font")
local Framework              = require("jive.ui.Framework")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local RadioButton            = require("jive.ui.RadioButton")
local RadioGroup             = require("jive.ui.RadioGroup")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Surface                = require("jive.ui.Surface")
local Textarea               = require("jive.ui.Textarea")
local Tile                   = require("jive.ui.Tile")
local Window                 = require("jive.ui.Window")

local table                  = require("jive.utils.table")
local debug                  = require("jive.utils.debug")
local autotable              = require("jive.utils.autotable")

local EVENT_ACTION           = jive.ui.EVENT_ACTION
local EVENT_CONSUME          = jive.ui.EVENT_CONSUME
local EVENT_WINDOW_POP       = jive.ui.EVENT_WINDOW_POP
local LAYER_FRAME            = jive.ui.LAYER_FRAME
local LAYER_CONTENT_ON_STAGE = jive.ui.LAYER_CONTENT_ON_STAGE

local LAYOUT_NORTH           = jive.ui.LAYOUT_NORTH
local LAYOUT_EAST            = jive.ui.LAYOUT_EAST
local LAYOUT_SOUTH           = jive.ui.LAYOUT_SOUTH
local LAYOUT_WEST            = jive.ui.LAYOUT_WEST
local LAYOUT_CENTER          = jive.ui.LAYOUT_CENTER
local LAYOUT_NONE            = jive.ui.LAYOUT_NONE

local appletManager          = appletManager


local print = print

module(...)
oo.class(_M, Applet)


-- Define useful variables for this skin
local imgpath = "applets/DefaultSkin/images/"
local sndpath = "applets/DefaultSkin/sounds/"
local fontpath = "fonts/"

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
		wallpaper = "Chapple_1.jpg",
	}
end


-- wallpaperSettings
-- The meta hooks this function to allow the user to select
-- a wallpaper
function wallpaperSetting(self, menuItem)
	local window = Window(self:displayName(), menuItem.text)
	local menu = SimpleMenu("menu")
	window:addWidget(menu)

	local wallpaper = self:getSettings()["wallpaper"]
	
	local group = RadioGroup()
	
	for name, file in table.pairsByKeys(wallpapers) do
		menu:addItem({
				     text = name, 
				     icon = RadioButton("radio", 
							group, 
							function()
								self:_setBackground(file)
							end,
							wallpaper == file
						)
			     })
	end

	menu:addItem({
			     text = "License",
			     callback = function()
						local window = Window("window", "License")
						window:addWidget(Textarea("textarea", backgroundLicense))
						window:show()
					end
		     })

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
		self:getSettings()["wallpaper"] = wallpaper
	else
		wallpaper = self:getSettings()["wallpaper"]
	end

	-- In this skin the background is make up of multiple images, we compoiste
	-- them here once instead of every time the screen is drawn
	local sw, sh = Framework:getScreenSize()
	srf = Surface:newRGB(sw, sh)
	local bgImage = Tile:loadImage("applets/DefaultSkin/wallpaper/" .. wallpaper)
	local iconBar =
		Tile:loadHTiles({
				       imgpath .. "border_l.png",
				       imgpath .. "border.png",
				       imgpath .. "border_r.png",
			       })

	local iw,ih = iconBar:getMinSize()

	srf:filledRectangle(0, 0, sw, sh, 0x000000FF);
	bgImage:blit(srf, 0, 0, sw, sh)
	iconBar:blit(srf, 0, sh-ih, sw, sh)

	Framework:setBackground(srf)
end


-- define a local function to make it easier to create icons.
local function _icon(var, x, y, img)
	var.x = x
	var.y = y
	var.img = Surface:loadImage(imgpath .. img)
	var.layer = LAYER_FRAME
	var.position = LAYOUT_SOUTH
end


-- splash screen
function splash(self)

	local splashImage = Surface:loadImage(imgpath .. "splash_squeezebox_jive.png")
	local splashWindow = Window("splash")
	splashWindow:addWidget(Icon("splash", splashImage))
	splashWindow:showBriefly(5000, nil,
				 splashWindow.transitionNone,
				 splashWindow.transitionNone)
	Framework:updateScreen()

	Audio:loadSound(sndpath .. "startup.wav", 1):play()
end


-- skin
-- The meta arranges for this to be called to skin Jive.
function skin(self, s)
	local screenWidth, screenHeight = Framework:getScreenSize()

	-- Sounds
	Framework:loadSound("BUMP", sndpath .. "bump.wav", 1)
	Framework:loadSound("CLICK", sndpath .. "click.wav", 0)
	Framework:loadSound("JUMP", sndpath .. "jump.wav", 0)
	Framework:loadSound("PUSHLEFT", sndpath .. "pushleft.wav", 1)
	Framework:loadSound("PUSHRIGHT", sndpath .. "pushright.wav", 1)
	Framework:loadSound("SELECT", sndpath .. "select.wav", 0)

	-- Images and Tiles
	local titleBox =
		Tile:loadTiles({
				       imgpath .. "titlebox.png",
				       imgpath .. "titlebox_tl.png",
				       imgpath .. "titlebox_t.png",
				       imgpath .. "titlebox_tr.png",
				       imgpath .. "titlebox_r.png",
				       imgpath .. "titlebox_br.png",
				       imgpath .. "titlebox_b.png",
				       imgpath .. "titlebox_bl.png",
				       imgpath .. "titlebox_l.png"
			       })

	local selectionBox =
		Tile:loadTiles({
				       imgpath .. "menu_selection_box.png",
				       imgpath .. "menu_selection_box_tl.png",
				       imgpath .. "menu_selection_box_t.png",
				       imgpath .. "menu_selection_box_tr.png",
				       imgpath .. "menu_selection_box_r.png",
				       imgpath .. "menu_selection_box_br.png",
				       imgpath .. "menu_selection_box_b.png",
				       imgpath .. "menu_selection_box_bl.png",
				       imgpath .. "menu_selection_box_l.png"
			       })

	local helpBox = 
		Tile:loadTiles({
				       imgpath .. "helpbox.png",
				       imgpath .. "helpbox_tl.png",
				       imgpath .. "helpbox_t.png",
				       imgpath .. "helpbox_tr.png",
				       imgpath .. "helpbox_r.png",
				       nil,
				       nil,
				       nil,
				       imgpath .. "helpbox_l.png",
			       })

	local scrollBackground =
		Tile:loadVTiles({
					imgpath .. "scrollbar_bkgroundtop.png",
					imgpath .. "scrollbar_bkgroundmid.png",
					imgpath .. "scrollbar_bkgroundbottom.png",
				})

	local scrollBar = 
		Tile:loadVTiles({
					imgpath .. "scrollbar_bodytop.png",
					imgpath .. "scrollbar_bodymid.png",
					imgpath .. "scrollbar_bodybottom.png",
			       })

	local sliderBackground = 
		Tile:loadHTiles({
					imgpath .. "slider_bkgrd_l.png",
					imgpath .. "slider_bkgrd.png",
					imgpath .. "slider_bkgrd_r.png",
			       })

	local sliderBar = 
		Tile:loadHTiles({
					imgpath .. "slider_fill_l.png",
					imgpath .. "slider_fill.png",
					imgpath .. "slider_fill_r.png",
			       })

	local volumeBar = 
		Tile:loadHTiles({
					imgpath .. "popup_volume_leftbody.png",
					imgpath .. "popup_volume_midbody.png",
					imgpath .. "popup_volume_rightbody.png",
			       })

	local volumeBackground = 
		Tile:loadHTiles({
					imgpath .. "popup_volume_bkground_l.png",
					imgpath .. "popup_volume_bkground.png",
					imgpath .. "popup_volume_bkground_r.png",
			       })

	local popupMask = Tile:fillColor(0x231f20e5)

	local popupBox =
		Tile:loadTiles({
				       imgpath .. "popupbox.png",
				       imgpath .. "popupbox_tl.png",
				       imgpath .. "popupbox_t.png",
				       imgpath .. "popupbox_tr.png",
				       imgpath .. "popupbox_r.png",
				       imgpath .. "popupbox_br.png",
				       imgpath .. "popupbox_b.png",
				       imgpath .. "popupbox_bl.png",
				       imgpath .. "popupbox_l.png"
			       })


	local textinputBackground =
		Tile:loadHTiles({
				       imgpath .. "text_entry_bkgrd_l.png",
				       imgpath .. "text_entry_bkgrd.png",
				       imgpath .. "text_entry_bkgrd_r.png",
			       })

	local textinputWheel = Tile:loadImage(imgpath .. "text_entry_select.png")

	local textinputCursor = Tile:loadImage(imgpath .. "text_entry_letter.png")


	-- Iconbar definitions, each icon needs an image and x,y

	-- play/stop/pause
	_icon(s.icon_playmode_off, 9, screenHeight - 30, "icon_mode_off.png")
	_icon(s.icon_playmode_stop, 9, screenHeight - 30, "icon_mode_off.png")
	_icon(s.icon_playmode_play, 9, screenHeight - 30, "icon_mode_play.png")
	_icon(s.icon_playmode_pause, 9, screenHeight - 30, "icon_mode_pause.png")

	-- repeat off/repeat track/repeat playlist
	_icon(s.icon_repeat_off, 41, screenHeight - 30, "icon_repeat_off.png")
	_icon(s.icon_repeat_0, 41, screenHeight - 30, "icon_repeat_off.png")
	_icon(s.icon_repeat_1, 41, screenHeight - 30, "icon_repeat_1.png")
	_icon(s.icon_repeat_2, 41, screenHeight - 30, "icon_repeat_1.png")

	-- shuffle off/shuffle album/shuffle playlist
	_icon(s.icon_shuffle_off, 75, screenHeight - 30, "icon_shuffle_off.png")
	_icon(s.icon_shuffle_0, 75, screenHeight - 30, "icon_shuffle_off.png")
	_icon(s.icon_shuffle_1, 75, screenHeight - 30, "icon_shuffle_1.png")
	_icon(s.icon_shuffle_2, 75, screenHeight - 30, "icon_shuffle_1.png")

	-- time
	s.icon_time.x = screenWidth - 60
	s.icon_time.y = screenHeight - 34
	s.icon_time.h = 34
	s.icon_time.layer = LAYER_FRAME
	s.icon_time.position = LAYOUT_SOUTH
	s.icon_time.font = Font:load(fontpath .. "FreeSansBold.ttf", 12)
	s.icon_time.fg = { 0xe7, 0xe7, 0xe7 }


	-- Window background
	self:_setBackground()


	-- Window title, this is a Label
	-- black text with a background image
	s.title.border = 4
	s.title.padding = { 10, 7, 8, 9 }
	s.title.position = LAYOUT_NORTH

	s.title.font = Font:load(fontpath .. "FreeSansBold.ttf", 20)
	s.title.fg = { 0x37, 0x37, 0x37 }
	s.title.bgImg = titleBox


	-- Menu with three basic styles: normal, selected and locked
	-- First define the dimesions of the menu
	s.menu.padding = { 4, 0, 4, 4 }
	s.menu.itemHeight = 27

	-- menu item
	s.item.padding = 10
	s.item.textW = screenWidth - 40
	s.item.font = Font:load(fontpath .. "FreeSansBold.ttf", 16)
	s.item.fg = { 0xe7, 0xe7, 0xe7 }
	s.item.sh = { 0x37, 0x37, 0x37 }
	--s.item.bgImg = selectionBox

	s.current.padding = 10
	s.current.textW = screenWidth - 40
	s.current.font = Font:load(fontpath .. "FreeSansBold.ttf", 18)
	s.current.fg = { 0xe7, 0xe7, 0xe7 }
	s.current.sh = { 0xaa, 0xaa, 0xaa }

	-- selected menu item
	s.selected.item.fg = { 0x37, 0x37, 0x37 }
	s.selected.item.sh = { }
	s.selected.item.bgImg = selectionBox
	s.selected.item.icon.img = Surface:loadImage(imgpath .. "selection_right.png")

	s.selected.current.fg = { 0x37, 0x37, 0x37 }
	s.selected.current.sh = { }
	s.selected.current.bgImg = selectionBox
	s.selected.current.icon.img = Surface:loadImage(imgpath .. "selection_right.png")

	-- locked menu item (with loading animation)
	s.locked.item.fg = { 0x37, 0x37, 0x37 }
	s.locked.item.sh = { }
	s.locked.item.bgImg = selectionBox
	s.locked.item.icon.img = Surface:loadImage(imgpath .. "selection_wait.png")
	s.locked.item.icon.frameRate = 5
	s.locked.item.icon.frameWidth = 10


	-- menu item choice
	s.item.choice.font = Font:load(fontpath .. "FreeSansBold.ttf", 16)
	s.item.choice.fg = { 0xe7, 0xe7, 0xe7 }
	s.item.choice.sh = { 0x37, 0x37, 0x37 }

	-- selected menu item choice
	s.selected.item.choice.fg = { 0x37, 0x37, 0x37 }
	s.selected.item.choice.sh = { }

	-- menu value choice
	s.item.value.font = Font:load(fontpath .. "FreeSansBold.ttf", 16)
	s.item.value.fg = { 0xe7, 0xe7, 0xe7 }
	s.item.value.sh = { 0x37, 0x37, 0x37 }

	-- selected menu item choice
	s.selected.item.value.fg = { 0x37, 0x37, 0x37 }
	s.selected.item.value.sh = { }

	-- Text areas
	s.textarea.w = screenWidth - 21
	s.textarea.padding = { 13, 8, 8, 8 }
	s.textarea.font = Font:load(fontpath .. "FreeSans.ttf", 16)
	s.textarea.fg = { 0xe7, 0xe7, 0xe7 }
	s.textarea.sh = { 0x37, 0x37, 0x37 }
	s.textarea.align = "left"
	

	-- Scrollbar
	s.scrollbar.w = 8
	s.scrollbar.padding = { 2, 0, 0, 0 }
	s.scrollbar.horizontal = 0
	s.scrollbar.bgImg = scrollBackground
	s.scrollbar.img = scrollBar
	s.scrollbar.layer = LAYER_CONTENT_ON_STAGE


	-- Checkbox
	s.checkbox.imgOn = Surface:loadImage(imgpath .. "checkbox_on.png")
	s.checkbox.imgOff = Surface:loadImage(imgpath .. "checkbox_off.png")


	-- Radio button
	s.radio.imgOn = Surface:loadImage(imgpath .. "radiobutton_on.png")
	s.radio.imgOff = Surface:loadImage(imgpath .. "radiobutton_off.png")


	-- Slider
	s.slider.border = 5
	s.slider.horizontal = 1
	s.slider.bgImg = sliderBackground
	s.slider.img = sliderBar


	-- Text input
	s.textinput.border = { 8, -5, 8, 0 }
	s.textinput.padding = { 6, 0, 6, 0 }
	s.textinput.font = Font:load(fontpath .. "FreeSansBold.ttf", 16)
	s.textinput.charWidth = 19
	s.textinput.charHeight = 26
	s.textinput.fg = { 0x37, 0x37, 0x37 }
	s.textinput.wh = { 0x55, 0x55, 0x55, 0xB2 }
	s.textinput.bgImg = textinputBackground
	s.textinput.wheelImg = textinputWheel
	s.textinput.cursorImg = textinputCursor
	s.textinput.enterImg = Tile:loadImage(imgpath .. "selection_right.png")

	-- Help menu
	s.help.w = screenWidth - 6
	s.help.position = LAYOUT_SOUTH
	s.help.padding = 12
	s.help.font = Font:load(fontpath .. "FreeSans.ttf", 16)
	s.help.fg = { 0xe7, 0xe7, 0xe7 }
	s.help.bgImg = helpBox
	s.help.textAlign = "left"
	s.help.scrollbar.w = 0


	s.window.w = screenWidth
	s.window.h = screenHeight

	-- Popup window
	s.popup.border = { 13, 0, 13, 0 }
	s.popup.popup = true
	s.popup.bgImg = popupBox
	s.popup.maskImg = popupMask

	s.popup.title.border = 2
	s.popup.title.padding = { 13, 13, 13, 13 }
	s.popup.title.font = Font:load(fontpath .. "FreeSansBold.ttf", 14)
	s.popup.title.textAlign = "center"
	s.popup.title.bgImg = false

	s.popup.text.border = 10
	s.popup.text.w = screenWidth - 60
	s.popup.text.fg = { 0x37, 0x37, 0x37 }
	s.popup.text.sh = { }
	s.popup.text.textAlign = "center"

	s.popup.textarea.w = screenWidth - 60
	s.popup.textarea.fg = { 0x37, 0x37, 0x37 }
	s.popup.textarea.sh = { }

	s.popup.slider.border = { 15, 0, 15, 15 }
	s.popup.slider.horizontal = 1
	s.popup.slider.img = volumeBar
	s.popup.slider.bgImg = volumeBackground


	-- Special styles for specific window types

	-- No layout for the splash screen
	s.splash.layout = Window.noLayout


	-- Jive Home Window

	-- Here we add an icon to the window title. This uses a function
	-- that is called at runtime, so for example the icon could change
	-- based on time of day
	s.home.window.title.icon.img = 
		function(widget)
			return Surface:loadImage(imgpath .. "icon_home.png")
		end



	-- SlimBrowser applet

	s.iconVolumeMin.img = Surface:loadImage(imgpath .. "icon_volume_min.png")
	s.iconVolumeMin.position = LAYOUT_NONE
	s.iconVolumeMin.x = 10
	s.iconVolumeMin.y = 40

	s.iconVolumeMax.img = Surface:loadImage(imgpath .. "icon_volume_max.png")
	s.iconVolumeMax.position = LAYOUT_NONE
	s.iconVolumeMax.x = 185
	s.iconVolumeMax.y = 40

	s.volume.x = 25
	s.volume.w = 156
	s.volume.border = { 30, 0, 35, 25 }
	s.volume.horizontal = 1
	s.volume.img = volumeBar
	s.volume.bgImg = volumeBackground


	-- titles with artwork and song info
	s.albumtitle.w = screenWidth
	s.albumtitle.h = 60
	s.albumtitle.border = 4
	s.albumtitle.padding = { 10, 8, 8, 9 }
	s.albumtitle.textW = screenWidth - 86
	s.albumtitle.font = Font:load(fontpath .. "FreeSansBold.ttf", 14)
	s.albumtitle.fg = { 0x37, 0x37, 0x37 }
	s.albumtitle.bgImg = titleBox
	s.albumtitle.textAlign = "top-right"
	s.albumtitle.iconAlign = "left"
	s.albumtitle.position = LAYOUT_NORTH
	s.albumtitle.icon.img = Surface:loadImage(imgpath .. "menu_album_noartwork.png")


	-- menus with artwork and song info
	s.albummenu.padding = 2
	s.albummenu.itemHeight = 61


	-- items with artwork and song info
	s.albumitem.h = 60
	s.albumitem.padding = { 12, 8, 8, 8 }
	s.albumitem.textW = screenWidth - 93
	s.albumitem.font = Font:load(fontpath .. "FreeSansBold.ttf", 13)
	s.albumitem.fg = { 0xe7, 0xe7, 0xe7 }
	s.albumitem.sh = { 0x37, 0x37, 0x37 }
	s.albumitem.icon.img = Surface:loadImage(imgpath .. "menu_album_noartwork.png")
	s.albumitem.textAlign = "top-right"
	s.albumitem.iconAlign = "left"


	-- selected item with artwork and song info
	s.selected.albumitem.fg = { 0x37, 0x37, 0x37 }
	s.selected.albumitem.sh = { }
	s.selected.albumitem.bgImg = selectionBox


	-- locked item with artwork and song info
	s.locked.albumitem.fg = { 0x37, 0x37, 0x37 }
	s.locked.albumitem.sh = { }
	s.locked.albumitem.bgImg = selectionBox


	-- now playing menu item
	s.albumcurrent.padding = 10
	s.albumcurrent.textW = screenWidth - 93
	s.albumcurrent.font = Font:load(fontpath .. "FreeSansBold.ttf", 15)
	s.albumcurrent.fg = { 0xe7, 0xe7, 0xe7 }
	s.albumcurrent.sh = { 0xaa, 0xaa, 0xaa }
	s.albumcurrent.textAlign = "top-right"
	s.albumcurrent.iconAlign = "left"


	-- selected now playing menu item
	s.selected.albumcurrent.fg = { 0x37, 0x37, 0x37 }
	s.selected.albumcurrent.sh = { 0x33, 0x33, 0x33 }
	s.selected.albumcurrent.sh = { }
	s.selected.albumcurrent.bgImg = selectionBox
	s.selected.albumcurrent.icon.img = Surface:loadImage(imgpath .. "selection_right.png")


	-- locked now playing menu item (with loading animation)
	s.locked.albumcurrent.fg = { 0x37, 0x37, 0x37 }
	s.locked.albumcurrent.sh = { 0xaa, 0xaa, 0xaa }
	s.locked.albumcurrent.sh = { }
	s.locked.albumcurrent.bgImg = selectionBox
	s.locked.albumcurrent.icon.img = Surface:loadImage(imgpath .. "selection_wait.png")
	s.locked.albumcurrent.icon.frameRate = 5
	s.locked.albumcurrent.icon.frameWidth = 10




	-- XXXX top and status styles defined using album and standard styles
	-- are these style needed?
	s.toptitle = s.albumtitle
	s.statustitle = s.title

	s.topmenu = s.menu
	s.statusmenu = s.albummenu

	s.topitem = s.item
	s.selected.topitem = s.selected.item
	s.locked.topitem = s.locked.item

	s.statusitem = s.albumitem
	s.selected.statusitem = s.selected.albumitem
	s.locked.statusitem = s.locked.albumitem

end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

