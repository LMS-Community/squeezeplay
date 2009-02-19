
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
local ipairs, pairs, setmetatable, type = ipairs, pairs, setmetatable, type

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
local jiveMain               = jiveMain


module(..., Framework.constants)
oo.class(_M, Applet)


-- Define useful variables for this skin
local imgpath = "applets/DefaultSkin/images/"
local fontpath = "fonts/"


function init(self)
	self.images = {}
end


-- reuse images instead of loading them twice
-- FIXME can be removed after Bug 10001 is fixed
local function _loadImage(self, file)
	if not self.images[file] then
		self.images[file] = Surface:loadImage(imgpath .. file)
	end

	return self.images[file]
end


-- define a local function to make it easier to create icons.
local function _icon(self, x, y, img)
	local var = {}
	var.x = x
	var.y = y
	var.img = _loadImage(self, img)
	var.layer = LAYER_FRAME
	var.position = LAYOUT_SOUTH

	return var
end


-- defines a new style that inherrits from an existing style
local function _uses(parent, value)
	local style = {}
	setmetatable(style, { __index = parent })

	for k,v in pairs(value or {}) do
		if type(v) == "table" and type(parent[k]) == "table" then
			-- recursively inherrit from parent style
			style[k] = _uses(parent[k], v)
		else
			style[k] = v
		end
	end

	return style
end


-- skin
-- The meta arranges for this to be called to skin Jive.
function skin(self, s, reload, useDefaultSize)
	local screenWidth, screenHeight = Framework:getScreenSize()
	if useDefaultSize or screenWidth < 240 or screenHeight < 320 then
		screenWidth = 240
		screenHeight = 320
	end

	Framework:setVideoMode(screenWidth, screenHeight, 16, jiveMain:isFullscreen())

	-- Images and Tiles
	local iconBackground = 
		Tile:loadHTiles({
					imgpath .. "border_l.png",
					imgpath .. "border.png",
					imgpath .. "border_r.png",
			       })

	local titleBox =
		Tile:loadTiles({
				       imgpath .. "Screen_Formats/Titlebar/titlebar.png",
				       imgpath .. "Screen_Formats/Titlebar/titlebar_tl.png",
				       imgpath .. "Screen_Formats/Titlebar/titlebar_t.png",
				       imgpath .. "Screen_Formats/Titlebar/titlebar_tr.png",
				       imgpath .. "Screen_Formats/Titlebar/titlebar_r.png",
				       imgpath .. "Screen_Formats/Titlebar/titlebar_br.png",
				       imgpath .. "Screen_Formats/Titlebar/titlebar_b.png",
				       imgpath .. "Screen_Formats/Titlebar/titlebar_bl.png",
				       imgpath .. "Screen_Formats/Titlebar/titlebar_l.png",
			       })

	local selectionBox =
		Tile:loadTiles({
				       imgpath .. "Screen_Formats/5_line_lists/menu_selection_box.png",
				       imgpath .. "Screen_Formats/5_line_lists/menu_selection_box_tl.png",
				       imgpath .. "Screen_Formats/5_line_lists/menu_selection_box_t.png",
				       imgpath .. "Screen_Formats/5_line_lists/menu_selection_box_tr.png",
				       imgpath .. "Screen_Formats/5_line_lists/menu_selection_box_r.png",
				       imgpath .. "Screen_Formats/5_line_lists/menu_selection_box_br.png",
				       imgpath .. "Screen_Formats/5_line_lists/menu_selection_box_b.png",
				       imgpath .. "Screen_Formats/5_line_lists/menu_selection_box_bl.png",
				       imgpath .. "Screen_Formats/5_line_lists/menu_selection_box_l.png",
			       })

	local albumSelectionBox =
		Tile:loadTiles({
				       imgpath .. "Screen_Formats/Albums/menu_selection_box_album.png",
				       imgpath .. "Screen_Formats/Albums/menu_selection_box_album_tl.png",
				       imgpath .. "Screen_Formats/Albums/menu_selection_box_album_t.png",
				       imgpath .. "Screen_Formats/Albums/menu_selection_box_album_tr.png",
				       imgpath .. "Screen_Formats/Albums/menu_selection_box_album_r.png",
				       imgpath .. "Screen_Formats/Albums/menu_selection_box_album_br.png",
				       imgpath .. "Screen_Formats/Albums/menu_selection_box_album_b.png",
				       imgpath .. "Screen_Formats/Albums/menu_selection_box_album_bl.png",
				       imgpath .. "Screen_Formats/Albums/menu_selection_box_album_l.png",
			       })

	local helpBox = 
		Tile:loadTiles({
				       imgpath .. "Screen_Formats/Popup_Menu/helpbox.png",
				       imgpath .. "Screen_Formats/Popup_Menu/helpbox_tl.png",
				       imgpath .. "Screen_Formats/Popup_Menu/helpbox_t.png",
				       imgpath .. "Screen_Formats/Popup_Menu/helpbox_tr.png",
				       imgpath .. "Screen_Formats/Popup_Menu/helpbox_r.png",
					nil,
					nil,
					nil,
				       imgpath .. "Screen_Formats/Popup_Menu/helpbox_l.png",
			       })

	local scrollBackground =
		Tile:loadVTiles({
					imgpath .. "Screen_Formats/Scroll_Bar/scrollbar_bkgrd_t.png",
					imgpath .. "Screen_Formats/Scroll_Bar/scrollbar_bkgrd.png",
					imgpath .. "Screen_Formats/Scroll_Bar/scrollbar_bkgrd_b.png",
				})

	local scrollBar = 
		Tile:loadVTiles({
					imgpath .. "Screen_Formats/Scroll_Bar/scrollbar_body_t.png",
					imgpath .. "Screen_Formats/Scroll_Bar/scrollbar_body.png",
					imgpath .. "Screen_Formats/Scroll_Bar/scrollbar_body_b.png",
			       })

	local sliderBackground = 
		Tile:loadHTiles({
					imgpath .. "Screen_Formats/Song_Progress_Bar/SP_Bar_Remote/rem_progbar_bkgrd_l.png",
					imgpath .. "Screen_Formats/Song_Progress_Bar/SP_Bar_Remote/rem_progbar_bkgrd.png",
					imgpath .. "Screen_Formats/Song_Progress_Bar/SP_Bar_Remote/rem_progbar_bkgrd_r.png",
			       })

	local sliderBar = 
		Tile:loadHTiles({
					imgpath .. "Screen_Formats/Song_Progress_Bar/SP_Bar_Remote/rem_progbar_fill_l.png",
					imgpath .. "Screen_Formats/Song_Progress_Bar/SP_Bar_Remote/rem_progbar_fill.png",
					imgpath .. "Screen_Formats/Song_Progress_Bar/SP_Bar_Remote/rem_progbar_fill_r.png",
			       })

	local volumeBar =
		Tile:loadHTiles({
					imgpath .. "Screen_Formats/Song_Progress_Bar/SP_Bar_Remote/rem_progbar_fill_l.png",
					imgpath .. "Screen_Formats/Song_Progress_Bar/SP_Bar_Remote/rem_progbar_fill.png",
					imgpath .. "Screen_Formats/Song_Progress_Bar/SP_Bar_Remote/rem_progbar_fill_r.png",
			       })

	local volumeBackground =
		Tile:loadHTiles({
					imgpath .. "Screen_Formats/Song_Progress_Bar/SP_Bar_Remote/rem_progbar_bkgrd_l.png",
					imgpath .. "Screen_Formats/Song_Progress_Bar/SP_Bar_Remote/rem_progbar_bkgrd.png",
					imgpath .. "Screen_Formats/Song_Progress_Bar/SP_Bar_Remote/rem_progbar_bkgrd_r.png",
				})



	local popupMask = Tile:fillColor(0x000000e5)

	-- FIXME: the paths between here and MARK need fixing to new image org structure
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
	-- MARK


	local TEXT_COLOR = { 0xE7, 0xE7, 0xE7 }
	local TEXT_SH_COLOR = { 0x37, 0x37, 0x37 }

	local SELECT_COLOR = { 0x00, 0x00, 0x00 }
	local SELECT_SH_COLOR = { }

	local FONT_NAME = "FreeSans"
	local BOLD_PREFIX = "Bold"

	local FONT_13px = Font:load(fontpath .. FONT_NAME .. ".ttf", 14)
	local FONT_15px = Font:load(fontpath .. FONT_NAME .. ".ttf", 16)

	local FONT_BOLD_13px = Font:load(fontpath .. FONT_NAME .. BOLD_PREFIX .. ".ttf", 14)
	local FONT_BOLD_15px = Font:load(fontpath .. FONT_NAME .. BOLD_PREFIX .. ".ttf", 16)
	local FONT_BOLD_18px = Font:load(fontpath .. FONT_NAME .. BOLD_PREFIX .. ".ttf", 20)
	local FONT_BOLD_20px = Font:load(fontpath .. FONT_NAME .. BOLD_PREFIX .. ".ttf", 22)
	local FONT_BOLD_22px = Font:load(fontpath .. FONT_NAME .. BOLD_PREFIX .. ".ttf", 24)
	local FONT_BOLD_200px = Font:load(fontpath .. FONT_NAME .. BOLD_PREFIX .. ".ttf", 200)


	-- Iconbar definitions, each icon needs an image and x,y
	s.iconBackground = {}
	s.iconBackground.x = 0
	s.iconBackground.y = screenHeight - 30
	s.iconBackground.w = screenWidth
	s.iconBackground.h = 30
	s.iconBackground.border = { 4, 0, 4, 0 }
	s.iconBackground.bgImg = iconBackground
	s.iconBackground.layer = LAYER_FRAME
	s.iconBackground.position = LAYOUT_SOUTH

	-- play/stop/pause
	s.iconPlaymodeOFF = _icon(self, 9, screenHeight - 30, "icon_mode_off.png")
	s.iconPlaymodeSTOP = _icon(self, 9, screenHeight - 30, "icon_mode_off.png")
	s.iconPlaymodePLAY = _icon(self, 9, screenHeight - 30, "icon_mode_play.png")
	s.iconPlaymodePAUSE = _icon(self, 9, screenHeight - 30, "icon_mode_pause.png")

	-- repeat off/repeat track/repeat playlist
	s.iconRepeatOFF = _icon(self, 41, screenHeight - 30, "icon_repeat_off.png")
	s.iconRepeat0 = _icon(self, 41, screenHeight - 30, "icon_repeat_off.png")
	s.iconRepeat1 = _icon(self, 41, screenHeight - 30, "icon_repeat_song.png")
	s.iconRepeat2 = _icon(self, 41, screenHeight - 30, "icon_repeat.png")

	-- repeat off/repeat track/repeat playlist
	s.iconPlaylistModeOFF = _icon(self, 41, screenHeight - 30, "icon_repeat_off.png")
	s.iconPlaylistModeDISABLED = _icon(self, 41, screenHeight - 30, "icon_repeat_off.png")

	-- FIXME, needs official artwork
	s.iconPlaylistModeON = _icon(self, 41, screenHeight - 30, "icon_mode_playlist.png")
	s.iconPlaylistModePARTY = _icon(self, 41, screenHeight - 30, "icon_mode_party.png")

	-- shuffle off/shuffle album/shuffle playlist
	s.iconShuffleOFF = _icon(self, 75, screenHeight - 30, "icon_shuffle_off.png")
	s.iconShuffle0 = _icon(self, 75, screenHeight - 30, "icon_shuffle_off.png")
	s.iconShuffle1 = _icon(self, 75, screenHeight - 30, "icon_shuffle.png")
	s.iconShuffle2 = _icon(self, 75, screenHeight - 30, "icon_shuffle_album.png")

	-- wireless status
	s.iconWireless1 = _icon(self, 107, screenHeight - 30, "icon_wireless_1.png")
	s.iconWireless2 = _icon(self, 107, screenHeight - 30, "icon_wireless_2.png")
	s.iconWireless3 = _icon(self, 107, screenHeight - 30, "icon_wireless_3.png")
	s.iconWireless4 = _icon(self, 107, screenHeight - 30, "icon_wireless_4.png")
	s.iconWirelessERROR = _icon(self, 107, screenHeight - 30, "icon_wireless_off.png")
	s.iconWirelessSERVERERROR = _icon(self, 107, screenHeight - 30, "icon_wireless_noserver.png")

	-- battery status
	s.iconBatteryAC = _icon(self, 137, screenHeight - 30, "icon_battery_ac.png")

	s.iconBatteryCHARGING = _icon(self, 137, screenHeight - 30, "icon_battery_charging.png")
	s.iconBattery0 = _icon(self, 137, screenHeight - 30, "icon_battery_0.png")
	s.iconBattery1 = _icon(self, 137, screenHeight - 30, "icon_battery_1.png")
	s.iconBattery2 = _icon(self, 137, screenHeight - 30, "icon_battery_2.png")
	s.iconBattery3 = _icon(self, 137, screenHeight - 30, "icon_battery_3.png")
	s.iconBattery4 = _icon(self, 137, screenHeight - 30, "icon_battery_4.png")

	s.iconBatteryCHARGING.frameRate = 1
	s.iconBatteryCHARGING.frameWidth = 37


	-- time
	s.iconTime = {}
	s.iconTime.x = screenWidth - 60
	s.iconTime.y = screenHeight - 34
	s.iconTime.h = 34
	s.iconTime.layer = LAYER_FRAME
	s.iconTime.position = LAYOUT_SOUTH
	s.iconTime.font = Font:load(fontpath .. "FreeSansBold.ttf", 12)
	s.iconTime.fg = TEXT_COLOR


	-- Window title, this is a Label
	-- black text with a background image
	s.title = {}
	s.title.border        = 4
	s.title.position      = LAYOUT_NORTH
	s.title.bgImg         = titleBox
	s.title.text = {}
	s.title.text.w        = WH_FILL
	s.title.text.padding  = { 8, 7, 0, 9 }
	s.title.text.align    = 'top-left'
	s.title.text.font     = FONT_BOLD_18px
	s.title.text.fg       = SELECT_COLOR
	-- FIXME: bug 8866
	s.title.order         = { "text", "icon" }
	s.title.icon = {}
	s.title.icon.padding  = { 0, 0, 8, 0 }
	s.title.icon.align    = 'right'

	-- title icons
	s.hometitle = {
		img = _loadImage(self, "Icons/Mini/icon_home.png")
	}

	s.settingstitle = {
		img = _loadImage(self, "Icons/Mini/icon_settings.png")
	}

	s.setuptitle = _uses(s.settingstitle)


	-- Menu with three basic styles: normal, selected and locked
	-- First define the dimesions of the menu
	s.menu = {}
	s.menu.padding = { 4, 2, 4, 2 }
	s.menu.itemHeight = 27
	s.menu.fg = {0xbb, 0xbb, 0xbb }
	s.menu.font = FONT_BOLD_200px

	-- s.splitmenu in default skin is a clone of s.menu
	s.splitmenu = _uses(s.menu)

	-- menu item
	s.item = {}
	s.item.order = { "text", "icon" }
	s.item.padding = { 9, 6, 6, 6 }
	s.item.text = {}
--	s.item.text.padding = { 1, 1, 1, 1 }
	s.item.text.w = WH_FILL
	s.item.text.font = FONT_BOLD_15px
	s.item.text.fg = TEXT_COLOR
	s.item.text.sh = TEXT_SH_COLOR

	-- menu item with no right icon
	s.itemNoAction = _uses(s.item)

	-- menu items for using different selection icons
	s.itemplay = {}
	s.itemplay = _uses(s.item)
	s.itemadd  = {}
	s.itemadd = _uses(s.item)

	-- checked menu item
	s.checked =
		_uses(s.item, {
			      order = { "text", "check", "icon" },
			      check = {
				      img = _loadImage(self, "Icons/icon_check.png"),
				      align = "right"

			      }
		      })
	-- checked menu item, with no action
	s.checkedNoAction = _uses(s.checked)

	-- selected menu item
	s.selected = {}
	s.selected.item =
		_uses(s.item, {
			      bgImg = selectionBox,
			      text = {
				      fg = SELECT_COLOR,
				      sh = SELECT_SH_COLOR
			      },
			      icon = {
				      padding = { 4, 0, 0, 0 },
				      align = "right",
				      img = _loadImage(self, "Icons/selection_right.png")
			      }
		      })

	s.selected.itemplay =
		_uses(s.selected.item, {
			      icon = {
				      img = _loadImage(self, "Icons/selection_play.png")
			      }
		      })

	s.selected.itemadd =
		_uses(s.selected.item, {
			      icon = {
				      img = _loadImage(self, "Icons/selection_add.png")
			      }
		      })

	s.selected.checked = _uses(s.selected.item, {
			      		order = { "text", "check", "icon" },
					icon = {
						img = _loadImage(self, "Icons/selection_right.png")
					},
					check = {
						align = "right",
						img = _loadImage(self, "Icons/icon_check_selected.png")
					}
				
				})

	s.selected.itemNoAction =
		_uses(s.itemNoAction, {
			      bgImg = selectionBox,
			      text = {
				      fg = SELECT_COLOR,
				      sh = SELECT_SH_COLOR
			      },
		      })

	s.selected.checkedNoAction =
		_uses(s.checkedNoAction, {
			      bgImg = selectionBox,
			      text = {
				      fg = SELECT_COLOR,
				      sh = SELECT_SH_COLOR
			      },
			      check = {
				      align = "right",
				      img = _loadImage(self, "Icons/icon_check_selected.png")
			      }
		      })


	-- locked menu item (with loading animation)
	s.locked = {}
	s.locked.item = _uses(s.selected.item, {
					icon = {
						img = _loadImage(self, "Icons/selection_wait.png"),
						frameRate = 5,
						frameWidth = 10
					}
			})

	--FIXME, locked menu item for these should show something other than the same icon as selected
	s.locked.itemplay = _uses(s.selected.itemplay)
	s.locked.itemadd = _uses(s.selected.itemadd)

	-- menu item choice
	s.item.choice = {}
	s.item.choice.font = FONT_BOLD_15px
	s.item.choice.fg = TEXT_COLOR
	s.item.choice.sh = TEXT_SH_COLOR
	s.item.choice.padding = { 8, 0, 0, 0 }

	-- selected menu item choice
	s.selected.item.choice = {}
	s.selected.item.choice.font = FONT_BOLD_15px
	s.selected.item.choice.fg = SELECT_COLOR
	s.selected.item.choice.sh = SELECT_SH_COLOR

	-- menu value choice
	s.item.value = {}
	s.item.value.font = FONT_BOLD_15px
	s.item.value.fg = TEXT_COLOR
	s.item.value.sh = TEXT_SH_COLOR

	-- selected menu item choice
	s.selected.item.value = {}
	s.selected.item.value.font = FONT_BOLD_15px
	s.selected.item.value.fg = SELECT_COLOR
	s.selected.item.value.sh = SELECT_SH_COLOR

	-- Text areas
	s.textarea = {}
	s.textarea.w = screenWidth
	s.textarea.padding = { 13, 8, 8, 8 }
	s.textarea.font = FONT_BOLD_15px
	s.textarea.fg = TEXT_COLOR
	s.textarea.sh = TEXT_SH_COLOR
	s.textarea.align = "left"
	

	-- Scrollbar
	s.scrollbar = {}
	s.scrollbar.w = 9
	s.scrollbar.border = { 4, 0, 0, 0 }
	s.scrollbar.horizontal = 0
	s.scrollbar.bgImg = scrollBackground
	s.scrollbar.img = scrollBar
	s.scrollbar.layer = LAYER_CONTENT_ON_STAGE


	-- Checkbox
	s.checkbox = {}
	s.checkbox.imgOn = _loadImage(self, "Icons/checkbox_on.png")
	s.checkbox.imgOff = _loadImage(self, "Icons/checkbox_off.png")
	s.item.checkbox = {}
	s.item.checkbox.padding = { 4, 0, 0, 0 }
	s.item.checkbox.align = "right"


	-- Radio button
	s.radio = {}
	s.radio.imgOn = _loadImage(self, "Icons/radiobutton_on.png")
	s.radio.imgOff = _loadImage(self, "Icons/radiobutton_off.png")
	s.item.radio = {}
	s.item.radio.padding = { 4, 0, 0, 0 }
	s.item.radio.align = "right"


	-- Slider
	s.slider = {}
	s.slider.border = 5
	s.slider.horizontal = 1
	s.slider.bgImg = sliderBackground
	s.slider.img = sliderBar

	s.sliderMin = {}
	s.sliderMin.img = _loadImage(self, "slider_icon_negative.png")
	s.sliderMin.border = { 5, 0, 5, 0 }
	s.sliderMax = {}
	s.sliderMax.img = _loadImage(self, "slider_icon_positive.png")
	s.sliderMax.border = { 5, 0, 5, 0 }

	s.sliderGroup = {}
	s.sliderGroup.border = { 7, 5, 25, 10 }

	-- Text input
	s.textinput = {}
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
	s.textinput.enterImg = Tile:loadImage(imgpath .. "Icons/selection_right.png")

        -- Keyboard
        s.keyboard = {}
        s.keyboard.w = 0
        s.keyboard.h = 0

	-- Help menu
	s.help = {}
	s.help.w = screenWidth - 6
	s.help.position = LAYOUT_SOUTH
	s.help.padding = 12
	s.help.font = FONT_15px
	s.help.fg = TEXT_COLOR
	s.help.bgImg = helpBox
	s.help.align = "left"
	s.help.scrollbar = {}
	s.help.scrollbar.w = 0

	-- Help with soft buttons
	s.softHelp = {}
	s.softHelp.w = screenWidth - 6
	s.softHelp.position = LAYOUT_SOUTH
	s.softHelp.padding = { 12, 12, 12, 42 }
	s.softHelp.font = FONT_15px
	s.softHelp.fg = TEXT_COLOR
	s.softHelp.bgImg = helpBox
	s.softHelp.align = "left"
	s.softHelp.scrollbar = {}
	s.softHelp.scrollbar.w = 0

	s.softButton1 = {}
	s.softButton1.x = 15
	s.softButton1.y = screenHeight - 33
	s.softButton1.w = (screenWidth / 2) - 20
	s.softButton1.h = 28
	s.softButton1.position = LAYOUT_NONE
	s.softButton1.align = "center"
	s.softButton1.font = FONT_15px
	s.softButton1.fg = SELECT_COLOR
	s.softButton1.bgImg = softButtonBackground

	s.softButton2 = {}
	s.softButton2.x = (screenWidth / 2) + 5
	s.softButton2.y = screenHeight - 33
	s.softButton2.w = (screenWidth / 2) - 20
	s.softButton2.h = 28
	s.softButton2.position = LAYOUT_NONE
	s.softButton2.align = "center"
	s.softButton2.font = FONT_15px
	s.softButton2.fg = SELECT_COLOR
	s.softButton2.bgImg = softButtonBackground

	s.window = {}
	s.window.w = screenWidth
	s.window.h = screenHeight

	s.errorWindow = {}
	s.errorWindow.w = screenWidth
	s.errorWindow.h = screenHeight
	s.errorWindow.maskImg = popupMask

	-- Popup window with Icon, no borders
	s.popupArt = {}
	s.popupArt.border = { 0, 0, 0, 0 }
	s.popupArt.maskImg = popupMask

	-- Popup window with Icon
	s.popupIcon = {}
	s.popupIcon.border = { 13, 0, 13, 0 }
	s.popupIcon.maskImg = popupMask

	s.popupIcon.text = {}
	s.popupIcon.text.border = 15
	s.popupIcon.text.line = {
		{
			font = FONT_BOLD_13px,
			height = 16,
		},
		{
			font = FONT_BOLD_20px,
		},
	}
	s.popupIcon.text.fg = TEXT_COLOR
	s.popupIcon.text.sh = TEXT_SH_COLOR
	s.popupIcon.text.align = "center"
	s.popupIcon.text.position = LAYOUT_SOUTH

	s.iconPower = {}
	s.iconPower.img = _loadImage(self, "Alerts/popup_shutdown_icon.png")
	s.iconPower.w = WH_FILL
	s.iconPower.align = 'center'

	s.iconFavorites = {}
	s.iconFavorites.img = _loadImage(self, "popup_fav_heart_bkgrd.png")
	s.iconFavorites.frameWidth = 161
	s.iconFavorites.align = 'center'

	-- connecting/connected popup icon
	s.iconConnecting = {}
	s.iconConnecting.img = _loadImage(self, "Alerts/wifi_connecting.png")
	s.iconConnecting.frameRate = 8
	s.iconConnecting.frameWidth = 161
	s.iconConnecting.w = WH_FILL
	s.iconConnecting.align = "center"

	s.iconConnected = {}
	s.iconConnected.img = _loadImage(self, "Alerts/connecting_success_icon.png")
	s.iconConnected.w = WH_FILL
	s.iconConnected.align = "center"

	s.iconLocked = {}
	s.iconLocked.img = _loadImage(self, "Alerts/popup_locked_icon.png")
	s.iconLocked.w = WH_FILL
	s.iconLocked.align = "center"

	s.iconBatteryLow = {}
	s.iconBatteryLow.img = _loadImage(self, "Alerts/popup_battery_low_icon.png")
	s.iconBatteryLow.w = WH_FILL
	s.iconBatteryLow.align = "center"

	s.iconAlarm = {}
	s.iconAlarm.img = _loadImage(self, "Alerts/popup_alarm_icon.png")
	s.iconAlarm.w = WH_FILL
	s.iconAlarm.align = "center"


	-- wireless icons for menus
	s.wirelessLevel1 = {}
	s.wirelessLevel1.align = "right"
	s.wirelessLevel1.img = _loadImage(self, "Icons/icon_wireless_1_shadow.png")
	s.wirelessLevel2 = {}
	s.wirelessLevel2.align = "right"
	s.wirelessLevel2.img = _loadImage(self, "Icons/icon_wireless_2_shadow.png")
	s.wirelessLevel3 = {}
	s.wirelessLevel3.align = "right"
	s.wirelessLevel3.img = _loadImage(self, "Icons/icon_wireless_3_shadow.png")
	s.wirelessLevel4 = {}
	s.wirelessLevel4.align = "right"
	s.wirelessLevel4.img = _loadImage(self, "Icons/icon_wireless_4_shadow.png")

	s.navcluster = {}
	s.navcluster.img = _loadImage(self, "navcluster.png")
	s.navcluster.align = "center"
	s.navcluster.w = WH_FILL


	-- Special styles for specific window types

	-- Jive Home Window

	-- Here we add an icon to the window title. This uses a function
	-- that is called at runtime, so for example the icon could change
	-- based on time of day
--[[
	This example is not relevant any more, but I have left it here as an example
	of how a style value can be set dynamically using a lua function.

	s.home.window.title.icon.img = 
		function(widget)
			return _loadImage(self, "mini_home.png")
		end
--]]


	-- SlimBrowser applet

	s.volumeMin = {}
	s.volumeMin.img = _loadImage(self, "volume_speaker_l.png")
	s.volumeMin.border = { 5, 0, 5, 0 }
	s.volumeMax = {}
	s.volumeMax.img = _loadImage(self, "volume_speaker_r.png")
	s.volumeMax.border = { 5, 0, 5, 0 }

	s.volume = {}
	s.volume.horizontal = 1
	s.volume.img = volumeBar
	s.volume.bgImg = volumeBackground

	s.volumeGroup = {}
	s.volumeGroup.border = { 16, 5, 16, 10 }

	s.volumePopup = {}
	s.volumePopup.x = 0
	s.volumePopup.y = screenHeight - 80
	s.volumePopup.w = screenWidth
	s.volumePopup.h = 80
	s.volumePopup.bgImg = helpBox
	s.volumePopup.title = {}
	s.volumePopup.title.border = 10
	s.volumePopup.title.fg = TEXT_COLOR
	s.volumePopup.title.font = FONT_BOLD_15px
	s.volumePopup.title.align = "center"
	s.volumePopup.title.bgImg = false

	s.scanner = {}
	s.scanner.horizontal = 1
	s.scanner.img = volumeBar
	s.scanner.bgImg = volumeBackground

	s.scannerGroup = {}
	s.scannerGroup.border = { 16, 5, 16, 10 }
	s.scannerGroup.order = { "elapsed", "slider", "remain" }
	s.scannerGroup.text = {}
	s.scannerGroup.text.fg = TEXT_COLOR
	s.scannerGroup.text.font = FONT_13px
	s.scannerGroup.text.w = 60
	s.scannerGroup.text.align = "right"
	s.scannerGroup.text.padding = { 0, 0, 4, 0}

	s.scannerPopup = {}
	s.scannerPopup.x = 0
	s.scannerPopup.y = screenHeight - 80
	s.scannerPopup.w = screenWidth
	s.scannerPopup.h = 80
	s.scannerPopup.bgImg = helpBox
	s.scannerPopup.title = {}
	s.scannerPopup.title.border = 10
	s.scannerPopup.title.fg = TEXT_COLOR
	s.scannerPopup.title.font = FONT_BOLD_15px
	s.scannerPopup.title.align = "center"
	s.scannerPopup.title.bgImg = false

	-- titles with artwork and song info
	s.albumtitle = {}
	s.albumtitle.position = LAYOUT_NORTH
	s.albumtitle.bgImg = titleBox
	s.albumtitle.order = { "icon", "text" }
	s.albumtitle.w = screenWidth
	s.albumtitle.h = 60
	s.albumtitle.border = 4
	s.albumtitle.text = {}
	s.albumtitle.text.padding = { 10, 8, 8, 9 }
	s.albumtitle.text.align = "top-left"
	s.albumtitle.text.font = FONT_13px
	s.albumtitle.text.lineHeight = 16
	s.albumtitle.text.line = {
		{
			font = FONT_BOLD_13px,
			height = 17,
		}
	}
	s.albumtitle.text.fg = SELECT_COLOR
	s.albumtitle.icon = {}
	s.albumtitle.icon.h = WH_FILL
	s.albumtitle.icon.align = "left"
	s.albumtitle.icon.img = _loadImage(self, "Icons/Mini/icon_album.png")
	s.albumtitle.icon.padding = { 9, 0, 0, 0 }


	-- FIXME these need changing after SlimBrowser is updated to
	-- use the new Window titles

	-- Based on s.title, this is for internetradio title style
	s.internetradiotitle =
		_uses(s.title, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_internet_radio.png")
			      }
		      })

	-- Based on s.title, this is for favorites title style
	s.favoritestitle = 
		_uses(s.title, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_favorites.png")
			      }
		      })

	-- Based on s.title, this is for mymusic title style
	s.mymusictitle =
		_uses(s.title, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_music_library.png")
			      }
		      })

	-- Based on s.title, this is for search title style
	s.searchtitle =
		_uses(s.title, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_search.png")
			      }
		      })


	-- Based on s.title, this is for newmusic title style
	s.newmusictitle =
		_uses(s.title, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_album_new.png")
			      }
		      })

	-- Based on s.title, this is for infobrowser title style
	s.infobrowsertitle =
		_uses(s.title, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_info_browser.png")
			      }
		      })

	-- Based on s.title, this is for albumlist title style
	-- NOTE: not to be confused with "album", which is a different style
	s.albumlisttitle =
		_uses(s.title, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_albums.png")
			      }
		      })


	-- Based on s.title, this is for artists title style
	s.artiststitle =
		_uses(s.title, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_artist.png")
			      }
		      })
	-- Based on s.title, this is for random title style
	s.randomtitle =
		_uses(s.title, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_random.png")
			      }
		      })

	-- Based on s.title, this is for musicfolder title style
	s.musicfoldertitle =
		_uses(s.title, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_music_folder.png")
			      }
		      })

	-- Based on s.title, this is for genres title style
	s.genrestitle =
		_uses(s.title, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_genres.png")
			      }
		      })

	-- Based on s.title, this is for years title style
	s.yearstitle =
		_uses(s.title, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_years.png")
			      }
		      })
	-- Based on s.title, this is for playlist title style
	s.playlisttitle =
		_uses(s.title, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_playlist.png")
			      }
		      })

	-- Based on s.title, this is for currentplaylist title style
	s.currentplaylisttitle =
		_uses(s.title, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_quarter_note.png")
			      }
		      })




	-- menus with artwork and song info
	s.albummenu = {}
	s.albummenu.padding = { 4, 2, 4, 2 }
	s.albummenu.itemHeight = 61
	s.albummenu.fg = {0xbb, 0xbb, 0xbb }
	s.albummenu.font = FONT_BOLD_200px

	s.album = {}
	s.album.menu = _uses(s.albummenu)

	s.button = {}
	s.button.menu = _uses(s.albummenu)

	s.multilinemenu = _uses(s.albummenu)

	-- items with artwork and song info
	--s.albumitem.h = 60
	s.albumitem = {}
	s.albumitem.order = { "icon", "text", "play" }
	s.albumitem.text = {}
	s.albumitem.text.w = WH_FILL
	s.albumitem.text.padding = { 6, 8, 8, 8 }
	s.albumitem.text.align = "top-left"
	s.albumitem.text.font = FONT_13px
	s.albumitem.text.lineHeight = 16
	s.albumitem.text.line = {
		{
			font = FONT_BOLD_13px,
			height = 17
		}
	}
	s.albumitem.text.fg = TEXT_COLOR
	s.albumitem.text.sh = TEXT_SH_COLOR
	s.albumitem.icon = {}
	s.albumitem.icon.w = 56
	s.albumitem.icon.h = WH_FILL
	s.albumitem.icon.align = "center"
	s.albumitem.icon.img = _loadImage(self, "album_noartwork_56.png")
	s.albumitem.icon.border = { 8, 0, 0, 0 }

	s.multilineitem = _uses(s.albumitem, {
				order = {'text', 'play'}
			})

	s.buttoniconitem = _uses(s.albumitem)
	s.buttonicon = _uses(s.albumitem.icon)

	-- checked albummenu item
	s.albumchecked =
		_uses(s.albumitem, {
			      order = { "icon", "text", "check" },
			      check = {
				      img = _loadImage(self, "Icons/icon_check.png"),
				      align = "right"

			      }
		      })
	s.multilinechecked = _uses(s.albumchecked, {
				order = { 'text', 'check' },
			})

	-- styles for choose player menu
	s.chooseplayer = _uses(s.albumitem, {
				text = { font = FONT_BOLD_13px }
			})
	s.transporter = _uses(s.buttonicon, {
		img = _loadImage(self, "Icons/Players/transporter.png"),
	})
	s.squeezebox = _uses(s.buttonicon, {
		img = _loadImage(self, "Icons/Players/squeezebox.png"),
	})
	s.squeezebox2 = _uses(s.buttonicon, {
		img = _loadImage(self, "Icons/Players/squeezebox.png"),
	})
	s.squeezebox3 = _uses(s.buttonicon, {
		img = _loadImage(self, "Icons/Players/squeezebox3.png"),
	})
	s.boom = _uses(s.buttonicon, {
		img = _loadImage(self, "Icons/Players/boom.png"),
	})
	s.slimp3 = _uses(s.buttonicon, {
		img = _loadImage(self, "Icons/Players/slimp3.png"),
	})
	s.softsqueeze = _uses(s.buttonicon, {
		img = _loadImage(self, "Icons/Players/softsqueeze.png"),
	})
	s.controller = _uses(s.buttonicon, {
		img = _loadImage(self, "Icons/Players/controller.png"),
	})
	s.receiver = _uses(s.buttonicon, {
		img = _loadImage(self, "Icons/Players/receiver.png"),
	})
	s.squeezeplay = _uses(s.buttonicon, {
		img = _loadImage(self, "Icons/Players/squeezeplay.png"),
	})
	s.http = _uses(s.buttonicon, {
		img = _loadImage(self, "Icons/Players/http.png"),
	})

	s.albumitemplay = _uses(s.albumitem)
	s.albumitemadd  = _uses(s.albumitem)

	s.popupToast = _uses(s.albumitem, 
		{
			order = { 'icon', 'text', 'textarea' },
			textarea = { 
				w = WH_FILL, 
				h = WH_FILL, 
				padding = { 12, 20, 12, 12 } 
			},
			text = { 
				padding = { 6, 15, 8, 8 } 
			},
			icon = { 
				align = 'top-left', 
				border = { 12, 12, 0, 0 } 
			}
		}
	)

	s.albumitemNoAction = {}
	s.albumitemNoAction.order = { "text" }
	s.albumitemNoAction.text = {}
	s.albumitemNoAction.text.w = WH_FILL
	s.albumitemNoAction.text.padding = { 6, 8, 8, 8 }
	s.albumitemNoAction.text.align = "top-left"
	s.albumitemNoAction.text.font = FONT_13px
	s.albumitemNoAction.text.lineHeight = 16
	s.albumitemNoAction.text.line = {
		{
			font = FONT_BOLD_13px,
			height = 17
		}
	}
	s.albumitemNoAction.text.fg = TEXT_COLOR
	s.albumitemNoAction.text.sh = TEXT_SH_COLOR

	s.multilineitemNoAction = _uses(s.albumitemNoAction)

--FIXME: albumitemNoAction can't use _uses because it sticks an icon on the screen
--[[
	s.albumitemNoAction = _uses(s.albumitem, {
					order = { 'text' },
					icon  = nil
				})
--]]
	s.selected.albumitemNoAction = _uses(s.albumitemNoAction)
	s.selected.multilineitemNoAction = _uses(s.multilineitemNoAction)

	-- selected item with artwork and song info
	s.selected.albumitem = {}
	s.selected.albumitem.text = {}
	s.selected.albumitem.text.fg = SELECT_COLOR
	s.selected.albumitem.text.sh = SELECT_SH_COLOR
	s.selected.albumitem.bgImg = albumSelectionBox

	s.selected.albumitem.play = {}
	s.selected.albumitem.play.h = WH_FILL
	s.selected.albumitem.play.align = "center"
	s.selected.albumitem.play.img = _loadImage(self, "Icons/selection_right.png")
	s.selected.albumitem.play.border = { 0, 0, 5, 0 }

	s.selected.multilineitem = _uses(s.selected.albumitem)

	s.selected.albumitemplay = _uses(s.selected.albumitem, {
			play = { img = _loadImage(self, "Icons/selection_play.png") }
	})
	s.selected.multilineitemplay = _uses(s.selected.albumitemplay)

	s.selected.albumitemadd = _uses(s.selected.albumitem, {
			play = { img = _loadImage(self, "Icons/selection_add.png") }
	})
	s.selected.mulitlineadd = _uses(s.selected.albumitemadd)

	s.selected.albumchecked = _uses(s.selected.albumitem, {
	      		order = { "icon", "text", "check", "play" },
			play = {
				img = _loadImage(self, "Icons/selection_right.png")
			},
			check = {
				align = "right",
				img = _loadImage(self, "Icons/icon_check_selected.png")
			}
	})

	s.selected.chooseplayer = _uses(s.selected.albumitem, {
			order = { "icon", "text", "play" },
			play = {
				img = _loadImage(self, "Icons/selection_right.png")
			},
			text = { font = FONT_BOLD_13px }
	})

	-- locked item with artwork and song info
	s.locked.albumitem = {}
	s.locked.albumitem.text = {}
	s.locked.albumitem.text.fg = SELECT_COLOR
	s.locked.albumitem.text.sh = SELECT_SH_COLOR
	s.locked.albumitem.bgImg = albumSelectionBox

	-- waiting item with spinny
	s.albumitemwaiting = _uses(s.albumitem, {
		icon = {
			-- FIXME: this needs renaming without specifics as to icon size, something like icon_connecting_small.png
			img = _loadImage(self, "icon_connecting_44.png"),
			frameRate = 4,
			frameWidth = 56
		}
	})

	s.selected.albumitemwaiting = _uses(s.albumitemwaiting)

	s.locked.albumitem.play = {}
	s.locked.albumitem.play.h = WH_FILL
	s.locked.albumitem.play.align = "center"
	s.locked.albumitem.play.img = _loadImage(self, "Icons/selection_wait.png")
	s.locked.albumitem.play.border = { 0, 0, 5, 0 }
	s.locked.albumitem.play.frameRate = 4
	s.locked.albumitem.play.frameWidth = 10


	-- smallicon style, similar to album but smaller icon and single line on the screen
	s.smalliconmenu = _uses(s.albummenu,
		{
			itemHeight = 27,
		}
	)

	s.smalliconitem = _uses(s.albumitem,
		{
			icon = { w = 25, h = 25, border = { 6, 0, 0, 0 } }
		}
	)

	s.smalliconitemNoAction          = _uses(s.smalliconitem)

	s.selected.smalliconitemNoAction = _uses(s.smalliconitemNoAction, 
		{
			order = { 'icon', 'text' },
			bgImg = selectionBox,
			text = {
				fg = SELECT_COLOR,
	 			sh = SELECT_SH_COLOR
			}
		}
	)

	s.selected.smalliconitem         = _uses(s.selected.albumitem)
	s.smalliconitemwaiting           = _uses(s.albumitemwaiting)
	s.locked.smalliconitem           = _uses(s.locked.albumitem)

	-- titles with artwork and song info
	s.nowplayingtitle = {}
	s.nowplayingtitle.position = LAYOUT_NORTH
	s.nowplayingtitle.bgImg = titleBox
	s.nowplayingtitle.order = { "text", "icon" }
	s.nowplayingtitle.w = screenWidth
	s.nowplayingtitle.h = 70
	s.nowplayingtitle.border = 4
	s.nowplayingtitle.text = {}
	s.nowplayingtitle.text.padding = { 10, 8, 8, 9 }
	s.nowplayingtitle.text.align = "top-left"
	s.nowplayingtitle.text.font = FONT_18px
	s.nowplayingtitle.text.lineHeight = 17
	s.nowplayingtitle.text.line = {
		{
			font = FONT_BOLD_18px,
			height = 20
		}
	}
	s.nowplayingtitle.text.fg = SELECT_COLOR
	s.nowplayingtitle.icon = {}
	s.nowplayingtitle.icon.hide = 1


	-- menus with artwork and song info
	s.nowplayingmenu = {}
	s.nowplayingmenu.padding = 2
	s.nowplayingmenu.itemHeight = 61


	-- items with artwork and song info
	--s.nowplayingitem.h = 60
	s.nowplayingitem = {}
	s.nowplayingitem.order = { "icon", "text", "play" }
	s.nowplayingitem.text = {}
	s.nowplayingitem.text.w = WH_FILL
	s.nowplayingitem.text.padding = { 12, 8, 8, 8 }
	s.nowplayingitem.text.align = "top-left"
	s.nowplayingitem.text.font = FONT_13px
	s.nowplayingitem.text.lineHeight = 170
	s.nowplayingitem.text.line = {
		{
			font = FONT_BOLD_13px,
			height = 17
		}
	}
	s.nowplayingitem.text.fg = TEXT_COLOR
	s.nowplayingitem.text.sh = TEXT_SH_COLOR
	s.nowplayingitem.icon = {}
	s.nowplayingitem.icon.w = 156
	s.nowplayingitem.icon.h = 156
	s.nowplayingitem.icon.align = "left"
	s.nowplayingitem.icon.img = _loadImage(self, "album_noartwork_56.png")
	s.nowplayingitem.icon.padding = { 5, 0, 0, 0 }


	-- selected item with artwork and song info
	s.selected.nowplayingitem = {}
	s.selected.nowplayingitem.text = {}
	s.selected.nowplayingitem.text.fg = SELECT_COLOR
	s.selected.nowplayingitem.text.sh = SELECT_SH_COLOR
	s.selected.nowplayingitem.bgImg = albumSelectionBox


	-- locked item with artwork and song info
	s.locked.nowplayingitem = {}
	s.locked.nowplayingitem.text = {}
	s.locked.nowplayingitem.text.fg = SELECT_COLOR
	s.locked.nowplayingitem.text.sh = SELECT_SH_COLOR
	s.locked.nowplayingitem.bgImg = albumSelectionBox


	-- now playing menu item
	s.albumcurrent = {}
	s.albumcurrent.order = { "icon", "text", "play" }
	s.albumcurrent.text = {}
	s.albumcurrent.text.w = WH_FILL
	s.albumcurrent.text.padding = { 6, 8, 8, 8 }
	s.albumcurrent.text.align = "top-left"
	s.albumcurrent.text.font = FONT_13px
	s.albumcurrent.text.lineHeight = 16
	s.albumcurrent.text.line = {
		{
			font = FONT_BOLD_13px,
			height = 17
		}
	}
	s.albumcurrent.text.fg = TEXT_COLOR
	s.albumcurrent.text.sh = TEXT_SH_COLOR
	s.albumcurrent.icon = {}
	s.albumcurrent.icon.w = 56
	s.albumcurrent.icon.h = WH_FILL
	s.albumcurrent.icon.align = "center"
	s.albumcurrent.icon.img = _loadImage(self, "album_noartwork_56.png")
	s.albumcurrent.icon.border = { 8, 0, 0, 0 }
	s.albumcurrent.play = {}
	s.albumcurrent.play.img = _loadImage(self, "Icons/icon_nowplaying_indicator_w.png")

	-- selected now playing menu item
	s.selected.albumcurrent = {}
	s.selected.albumcurrent.bgImg = albumSelectionBox
	s.selected.albumcurrent.text = {}
	s.selected.albumcurrent.text.fg = SELECT_COLOR
	s.selected.albumcurrent.text.sh = SELECT_SH_COLOR
	s.selected.albumcurrent.play = {}
	s.selected.albumcurrent.play.img = _loadImage(self, "Icons/icon_nowplaying_indicator_b.png")


	-- locked now playing menu item (with loading animation)
	s.locked.albumcurrent = {}
	s.locked.albumcurrent.bgImg = albumSelectionBox
	s.locked.albumcurrent.text = {}
	s.locked.albumcurrent.text.fg = SELECT_COLOR
	s.locked.albumcurrent.text.sh = SELECT_SH_COLOR

	-- Popup window for current song info
	s.currentsong = {}
	s.currentsong.x = 0
	s.currentsong.y = screenHeight - 93
	s.currentsong.w = screenWidth
	s.currentsong.h = 93
	s.currentsong.bgImg = helpBox
	s.currentsong.albumitem = {}
	s.currentsong.albumitem.border = { 4, 10, 4, 0 }
	s.currentsong.albumitem.icon = { }
	s.currentsong.albumitem.icon.align = "top"

	-- Popup window for play/add without artwork
	s.popupplay= {}
	s.popupplay.x = 0
	s.popupplay.y = screenHeight - 96
	s.popupplay.w = screenWidth
	s.popupplay.h = 96

	-- for textarea properties in popupplay
	s.popupplay.padding = { 12, 12, 12, 0 }
	s.popupplay.fg = TEXT_COLOR
	s.popupplay.font = FONT_15px
	s.popupplay.align = "top-left"
	s.popupplay.scrollbar = {}
	s.popupplay.scrollbar.w = 0

	s.lockedHelp = {}
	s.lockedHelp.padding = { 12, 0, 12, 12 }
	s.lockedHelp.fg = TEXT_COLOR
	s.lockedHelp.font = FONT_BOLD_15px
	s.lockedHelp.align = "center"
	s.lockedHelp.position = LAYOUT_NORTH
	s.lockedHelp.w = screenWidth - 20
	s.lockedHelp.x = 20
	s.lockedHelp.y = 0

	s.popupplay.text = {}
	s.popupplay.text.w = screenWidth
	s.popupplay.text.h = 72
	s.popupplay.text.padding = { 20, 20, 20, 20 }
	s.popupplay.text.font = FONT_15px
	s.popupplay.text.lineHeight = 17
	s.popupplay.text.line = {
		nil,
		{
			font = FONT_BOLD_15px,
			height = 17
		}
	}
	s.popupplay.text.fg = TEXT_COLOR
	s.popupplay.text.align = "top-left"

	-- Popup window for information display
	s.popupinfo = {}
	s.popupinfo.x = 0
	s.popupinfo.y = screenHeight - 96
	s.popupinfo.w = screenWidth
	s.popupinfo.h = 96
	s.popupinfo.bgImg = helpBox
	s.popupinfo.text = {}
	s.popupinfo.text.w = screenWidth
	s.popupinfo.text.h = 72
	s.popupinfo.text.padding = { 14, 24, 14, 14 }
	s.popupinfo.text.font = FONT_BOLD_13px
	s.popupinfo.text.lineHeight = 17
	s.popupinfo.text.fg = TEXT_COLOR
	s.popupinfo.text.align = "left"

	-- the NowPlaying skin code is established in two forms,
	-- one for the Screensaver windowStyle (ss), one for the browse windowStyle (browse)
	-- a lot of it can be recycled from one to the other

	-- BEGIN NowPlaying skin code
	local screenWidth, screenHeight = Framework:getScreenSize()

	local nptitleBox =
		Tile:loadTiles({
				       imgpath .. "Screen_Formats/Titlebar/titlebar.png",
				       imgpath .. "Screen_Formats/Titlebar/titlebar_tl.png",
				       imgpath .. "Screen_Formats/Titlebar/titlebar_t.png",
				       imgpath .. "Screen_Formats/Titlebar/titlebar_tr.png",
				       imgpath .. "Screen_Formats/Titlebar/titlebar_r.png",
				       imgpath .. "bghighlight_tr.png",
				       imgpath .. "Screen_Formats/Titlebar/titlebar_b.png",
				       imgpath .. "bghighlight_tl.png",
				       imgpath .. "Screen_Formats/Titlebar/titlebar_l.png",
			       })

        local highlightBox =
                Tile:loadTiles({
                                       imgpath .. "bghighlight.png",
                                       nil,
                                       nil,
                                       nil,
                                       imgpath .. "bghighlight_r.png",
                                       imgpath .. "bghighlight_br.png",
                                       imgpath .. "bghighlight_b.png",
                                       imgpath .. "bghighlight_bl.png",
                                       imgpath .. "bghighlight_l.png"
                               })

	-- Title
	s.ssnptitle = {}
	s.ssnptitle.border = { 4, 4, 4, 0 }
	s.ssnptitle.position = LAYOUT_NORTH
	s.ssnptitle.bgImg = nptitleBox
	s.ssnptitle.order = { "text", "rbutton" }
	s.ssnptitle.text = {}
	s.ssnptitle.text.w = WH_FILL
	s.ssnptitle.text.padding = { 10, 7, 10, 9 }
	s.ssnptitle.text.align = "top-left"
	s.ssnptitle.text.font = Font:load(fontpath .. "FreeSansBold.ttf", 20)
	s.ssnptitle.text.fg = { 0x00, 0x00, 0x00 }
	s.ssnptitle.rbutton = {}
	s.ssnptitle.rbutton.padding = { 10, 7, 10, 9 }
	s.ssnptitle.rbutton.font = Font:load(fontpath .. "FreeSans.ttf", 15)
	s.ssnptitle.rbutton.fg = { 0x00, 0x00, 0x00 }
	s.ssnptitle.rbutton.textAlign = "top-right"


	local nplargetitleBox = Tile:loadTiles({ imgpath .. "Screen_Formats/Titlebar/titlebar.png" })

	-- nptitle style is the same for all windowStyles
	s.browsenptitle = _uses(s.ssnptitle)
	s.largenptitle  = _uses(s.ssnptitle, {
				bgImg = nplargetitleBox,
				border = { 0, 0, 0, 0 },
				text = {
						padding = { 4, 7, 10, 9 }
				}
			}
	)


	-- Song
	s.ssnptrack = {}
	s.ssnptrack.border = { 4, 0, 4, 0 }
        s.ssnptrack.bgImg = highlightBox
	s.ssnptrack.text = {}
	s.ssnptrack.text.w = WH_FILL
	s.ssnptrack.text.padding = { 10, 10, 8, 4 }
	s.ssnptrack.text.align = "top-left"
        s.ssnptrack.text.font = Font:load(fontpath .. "FreeSans.ttf", 14)
	s.ssnptrack.text.lineHeight = 17
        s.ssnptrack.text.line = {
		{
			font = Font:load(fontpath .. "FreeSansBold.ttf", 14),
			height = 17
		}
	}
	s.ssnptrack.text.fg = { 0x00, 0x00, 0x00 }

        local largeHighlightBox = Tile:loadTiles({ imgpath .. "bghighlight.png" })


	-- nptrack is identical between all np styles
	s.browsenptrack = _uses(s.ssnptrack)
	s.largenptrack  = _uses(s.ssnptrack, {
					bgImg = largeHighlightBox,
					
					border = { 0, 0, 0, 0 },
					text = {
						padding = { 4, 6, 4, 0 },
						lineHeight = 24,
						font = Font:load(fontpath .. "FreeSansBold.ttf", 22),
						line = {
							font = Font:load(fontpath .. "FreeSansBold.ttf", 22),
							height = 24
						},
					}
				}
			)

	-- Artwork

	s.ssnpartwork = {}
	s.ssnpartwork.w = WH_FILL
	-- 8 pixel padding below artwork in browse mode
	s.ssnpartwork.border = { 0, 10, 0, 8 }
	s.ssnpartwork.artwork = {}
	s.ssnpartwork.artwork.padding = 0 
	s.ssnpartwork.artwork.w = WH_FILL
	s.ssnpartwork.artwork.align = "center"
	s.ssnpartwork.artwork.img = _loadImage(self, "Icons/icon_album_noartwork_npss.png")

	-- artwork layout for browse NP page
	local browsenpartwork = {
		-- 10 pixel padding below artwork in browse mode
		w = WH_FILL,
		border = { 0, 10, 0, 10 },
		artwork = { padding = 0, img = _loadImage(self, "Icons/icon_album_noartwork_browse.png") }
	}
	-- artwork layout for large NP page
	local largenpartwork = {
		w = WH_FILL,
		border = { 0, 0, 0, 0 },
		artwork = { padding = 0, img = _loadImage(self, "Icons/icon_album_noartwork_browse.png") }
	}
	s.browsenpartwork = _uses(s.ssnpartwork, browsenpartwork)
	s.largenpartwork = _uses(s.ssnpartwork, largenpartwork)

	-- Progress bar
	s.ssprogress = {}
	s.ssprogress.position = LAYOUT_SOUTH
	s.ssprogress.order = { "elapsed", "slider", "remain" }

	s.ssprogress.remain = {}
	s.ssprogress.remain.w = 50
	s.ssprogress.padding = { 8, 0, 8, 5 }
	s.ssprogress.remain.padding = { 8, 0, 0, 5 }
	s.ssprogress.remain.font = Font:load(fontpath .. "FreeSansBold.ttf", 12)
	s.ssprogress.remain.fg = { 0xe7,0xe7, 0xe7 }
	s.ssprogress.remain.sh = { 0x37, 0x37, 0x37 }
	s.ssprogress.elapsed = _uses(s.ssprogress.remain)

	-- browse has different positioning than ss windowStyle
	s.browseprogress = _uses(s.ssprogress,
				{ 
					padding = { 8, 0, 8, 25 },
					elapsed = {
						padding = { 8, 0, 0, 25 }
					},
					remain = {
						padding = { 8, 0, 0, 25 }
					}
				}
			)
	s.largeprogress = _uses(s.ssprogress,
				{
					padding = { 0, 0, 0, 0 },
					elapsed = {
						padding = { 0, 2, 8, 7 },
						align = 'right',
					},
					remain = {
						padding = { 8, 2, 0, 7 },
						align = 'left',
					}
				})

	s.ssprogressB             = {}
        s.ssprogressB.horizontal  = 1
        s.ssprogressB.bgImg       = sliderBackground
        s.ssprogressB.img         = sliderBar
	s.ssprogressB.position    = LAYOUT_SOUTH
	s.ssprogressB.padding     = { 0, 0, 0, 5 }

	s.browseprogressB = _uses(s.ssprogressB,
					{
					padding = { 0, 0, 0, 25 }
					}
				)
	s.largeprogressB = _uses(s.ssprogressB, 
				{
					padding = { 0, 0, 0, 3 }
				}
				)

	-- special style for when there shouldn't be a progress bar (e.g., internet radio streams)
	s.ssprogressNB = {}
	s.ssprogressNB.position = LAYOUT_SOUTH
	s.ssprogressNB.order = { "elapsed" }
	s.ssprogressNB.elapsed = {}
	s.ssprogressNB.elapsed.w = WH_FILL
	s.ssprogressNB.elapsed.align = "center"
	s.ssprogressNB.padding = { 0, 0, 0, 5 }
	s.ssprogressNB.elapsed.padding = { 0, 0, 0, 5 }
	s.ssprogressNB.elapsed.font = Font:load(fontpath .. "FreeSansBold.ttf", 12)
	s.ssprogressNB.elapsed.fg = { 0xe7, 0xe7, 0xe7 }
	s.ssprogressNB.elapsed.sh = { 0x37, 0x37, 0x37 }

	s.browseprogressNB = _uses(s.ssprogressNB,
				{ 
					padding = { 0, 0, 0, 25 },
					elapsed = {
						padding = { 0, 0, 0, 25 },
					}
				}
			)
	s.largeprogressNB = _uses(s.ssprogressNB,
				{
					padding = { 0, 0, 0, 0 },
					elapsed = {
						padding = { 0, 0, 0, 0 },
					}
				}
			)

	-- background style should start at x,y = 0,0
        s.iconbg = {}
        s.iconbg.x = 0
        s.iconbg.y = 0
        s.iconbg.h = screenHeight
        s.iconbg.w = screenWidth
	s.iconbg.border = { 0, 0, 0, 0 }
	s.iconbg.position = LAYOUT_NONE

	-- END NowPlaying skin code


end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

