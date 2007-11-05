
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
local ipairs, pairs, setmetatable = ipairs, pairs, setmetatable

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

local log = require("jive.utils.log").logger("ui")

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

local WH_FILL                = jive.ui.WH_FILL

local appletManager          = appletManager


module(...)
oo.class(_M, Applet)


-- Define useful variables for this skin
local imgpath = "applets/DefaultSkin/images/"
local sndpath = "applets/DefaultSkin/sounds/"
local fontpath = "fonts/"

-- define a local function to make it easier to create icons.
local function _icon(var, x, y, img)
	var.x = x
	var.y = y
	var.img = Surface:loadImage(imgpath .. img)
	var.layer = LAYER_FRAME
	var.position = LAYOUT_SOUTH
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
	Framework:loadSound("DOCKING", sndpath .. "docking.wav", 1)

	-- Images and Tiles
	local iconBackground = 
		Tile:loadHTiles({
					imgpath .. "border_l.png",
					imgpath .. "border.png",
					imgpath .. "border_r.png",
			       })

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

	local albumSelectionBox =
		Tile:loadTiles({
				       imgpath .. "menu_album_selection.png",
				       imgpath .. "menu_album_selection_tl.png",
				       imgpath .. "menu_album_selection_t.png",
				       imgpath .. "menu_album_selection_tr.png",
				       imgpath .. "menu_album_selection_r.png",
				       imgpath .. "menu_album_selection_br.png",
				       imgpath .. "menu_album_selection_b.png",
				       imgpath .. "menu_album_selection_bl.png",
				       imgpath .. "menu_album_selection_l.png"
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
					imgpath .. "volume_fill_l.png",
					imgpath .. "volume_fill.png",
					imgpath .. "volume_fill_r.png",
				})

	local volumeBackground =
		Tile:loadHTiles({
					imgpath .. "volume_bkgrd_l.png",
					imgpath .. "volume_bkgrd.png",
					imgpath .. "volume_bkgrd_r.png",
			       })

	local popupMask = Tile:fillColor(0x231f20f7)

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

	local softButtonBackground =
		Tile:loadTiles({
				       imgpath .. "button.png",
				       imgpath .. "button_tl.png",
				       imgpath .. "button_t.png",
				       imgpath .. "button_tr.png",
				       imgpath .. "button_r.png",
				       imgpath .. "button_br.png",
				       imgpath .. "button_b.png",
				       imgpath .. "button_bl.png",
				       imgpath .. "button_l.png"
				})

	local textinputWheel = Tile:loadImage(imgpath .. "text_entry_select.png")

	local textinputCursor = Tile:loadImage(imgpath .. "text_entry_letter.png")


	local TEXT_COLOR = { 0xE7, 0xE7, 0xE7 }
	local TEXT_SH_COLOR = { 0x37, 0x37, 0x37 }

	local SELECT_COLOR = { 0x00, 0x00, 0x00 }
	local SELECT_SH_COLOR = { }

	local FONT_13px = Font:load(fontpath .. "FreeSans.ttf", 14)
	local FONT_15px = Font:load(fontpath .. "FreeSans.ttf", 16)

	local FONT_BOLD_13px = Font:load(fontpath .. "FreeSansBold.ttf", 14)
	local FONT_BOLD_15px = Font:load(fontpath .. "FreeSansBold.ttf", 16)
	local FONT_BOLD_18px = Font:load(fontpath .. "FreeSansBold.ttf", 20)
	local FONT_BOLD_20px = Font:load(fontpath .. "FreeSansBold.ttf", 22)
	local FONT_BOLD_22px = Font:load(fontpath .. "FreeSansBold.ttf", 24)

--				left, top, right, bottom
	local MINI_ICON_PADDING = { 0, 0, 4, 0 }
	local MINI_ICON_TEXT_PADDING= { 10, 7, 0, 9 }
	local MINI_ICON_TEXT_ALIGN = 'top-left'
	local MINI_ICON_TITLE_BORDER = 4
	local MINI_ICON_ITEM_ORDER = { "text", "icon" }
	local MINI_ICON_ICON_ALIGN = 'right'

	-- Iconbar definitions, each icon needs an image and x,y
	s.icon_background.x = 0
	s.icon_background.y = screenHeight - 30
	s.icon_background.w = screenWidth
	s.icon_background.h = 30
	s.icon_background.border = { 4, 0, 4, 0 }
	s.icon_background.bgImg = iconBackground
	s.icon_background.layer = LAYER_FRAME
	s.icon_background.position = LAYOUT_SOUTH

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


	-- wireless status
	_icon(s.iconWireless1, 107, screenHeight - 30, "icon_wireless_2.png")
	_icon(s.iconWireless2, 107, screenHeight - 30, "icon_wireless_3.png")
	_icon(s.iconWireless3, 107, screenHeight - 30, "icon_wireless_4.png")
	_icon(s.iconWirelessOff, 107, screenHeight - 30, "icon_wireless_off.png")

	-- battery status
	_icon(s.iconBatteryAC, 137, screenHeight - 30, "icon_battery_ac.png")

	_icon(s.iconBatteryCharging, 137, screenHeight - 30, "icon_battery_charging.png")
	_icon(s.iconBattery0, 137, screenHeight - 30, "icon_battery_0.png")
	_icon(s.iconBattery1, 137, screenHeight - 30, "icon_battery_1.png")
	_icon(s.iconBattery2, 137, screenHeight - 30, "icon_battery_2.png")
	_icon(s.iconBattery3, 137, screenHeight - 30, "icon_battery_3.png")
	_icon(s.iconBattery4, 137, screenHeight - 30, "icon_battery_4.png")

	s.iconBatteryCharging.frameRate = 1
	s.iconBatteryCharging.frameWidth = 37


	-- time
	s.icon_time.x = screenWidth - 60
	s.icon_time.y = screenHeight - 34
	s.icon_time.h = 34
	s.icon_time.layer = LAYER_FRAME
	s.icon_time.position = LAYOUT_SOUTH
	s.icon_time.font = Font:load(fontpath .. "FreeSansBold.ttf", 12)
	s.icon_time.fg = TEXT_COLOR


	-- Window title, this is a Label
	-- black text with a background image
	s.title.border = 4
	s.title.position = LAYOUT_NORTH
	s.title.bgImg = titleBox
	s.title.text.padding = { 10, 7, 8, 9 }
	s.title.text.align = "top-left"
	s.title.text.font = FONT_BOLD_18px
	s.title.text.fg = SELECT_COLOR


	-- Menu with three basic styles: normal, selected and locked
	-- First define the dimesions of the menu
	s.menu.padding = { 4, 0, 4, 4 }
	s.menu.itemHeight = 27

	-- menu item
	s.item.order = { "text", "icon" }
	s.item.padding = { 9, 6, 6, 6 }
	s.item.text.w = WH_FILL
	s.item.text.font = FONT_BOLD_15px
	s.item.text.fg = TEXT_COLOR
	s.item.text.sh = TEXT_SH_COLOR

	-- menu item
	s.itemNoAction.order = { "text", "icon" }
	s.itemNoAction.padding =  { 9, 6, 6, 6 }
	s.itemNoAction.text.w = WH_FILL
	s.itemNoAction.text.font = FONT_BOLD_15px
	s.itemNoAction.text.fg = TEXT_COLOR
	s.itemNoAction.text.sh = TEXT_SH_COLOR

	--s.item.bgImg = selectionBox

	s.checked.order = { "text", "check", "icon" }
	s.checked.padding = { 9, 6, 6, 6 }
	s.checked.text.w = WH_FILL
	s.checked.text.font = FONT_BOLD_15px
	s.checked.text.fg = TEXT_COLOR
	s.checked.text.sh = TEXT_SH_COLOR
	s.checked.check.img = Surface:loadImage(imgpath .. "menu_nowplaying.png") -- FIXME
	s.checked.check.align = "right"

	-- selected menu item
	s.selected.item.bgImg = selectionBox
	s.selected.item.text.font = FONT_BOLD_15px
	s.selected.item.text.fg = SELECT_COLOR
	s.selected.item.text.sh = SELECT_SH_COLOR
	s.selected.item.icon.padding = { 4, 0, 0, 0 }
	s.selected.item.icon.align = "right"
	s.selected.item.icon.img = Surface:loadImage(imgpath .. "selection_right.png")

	s.selected.checked.bgImg = selectionBox
	s.selected.checked.text.font = FONT_BOLD_15px
	s.selected.checked.text.fg = SELECT_COLOR
	s.selected.checked.text.sh = SELECT_SH_COLOR
	s.selected.checked.icon.padding = { 4, 0, 0, 0 }
	s.selected.checked.icon.align = "right"
	s.selected.checked.icon.img = Surface:loadImage(imgpath .. "selection_right.png")
	s.selected.checked.check.align = "right"
	s.selected.checked.check.img = Surface:loadImage(imgpath .. "menu_nowplaying_selected.png") -- FIXME

	s.selected.itemNoAction.bgImg = selectionBox
	s.selected.itemNoAction.text.font = FONT_BOLD_15px
	s.selected.itemNoAction.text.fg = SELECT_COLOR
	s.selected.itemNoAction.text.sh = SELECT_SH_COLOR

	-- locked menu item (with loading animation)
	s.locked.item.bgImg = selectionBox
	s.locked.item.text.font = FONT_BOLD_15px
	s.locked.item.text.fg = SELECT_COLOR
	s.locked.item.text.sh = SELECT_SH_COLOR
	s.locked.item.icon.img = Surface:loadImage(imgpath .. "selection_wait.png")
	s.locked.item.icon.align = "right"
	s.locked.item.icon.frameRate = 5
	s.locked.item.icon.frameWidth = 10


	-- menu item choice
	s.item.choice.font = FONT_BOLD_15px
	s.item.choice.fg = TEXT_COLOR
	s.item.choice.sh = TEXT_SH_COLOR
	s.item.choice.padding = { 8, 0, 0, 0 }


	-- menu item choice
	s.itemNoAction.choice.font = FONT_BOLD_15px
	s.itemNoAction.choice.fg = TEXT_COLOR
	s.itemNoAction.choice.sh = TEXT_SH_COLOR
	s.itemNoAction.choice.padding = { 8, 0, 0, 0 }

	-- selected menu item choice
	s.selected.item.choice.font = FONT_BOLD_15px
	s.selected.item.choice.fg = SELECT_COLOR
	s.selected.item.choice.sh = SELECT_SH_COLOR

	-- menu value choice
	s.item.value.font = FONT_BOLD_15px
	s.item.value.fg = TEXT_COLOR
	s.item.value.sh = TEXT_SH_COLOR

	-- selected menu item choice
	s.selected.item.value.font = FONT_BOLD_15px
	s.selected.item.value.fg = SELECT_COLOR
	s.selected.item.value.sh = SELECT_SH_COLOR

	-- Text areas
	s.textarea.w = screenWidth
	s.textarea.padding = { 13, 8, 8, 8 }
	s.textarea.font = FONT_BOLD_15px
	s.textarea.fg = TEXT_COLOR
	s.textarea.sh = TEXT_SH_COLOR
	s.textarea.align = "left"
	

	-- Scrollbar
	s.scrollbar.w = 9
	s.scrollbar.border = { 4, 0, 0, 0 }
	s.scrollbar.horizontal = 0
	s.scrollbar.bgImg = scrollBackground
	s.scrollbar.img = scrollBar
	s.scrollbar.layer = LAYER_CONTENT_ON_STAGE


	-- Checkbox
	s.checkbox.imgOn = Surface:loadImage(imgpath .. "checkbox_on.png")
	s.checkbox.imgOff = Surface:loadImage(imgpath .. "checkbox_off.png")
	s.item.checkbox.padding = { 4, 0, 0, 0 }
	s.item.checkbox.align = "right"


	-- Radio button
	s.radio.imgOn = Surface:loadImage(imgpath .. "radiobutton_on.png")
	s.radio.imgOff = Surface:loadImage(imgpath .. "radiobutton_off.png")
	s.item.radio.padding = { 4, 0, 0, 0 }
	s.item.radio.align = "right"


	-- Slider
	s.slider.border = 5
	s.slider.horizontal = 1
	s.slider.bgImg = sliderBackground
	s.slider.img = sliderBar


	-- Text input
	s.textinput.border = { 8, -5, 8, 0 }
	s.textinput.padding = { 6, 0, 6, 0 }
	s.textinput.font = FONT_15px
	s.textinput.cursorFont = FONT_BOLD_22px
	s.textinput.wheelFont = FONT_BOLD_15px
	s.textinput.charHeight = 26
	s.textinput.fg = SELECT_COLOR
	s.textinput.wh = { 0x55, 0x55, 0x55 }
	s.textinput.bgImg = textinputBackground
	s.textinput.wheelImg = textinputWheel
	s.textinput.cursorImg = textinputCursor
	s.textinput.enterImg = Tile:loadImage(imgpath .. "selection_right.png")

	-- Help menu
	s.help.w = screenWidth - 6
	s.help.position = LAYOUT_SOUTH
	s.help.padding = 12
	s.help.font = FONT_15px
	s.help.fg = TEXT_COLOR
	s.help.bgImg = helpBox
	s.help.align = "left"
	s.help.scrollbar.w = 0

	-- Help with soft buttons
	s.softHelp.w = screenWidth - 6
	s.softHelp.position = LAYOUT_SOUTH
	s.softHelp.padding = { 12, 12, 12, 42 }
	s.softHelp.font = FONT_15px
	s.softHelp.fg = TEXT_COLOR
	s.softHelp.bgImg = helpBox
	s.softHelp.align = "left"
	s.softHelp.scrollbar.w = 0

	s.softButton1.x = 15
	s.softButton1.y = screenHeight - 33
	s.softButton1.w = (screenWidth / 2) - 20
	s.softButton1.h = 28
	s.softButton1.position = LAYOUT_NONE
	s.softButton1.align = "center"
	s.softButton1.font = FONT_15px
	s.softButton1.fg = SELECT_COLOR
	s.softButton1.bgImg = softButtonBackground

	s.softButton2.x = (screenWidth / 2) + 5
	s.softButton2.y = screenHeight - 33
	s.softButton2.w = (screenWidth / 2) - 20
	s.softButton2.h = 28
	s.softButton2.position = LAYOUT_NONE
	s.softButton2.align = "center"
	s.softButton2.font = FONT_15px
	s.softButton2.fg = SELECT_COLOR
	s.softButton2.bgImg = softButtonBackground

	s.window.w = screenWidth
	s.window.h = screenHeight


	-- Popup window with Icon
	s.popupIcon.border = { 13, 0, 13, 0 }
	s.popupIcon.maskImg = popupMask

	s.popupIcon.text.border = 15
	s.popupIcon.text.line[1].font = FONT_BOLD_13px
	s.popupIcon.text.line[1].height = 16
	s.popupIcon.text.line[2].font = FONT_BOLD_20px
	s.popupIcon.text.fg = TEXT_COLOR
	s.popupIcon.text.sh = TEXT_SH_COLOR
	s.popupIcon.text.align = "center"
	s.popupIcon.text.position = LAYOUT_SOUTH

	s.iconFavorites.img = Surface:loadImage(imgpath .. "popup_fav_heart_bkgrd.png")
	s.iconFavorites.frameWidth = 161
	s.iconFavorites.align = 'center'

	-- connecting/connected popup icon
	s.iconConnecting.img = Surface:loadImage(imgpath .. "icon_connecting.png")
	s.iconConnecting.frameRate = 4
	s.iconConnecting.frameWidth = 161
	s.iconConnecting.w = WH_FILL
	s.iconConnecting.align = "center"

	s.iconConnected.img = Surface:loadImage(imgpath .. "icon_connected.png")
	s.iconConnected.w = WH_FILL
	s.iconConnected.align = "center"

	s.iconLocked.img = Surface:loadImage(imgpath .. "popup_locked_icon.png")
	s.iconLocked.w = WH_FILL
	s.iconLocked.align = "center"

	s.iconBatteryLow.img = Surface:loadImage(imgpath .. "popup_battery_low_icon.png")
	s.iconBatteryLow.w = WH_FILL
	s.iconBatteryLow.align = "center"

	s.iconAlarm.img = Surface:loadImage(imgpath .. "popup_alarm_icon.png")
	s.iconAlarm.w = WH_FILL
	s.iconAlarm.align = "center"


	-- wireless icons for menus
	s.wirelessLevel1.align = "right"
	s.wirelessLevel1.img = Surface:loadImage(imgpath .. "icon_wireless_2_shadow.png")
	s.wirelessLevel2.align = "right"
	s.wirelessLevel2.img = Surface:loadImage(imgpath .. "icon_wireless_3_shadow.png")
	s.wirelessLevel3.align = "right"
	s.wirelessLevel3.img = Surface:loadImage(imgpath .. "icon_wireless_4_shadow.png")

	s.navcluster.img = Surface:loadImage(imgpath .. "navcluster.png")
	s.navcluster.align = "center"
	s.navcluster.w = WH_FILL


	-- Special styles for specific window types

	-- No layout for the splash screen
	s.splash.layout = Window.noLayout


	-- Jive Home Window

	-- Here we add an icon to the window title. This uses a function
	-- that is called at runtime, so for example the icon could change
	-- based on time of day
	s.home.window.title.icon.img = 
		function(widget)
			return Surface:loadImage(imgpath .. "mini_home.png")
		end



	-- SlimBrowser applet

	s.iconVolumeMin.img = Surface:loadImage(imgpath .. "volume_speaker_l.png")
	s.iconVolumeMin.position = LAYOUT_NONE
	s.iconVolumeMin.x = 16
	s.iconVolumeMin.y = 34

	s.iconVolumeMax.img = Surface:loadImage(imgpath .. "volume_speaker_r.png")
	s.iconVolumeMax.position = LAYOUT_NONE
	s.iconVolumeMax.x = 208
	s.iconVolumeMax.y = 33

	s.volume.border = { 45, 0, 45, 25 }
	s.volume.horizontal = 1
	s.volume.img = volumeBar
	s.volume.bgImg = volumeBackground

	s.volumePopup.x = 0
	s.volumePopup.y = screenHeight - 80
	s.volumePopup.w = screenWidth
	s.volumePopup.h = 80
	s.volumePopup.bgImg = helpBox
	s.volumePopup.title.fg = SELECT_COLOR
	s.volumePopup.title.font = FONT_BOLD_15px
	s.volumePopup.title.align = "center"
	s.volumePopup.title.bgImg = false

	-- titles with artwork and song info
	s.albumtitle.position = LAYOUT_NORTH
	s.albumtitle.bgImg = titleBox
	s.albumtitle.order = { "icon", "text" }
	s.albumtitle.w = screenWidth
	s.albumtitle.h = 60
	s.albumtitle.border = 4
	s.albumtitle.text.padding = { 10, 8, 8, 9 }
	s.albumtitle.text.align = "top-left"
	s.albumtitle.text.font = FONT_13px
	s.albumtitle.text.lineHeight = 16
	s.albumtitle.text.line[1].font = FONT_BOLD_13px
	s.albumtitle.text.line[1].height = 17
	s.albumtitle.text.fg = SELECT_COLOR
	s.albumtitle.icon.align = "center"
	s.albumtitle.icon.img = Surface:loadImage(imgpath .. "menu_album_noartwork.png")
	s.albumtitle.icon.padding = { 6, 0, 0, 0 }

--[[
	why the fudge can't I do it like this?
	-- titles with artwork and song info
	s.internetradiotitle = {}
	s.internetradiotitle.mt = {}
	s.internetradiotitle.mt.__index = s.title
	setmetatable(s.internetradiotitle, s.internetradiotitle.mt)

	s.internetradiotitle.order = { "icon", "text" }
	s.internetradiotitle.icon.img = Surface:loadImage(imgpath .. "mini_internet_radio.png")
	s.internetradiotitle.icon.padding = MINI_ICON_PADDING

--]]

	-- Based on s.title, this is for internetradio title style
	s.internetradiotitle.border       = MINI_ICON_TITLE_BORDER
	s.internetradiotitle.position     = LAYOUT_NORTH
	s.internetradiotitle.bgImg        = titleBox
	s.internetradiotitle.text.padding = MINI_ICON_TEXT_PADDING
	s.internetradiotitle.text.w       = WH_FILL
	s.internetradiotitle.text.align   = MINI_ICON_TEXT_ALIGN
	s.internetradiotitle.text.font    = FONT_BOLD_18px
	s.internetradiotitle.text.fg      = SELECT_COLOR
	s.internetradiotitle.order        = MINI_ICON_ITEM_ORDER
	s.internetradiotitle.icon.img     = Surface:loadImage(imgpath .. "mini_internet_radio.png")
	s.internetradiotitle.icon.padding = MINI_ICON_PADDING
	s.internetradiotitle.icon.align   = MINI_ICON_ICON_ALIGN

	-- Based on s.title, this is for favorites title style
	s.favoritestitle.border        = MINI_ICON_TITLE_BORDER
	s.favoritestitle.position      = LAYOUT_NORTH
	s.favoritestitle.bgImg         = titleBox
	s.favoritestitle.text.w        = WH_FILL
	s.favoritestitle.text.padding  = MINI_ICON_TEXT_PADDING
	s.favoritestitle.text.align    = MINI_ICON_TEXT_ALIGN
	s.favoritestitle.text.font     = FONT_BOLD_18px
	s.favoritestitle.text.fg       = SELECT_COLOR
	s.favoritestitle.order         = MINI_ICON_ITEM_ORDER
	s.favoritestitle.icon.img      = Surface:loadImage(imgpath .. "mini_favorites.png")
	s.favoritestitle.icon.padding  = MINI_ICON_PADDING
	s.favoritestitle.icon.align    = MINI_ICON_ICON_ALIGN

	-- Based on s.title, this is for mymusic title style
	s.mymusictitle.border        = MINI_ICON_TITLE_BORDER
	s.mymusictitle.position      = LAYOUT_NORTH
	s.mymusictitle.bgImg         = titleBox
	s.mymusictitle.text.w        = WH_FILL
	s.mymusictitle.text.padding  = MINI_ICON_TEXT_PADDING
	s.mymusictitle.text.align    = MINI_ICON_TEXT_ALIGN
	s.mymusictitle.text.font     = FONT_BOLD_18px
	s.mymusictitle.text.fg       = SELECT_COLOR
	s.mymusictitle.order         = MINI_ICON_ITEM_ORDER
	s.mymusictitle.icon.padding  = MINI_ICON_PADDING
	s.mymusictitle.icon.align    = MINI_ICON_ICON_ALIGN
	s.mymusictitle.icon.img      = Surface:loadImage(imgpath .. "mini_mymusic.png")
	s.mymusictitle.icon.align    = MINI_ICON_ICON_ALIGN

	-- Based on s.title, this is for search title style
	s.searchtitle.border        = MINI_ICON_TITLE_BORDER
	s.searchtitle.position      = LAYOUT_NORTH
	s.searchtitle.bgImg         = titleBox
	s.searchtitle.text.w        = WH_FILL
	s.searchtitle.text.padding  = MINI_ICON_TEXT_PADDING
	s.searchtitle.text.align    = MINI_ICON_TEXT_ALIGN
	s.searchtitle.text.font     = FONT_BOLD_18px
	s.searchtitle.text.fg       = SELECT_COLOR
	s.searchtitle.order         = MINI_ICON_ITEM_ORDER
	s.searchtitle.icon.img      = Surface:loadImage(imgpath .. "mini_search.png")
	s.searchtitle.icon.padding  = MINI_ICON_PADDING
	s.searchtitle.icon.align    = MINI_ICON_ICON_ALIGN

	-- Based on s.title, this is for settings title style
	s.hometitle.border        = MINI_ICON_TITLE_BORDER
	s.hometitle.position      = LAYOUT_NORTH
	s.hometitle.bgImg         = titleBox
	s.hometitle.text.w        = WH_FILL
	s.hometitle.text.padding  = MINI_ICON_TEXT_PADDING
	s.hometitle.text.align    = MINI_ICON_TEXT_ALIGN
	s.hometitle.text.font     = FONT_BOLD_18px
	s.hometitle.text.fg       = SELECT_COLOR
	s.hometitle.order         = MINI_ICON_ITEM_ORDER
	s.hometitle.icon.img      = Surface:loadImage(imgpath .. "mini_home.png")
	s.hometitle.icon.padding  = MINI_ICON_PADDING
	s.hometitle.icon.align    = MINI_ICON_ICON_ALIGN


	-- Based on s.title, this is for settings title style
	s.settingstitle.border        = MINI_ICON_TITLE_BORDER
	s.settingstitle.position      = LAYOUT_NORTH
	s.settingstitle.bgImg         = titleBox
	s.settingstitle.text.w        = WH_FILL
	s.settingstitle.text.padding  = MINI_ICON_TEXT_PADDING
	s.settingstitle.text.align    = MINI_ICON_TEXT_ALIGN
	s.settingstitle.text.font     = FONT_BOLD_18px
	s.settingstitle.text.fg       = SELECT_COLOR
	s.settingstitle.order         = MINI_ICON_ITEM_ORDER
	s.settingstitle.icon.img      = Surface:loadImage(imgpath .. "mini_settings.png")
	s.settingstitle.icon.padding  = MINI_ICON_PADDING
	s.settingstitle.icon.align    = MINI_ICON_ICON_ALIGN

	-- Based on s.title, this is for newmusic title style
	s.newmusictitle.border        = MINI_ICON_TITLE_BORDER
	s.newmusictitle.position      = LAYOUT_NORTH
	s.newmusictitle.bgImg         = titleBox
	s.newmusictitle.text.w        = WH_FILL
	s.newmusictitle.text.padding  = MINI_ICON_TEXT_PADDING
	s.newmusictitle.text.align    = MINI_ICON_TEXT_ALIGN
	s.newmusictitle.text.font     = FONT_BOLD_18px
	s.newmusictitle.text.fg       = SELECT_COLOR
	s.newmusictitle.order         = MINI_ICON_ITEM_ORDER
	s.newmusictitle.icon.img      = Surface:loadImage(imgpath .. "mini_quarter_note.png")
	s.newmusictitle.icon.padding  = MINI_ICON_PADDING
	s.newmusictitle.icon.align    = MINI_ICON_ICON_ALIGN


	-- menus with artwork and song info
	s.albummenu.padding = 2
	s.albummenu.itemHeight = 61


	-- items with artwork and song info
	--s.albumitem.h = 60
	s.albumitem.order = { "icon", "text", "play" }
	s.albumitem.text.w = WH_FILL
	s.albumitem.text.padding = { 12, 8, 8, 8 }
	s.albumitem.text.align = "top-left"
	s.albumitem.text.font = FONT_13px
	s.albumitem.text.lineHeight = 16
	s.albumitem.text.line[1].font = FONT_BOLD_13px
	s.albumitem.text.line[1].height = 17
	s.albumitem.text.fg = TEXT_COLOR
	s.albumitem.text.sh = TEXT_SH_COLOR
	s.albumitem.icon.align = "center"
	s.albumitem.icon.img = Surface:loadImage(imgpath .. "menu_album_noartwork.png")
	s.albumitem.icon.padding = { 6, 0, 0, 0 }


	-- selected item with artwork and song info
	s.selected.albumitem.text.fg = SELECT_COLOR
	s.selected.albumitem.text.sh = SELECT_SH_COLOR
	s.selected.albumitem.bgImg = albumSelectionBox


	-- locked item with artwork and song info
	s.locked.albumitem.text.fg = SELECT_COLOR
	s.locked.albumitem.text.sh = SELECT_SH_COLOR
	s.locked.albumitem.bgImg = albumSelectionBox

	-- titles with artwork and song info
	s.nowplayingtitle.position = LAYOUT_NORTH
	s.nowplayingtitle.bgImg = titleBox
	s.nowplayingtitle.order = { "text", "icon" }
	s.nowplayingtitle.w = screenWidth
	s.nowplayingtitle.h = 70
	s.nowplayingtitle.border = 4
	s.nowplayingtitle.text.padding = { 10, 8, 8, 9 }
	s.nowplayingtitle.text.align = "top-left"
	s.nowplayingtitle.text.font = FONT_18px
	s.nowplayingtitle.text.lineHeight = 17
	s.nowplayingtitle.text.line[1].font = FONT_BOLD_18px
	s.nowplayingtitle.text.line[1].height = 20
	s.nowplayingtitle.text.fg = SELECT_COLOR
	s.nowplayingtitle.icon.hide = 1
--	s.nowplayingtitle.icon.align = "center"
--	s.nowplayingtitle.icon.img = Surface:loadImage(imgpath .. "menu_nowplaying_noartwork.png")
--	s.nowplayingtitle.icon.padding = { 6, 0, 0, 0 }


	-- menus with artwork and song info
	s.nowplayingmenu.padding = 2
	s.nowplayingmenu.itemHeight = 61


	-- items with artwork and song info
	--s.nowplayingitem.h = 60
	s.nowplayingitem.order = { "icon", "text", "play" }
	s.nowplayingitem.text.w = WH_FILL
	s.nowplayingitem.text.padding = { 12, 8, 8, 8 }
	s.nowplayingitem.text.align = "top-left"
	s.nowplayingitem.text.font = FONT_13px
	s.nowplayingitem.text.lineHeight = 170
	s.nowplayingitem.text.line[1].font = FONT_BOLD_13px
	s.nowplayingitem.text.line[1].height = 17
	s.nowplayingitem.text.fg = TEXT_COLOR
	s.nowplayingitem.text.sh = TEXT_SH_COLOR
	s.nowplayingitem.icon.w = 156
	s.nowplayingitem.icon.h = 156
	s.nowplayingitem.icon.align = "center"
	s.nowplayingitem.icon.img = Surface:loadImage(imgpath .. "menu_album_noartwork.png")
	s.nowplayingitem.icon.padding = { 6, 0, 0, 0 }


	-- selected item with artwork and song info
	s.selected.nowplayingitem.text.fg = SELECT_COLOR
	s.selected.nowplayingitem.text.sh = SELECT_SH_COLOR
	s.selected.nowplayingitem.bgImg = albumSelectionBox


	-- locked item with artwork and song info
	s.locked.nowplayingitem.text.fg = SELECT_COLOR
	s.locked.nowplayingitem.text.sh = SELECT_SH_COLOR
	s.locked.nowplayingitem.bgImg = albumSelectionBox


	-- now playing menu item
	s.albumcurrent.order = { "icon", "text", "play" }
	s.albumcurrent.text.w = WH_FILL
	s.albumcurrent.text.padding = { 12, 8, 8, 8 }
	s.albumcurrent.text.align = "top-left"
	s.albumcurrent.text.font = FONT_13px
	s.albumcurrent.text.lineHeight = 16
	s.albumcurrent.text.line[1].font = FONT_BOLD_13px
	s.albumcurrent.text.line[1].height = 17
	s.albumcurrent.text.fg = TEXT_COLOR
	s.albumcurrent.text.sh = TEXT_SH_COLOR
	s.albumcurrent.icon.align = "center"
	s.albumcurrent.icon.img = Surface:loadImage(imgpath .. "menu_album_noartwork.png")
	s.albumcurrent.icon.padding = { 6, 0, 0, 0 }
	s.albumcurrent.play.img = Surface:loadImage(imgpath .. "menu_nowplaying.png")

	-- selected now playing menu item
	s.selected.albumcurrent.bgImg = albumSelectionBox
	s.selected.albumcurrent.text.fg = SELECT_COLOR
	s.selected.albumcurrent.text.sh = SELECT_SH_COLOR
	s.selected.albumcurrent.play.img = Surface:loadImage(imgpath .. "menu_nowplaying_selected.png")


	-- locked now playing menu item (with loading animation)
	s.locked.albumcurrent.bgImg = albumSelectionBox
	s.locked.albumcurrent.text.fg = SELECT_COLOR
	s.locked.albumcurrent.text.sh = SELECT_SH_COLOR

	-- Popup window for current song info
	s.currentsong.x = 0
	s.currentsong.y = screenHeight - 96
	s.currentsong.w = screenWidth
	s.currentsong.h = 96
	s.currentsong.bgImg = helpBox
	s.currentsong.icon.img = Surface:loadImage(imgpath .. "menu_album_noartwork.png")
	s.currentsong.icon.padding = { 6, -30, 4, 4 }

	s.currentsong.text.w = screenWidth
	s.currentsong.text.h = 72
	s.currentsong.text.padding = { 74, 12, 12, 4 }
	s.currentsong.text.font = FONT_13px
	s.currentsong.text.lineHeight = 17
	s.currentsong.text.line[2].font = FONT_BOLD_13px
	s.currentsong.text.line[2].height = 17
	s.currentsong.text.fg = TEXT_COLOR
	s.currentsong.text.align = "top-left"

	-- Popup window for play/add without artwork
	s.popupplay.x = 0
	s.popupplay.y = screenHeight - 96
	s.popupplay.w = screenWidth
	s.popupplay.h = 96
	s.popupplay.bgImg = helpBox

	s.popupplay.text.w = screenWidth
	s.popupplay.text.h = 72
	s.popupplay.text.padding = { 20, 20, 20, 20 }
	s.popupplay.text.font = FONT_15px
	s.popupplay.text.lineHeight = 17
	s.popupplay.text.line[2].font = FONT_BOLD_15px
	s.popupplay.text.line[2].height = 17
	s.popupplay.text.fg = TEXT_COLOR
	s.popupplay.text.align = "top-left"

	-- Popup window for information display
	s.popupinfo.x = 0
	s.popupinfo.y = screenHeight - 96
	s.popupinfo.w = screenWidth
	s.popupinfo.h = 96
	s.popupinfo.bgImg = helpBox
	s.popupinfo.text.w = screenWidth
	s.popupinfo.text.h = 72
	s.popupinfo.text.padding = { 14, 24, 14, 14 }
	s.popupinfo.text.font = FONT_BOLD_13px
	s.popupinfo.text.lineHeight = 17
	s.popupinfo.text.fg = TEXT_COLOR
	s.popupinfo.text.align = "left"

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

