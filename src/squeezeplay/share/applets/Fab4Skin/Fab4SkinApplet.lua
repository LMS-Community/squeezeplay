
--[[
=head1 NAME

applets.FullscreenSkin.FullscreenSkinApplet - The Jive skin for the Fullscreen desktop application

=head1 DESCRIPTION

This applet implements the fullscreen Jive skin. 

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 
FullscreenSkin overrides the following methods:

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
local imgpath = "applets/Fab4Skin/images/"
local sndpath = "applets/Fab4Skin/sounds/"
local fontpath = "fonts/"
local FONT_NAME = "FreeSans"
local BOLD_PREFIX = "Bold"

-- define a local function to make it easier to create icons.
local function _icon(x, y, img)
	local var = {}
	var.x = x
	var.y = y
	var.img = Surface:loadImage(imgpath .. img)
	var.layer = LAYER_FRAME
	var.position = LAYOUT_SOUTH

	return var
end

-- define a local function that makes it easier to set fonts
local function _font(fontSize)
	return Font:load(fontpath .. FONT_NAME .. ".ttf", fontSize)
end

-- define a local function that makes it easier to set bold fonts
local function _boldfont(fontSize)
	return Font:load(fontpath .. FONT_NAME .. BOLD_PREFIX .. ".ttf", fontSize)
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
function skin(self, s)

	-- XXXX for testing
	Framework:setVideoMode(480, 272, 32, false)

	local screenWidth, screenHeight = Framework:getScreenSize()

	-- Images and Tiles
	local titleBox =
		Tile:loadTiles({
				       imgpath .. "Screen Formats/Titlebar/titlebar.png",
				       imgpath .. "Screen Formats/Titlebar/titlebar_tl.png",
				       imgpath .. "Screen Formats/Titlebar/titlebar_t.png",
				       imgpath .. "Screen Formats/Titlebar/titlebar_tr.png",
				       imgpath .. "Screen Formats/Titlebar/titlebar_r.png",
				       imgpath .. "Screen Formats/Titlebar/titlebar_br.png",
				       imgpath .. "Screen Formats/Titlebar/titlebar_b.png",
				       imgpath .. "Screen Formats/Titlebar/titlebar_bl.png",
				       imgpath .. "Screen Formats/Titlebar/titlebar_l.png",
			       })

	local selectionBox =
		Tile:loadTiles({
				       imgpath .. "Screen Formats/5 line lists/menu_selection_box.png",
				       imgpath .. "Screen Formats/5 line lists/menu_selection_box_tl.png",
				       imgpath .. "Screen Formats/5 line lists/menu_selection_box_t.png",
				       imgpath .. "Screen Formats/5 line lists/menu_selection_box_tr.png",
				       imgpath .. "Screen Formats/5 line lists/menu_selection_box_r.png",
				       imgpath .. "Screen Formats/5 line lists/menu_selection_box_br.png",
				       imgpath .. "Screen Formats/5 line lists/menu_selection_box_b.png",
				       imgpath .. "Screen Formats/5 line lists/menu_selection_box_bl.png",
				       imgpath .. "Screen Formats/5 line lists/menu_selection_box_l.png",
			       })

	local albumSelectionBox =
		Tile:loadTiles({
				       imgpath .. "Screen Formats/Albums/menu_selection_box_album.png",
				       imgpath .. "Screen Formats/Albums/menu_selection_box_album_tl.png",
				       imgpath .. "Screen Formats/Albums/menu_selection_box_album_t.png",
				       imgpath .. "Screen Formats/Albums/menu_selection_box_album_tr.png",
				       imgpath .. "Screen Formats/Albums/menu_selection_box_album_r.png",
				       imgpath .. "Screen Formats/Albums/menu_selection_box_album_br.png",
				       imgpath .. "Screen Formats/Albums/menu_selection_box_album_b.png",
				       imgpath .. "Screen Formats/Albums/menu_selection_box_album_bl.png",
				       imgpath .. "Screen Formats/Albums/menu_selection_box_album_l.png",
			       })

-- FIXME: do these need updating for Fab4Skin?
	local helpBox = 
		Tile:loadTiles({
				       imgpath .. "Screen Formats/Popup Menu/helpbox.png",
				       imgpath .. "Screen Formats/Popup Menu/helpbox_tl.png",
				       imgpath .. "Screen Formats/Popup Menu/helpbox_t.png",
				       imgpath .. "Screen Formats/Popup Menu/helpbox_tr.png",
				       imgpath .. "Screen Formats/Popup Menu/helpbox_r.png",
				       imgpath .. "Screen Formats/Popup Menu/helpbox_br.png",
				       imgpath .. "Screen Formats/Popup Menu/helpbox_b.png",
				       imgpath .. "Screen Formats/Popup Menu/helpbox_bl.png",
				       imgpath .. "Screen Formats/Popup Menu/helpbox_l.png",
			       })

	local scrollBackground =
		Tile:loadVTiles({
					imgpath .. "Screen Formats/Scroll Bar/scrollbar_bkgrd_t.png",
					imgpath .. "Screen Formats/Scroll Bar/scrollbar_bkgrd.png",
					imgpath .. "Screen Formats/Scroll Bar/scrollbar_bkgrd_b.png",
				})

	local scrollBar = 
		Tile:loadVTiles({
					imgpath .. "Screen Formats/Scroll Bar/scrollbar_body_t.png",
					imgpath .. "Screen Formats/Scroll Bar/scrollbar_body.png",
					imgpath .. "Screen Formats/Scroll Bar/scrollbar_body_b.png",
			       })

	local sliderBackground = 
		Tile:loadHTiles({
					imgpath .. "Screen Formats/Song Progress Bar/SP Bar Remote/rem_progbar_bkgrd_l.png",
					imgpath .. "Screen Formats/Song Progress Bar/SP Bar Remote/rem_progbar_bkgrd.png",
					imgpath .. "Screen Formats/Song Progress Bar/SP Bar Remote/rem_progbar_bkgrd_r.png",
			       })

	local sliderBar = 
		Tile:loadHTiles({
					imgpath .. "Screen Formats/Song Progress Bar/SP Bar Remote/rem_progbar_fill_l.png",
					imgpath .. "Screen Formats/Song Progress Bar/SP Bar Remote/rem_progbar_fill.png",
					imgpath .. "Screen Formats/Song Progress Bar/SP Bar Remote/rem_progbar_fill_r.png",
			       })

	local volumeBar =
		Tile:loadHTiles({
					imgpath .. "Screen Formats/Song Progress Bar/SP Bar Remote/rem_progbar_fill_l.png",
					imgpath .. "Screen Formats/Song Progress Bar/SP Bar Remote/rem_progbar_fill.png",
					imgpath .. "Screen Formats/Song Progress Bar/SP Bar Remote/rem_progbar_fill_r.png",
			       })

	local volumeBackground =
		Tile:loadHTiles({
					imgpath .. "Screen Formats/Song Progress Bar/SP Bar Remote/rem_progbar_bkgrd_l.png",
					imgpath .. "Screen Formats/Song Progress Bar/SP Bar Remote/rem_progbar_bkgrd.png",
					imgpath .. "Screen Formats/Song Progress Bar/SP Bar Remote/rem_progbar_bkgrd_r.png",
				})

		local popupMask = Tile:fillColor(0x000000e5)

	local textinputBackground =
		Tile:loadHTiles({
				-- FIXME: need to use Noah's assets for this
				--[[
				       imgpath .. "Screen Formats/Text Entry/Classic/text_entry_bac",
				--]]
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


	local TITLE_PADDING  = { 0, 6, 0, 12 }
	local BUTTON_PADDING = { 2, 12, 0, 0 }
	local CHECK_PADDING  = { 2, 0, 6, 0 }
	local CHECKBOX_RADIO_PADDING  = { 2, 8, 8, 0 }

	--FIXME: paddings here need tweaking for Fab4Skin

	-- this is what they were
	--local MENU_ALBUMITEM_PADDING = { 50, 0, 50, 0 }
	--local MENU_ALBUMITEM_TEXT_PADDING = { 25, 20, 0, 10 }
	--local TEXTAREA_PADDING = { 50, 20, 50, 20 }
	local MENU_ALBUMITEM_PADDING = { 6, 0, 0, 0 }
	local MENU_ALBUMITEM_TEXT_PADDING = { 26, 20, 0, 10 }
	local MENU_CURRENTALBUM_TEXT_PADDING = { 6, 20, 0, 10 }
	local TEXTAREA_PADDING = { 50, 20, 50, 20 }

	local TEXT_COLOR = { 0xE7, 0xE7, 0xE7 }
	local TEXT_COLOR_BLACK = { 0x00, 0x00, 0x00 }
	local TEXT_SH_COLOR = { 0x37, 0x37, 0x37 }

	local SELECT_COLOR = { 0x00, 0x00, 0x00 }
	local SELECT_SH_COLOR = { }

	local TITLE_FONT_SIZE = 18
	local ALBUMMENU_FONT_SIZE = 18
	local TEXTMENU_FONT_SIZE = 24
	local TRACK_FONT_SIZE = 18
	local TEXTAREA_FONT_SIZE = 18
	local TEXTINPUT_FONT_SIZE = 18
	local TEXTINPUT_SELECTED_FONT_SIZE = 28
	local HELP_FONT_SIZE = 18

	local ITEM_ICON_PADDING = { 4, 5, 4, 2 }
	local ITEM_ICON_ALIGN   = 'center'

	-- time (hidden off screen)
	s.iconTime = {}
	s.iconTime.x = screenWidth + 10
	s.iconTime.y = screenHeight + 10
	s.iconTime.h = 34
	s.iconTime.layer = LAYER_FRAME
	s.iconTime.position = LAYOUT_NONE
	s.iconTime.font = Font:load(fontpath .. "FreeSansBold.ttf", 12)
	s.iconTime.fg = TEXT_COLOR


	-- Window title, this is a Label
	s.title = {}
	s.title.border = 4
	s.title.padding = { 15, 5, 10, 0 }
	s.title.position = LAYOUT_NORTH
	s.title.bgImg = titleBox
	s.title.order = { "icon", "text" }
	s.title.text = {}
        s.title.text.w = WH_FILL
	s.title.text.padding = TITLE_PADDING
	s.title.text.align = "center"
	s.title.text.font = _boldfont(TITLE_FONT_SIZE)
	s.title.text.fg = TEXT_COLOR
--[[
	s.title.back = {}
	s.title.back.img = Surface:loadImage(imgpath .. "pointer_selector_L.png")
	s.title.back.align = "left"
--]]



	-- Menu with three basic styles: normal, selected and locked
	-- First define the dimesions of the menu
	s.menu = {}
	s.menu.padding = { 8, 2, 0, 2 }
	s.menu.itemHeight = 46
	s.menu.fg = {0xbb, 0xbb, 0xbb }
	s.menu.font = _boldfont(250)

	s.splitmenu = _uses(s.menu, {
			padding = { 150, 2, 0, 2 }
	})

	-- menu item
	s.item = {}
	s.item.order = { "text", "icon" }
	s.item.padding = { 10, 2, 0, 2 }
	s.item.text = {}
	s.item.text.padding = { 6, 10, 2, 0 }
	s.item.text.align = "left"
	s.item.text.w = WH_FILL
	s.item.text.font = _font(TEXTMENU_FONT_SIZE)
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
					align = ITEM_ICON_ALIGN,
					padding = CHECK_PADDING,
				      img = Surface:loadImage(imgpath .. "Icons/icon_check_14x30.png")

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
				      padding = BUTTON_PADDING,
				      align = ITEM_ICON_ALIGN,
				      img = Surface:loadImage(imgpath .. "Icons/selection_right.png")
			      }
		      })


	s.selected.itemplay =
		_uses(s.selected.item, {
			      icon = {
				      img = Surface:loadImage(imgpath .. "selection_play.png")
			      }
		      })

	s.selected.itemadd =
		_uses(s.selected.item, {
			      icon = {
				      img = Surface:loadImage(imgpath .. "selection_add.png")
			      }
		      })

	s.selected.checked = _uses(s.selected.item, {
			      		order = { "text", "check", "icon" },
					icon = {
						img = Surface:loadImage(imgpath .. "Icons/selection_right.png")
					},
					check = {
						align = ITEM_ICON_ALIGN,
						padding = CHECK_PADDING,
						img = Surface:loadImage(imgpath .. "Icons/icon_check_selected_14x30.png")
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
					align = ITEM_ICON_ALIGN,
					padding = BUTTON_PADDING,
					img = Surface:loadImage(imgpath .. "Icons/icon_check_selected.png")
			      }
		      })


	-- locked menu item (with loading animation)
	s.locked = {}
	s.locked.item = _uses(s.selected.item, {
					icon = {
						img = Surface:loadImage(imgpath .. "selection_wait.png"),
						frameRate = 5,
						frameWidth = 10
					}
			})

	--FIXME, locked menu item for these should show something other than the same icon as selected
	s.locked.itemplay = _uses(s.selected.itemplay)
	s.locked.itemadd = _uses(s.selected.itemadd)

	-- menu item choice
	s.item.choice = {}
	s.item.choice.font = _boldfont(TEXTMENU_FONT_SIZE)
	s.item.choice.fg = TEXT_COLOR
	s.item.choice.sh = TEXT_SH_COLOR
	s.item.choice.padding = BUTTON_PADDING

	-- selected menu item choice
	s.selected.item.choice = {}
	s.selected.item.choice.font = _boldfont(TEXTMENU_FONT_SIZE)
	s.selected.item.choice.fg = SELECT_COLOR
	s.selected.item.choice.sh = SELECT_SH_COLOR

	-- menu value choice
	s.item.value = {}
	s.item.value.font = _boldfont(TEXTMENU_FONT_SIZE)
	s.item.value.fg = TEXT_COLOR
	s.item.value.sh = TEXT_SH_COLOR

	-- selected menu item choice
	s.selected.item.value = {}
	s.selected.item.value.font = _boldfont(TEXTMENU_FONT_SIZE)
	s.selected.item.value.fg = SELECT_COLOR
	s.selected.item.value.sh = SELECT_SH_COLOR

	-- Text areas
	s.textarea = {}
	s.textarea.w = screenWidth
	s.textarea.padding = TEXTAREA_PADDING 
	s.textarea.font = _boldfont(TEXTAREA_FONT_SIZE)
	s.textarea.fg = TEXT_COLOR
	s.textarea.sh = TEXT_SH_COLOR
	s.textarea.align = "left"
	

	-- Scrollbar
	s.scrollbar = {}
	s.scrollbar.w = 24
	s.scrollbar.border = { 0, 0, 0, 10 }
	s.scrollbar.padding = { 0, 0, 0, 0 }
	s.scrollbar.horizontal = 0
	s.scrollbar.bgImg = scrollBackground
	s.scrollbar.img = scrollBar
	s.scrollbar.layer = LAYER_CONTENT_ON_STAGE


	-- Checkbox
	s.checkbox = {}
	s.checkbox.imgOn = Surface:loadImage(imgpath .. "Icons/checkbox_on.png")
	s.checkbox.imgOff = Surface:loadImage(imgpath .. "Icons/checkbox_off.png")
	s.item.checkbox = {}
	s.item.checkbox.padding = CHECKBOX_RADIO_PADDING
	s.item.checkbox.align = "right"


	-- Radio button
	s.radio = {}
	s.radio.imgOn = Surface:loadImage(imgpath .. "Icons/radiobutton_on.png")
	s.radio.imgOff = Surface:loadImage(imgpath .. "Icons/radiobutton_off.png")
	s.item.radio = {}
	s.item.radio.padding = CHECKBOX_RADIO_PADDING
	s.item.radio.align = "right"

	-- Slider
	s.slider = {}
	s.slider.border = 5
	s.slider.horizontal = 1
	s.slider.bgImg = sliderBackground
	s.slider.img = sliderBar

	s.sliderMin = {}
	s.sliderMin.img = Surface:loadImage(imgpath .. "slider_icon_negative.png")
	s.sliderMin.border = { 5, 0, 5, 0 }
	s.sliderMax = {}
	s.sliderMax.img = Surface:loadImage(imgpath .. "slider_icon_positive.png")
	s.sliderMax.border = { 5, 0, 5, 0 }

	s.sliderGroup = {}
	s.sliderGroup.border = { 7, 5, 25, 10 }

	-- Text input
	s.textinput = {}
	s.textinput.border = { 8, -5, 8, 0 }
	s.textinput.padding = { 6, 0, 6, 0 }
	s.textinput.font = _font(TEXTINPUT_FONT_SIZE)
	s.textinput.cursorFont = _boldfont(TEXTINPUT_SELECTED_FONT_SIZE)
	s.textinput.wheelFont = _boldfont(TEXTINPUT_FONT_SIZE)
	s.textinput.charHeight = TEXTINPUT_SELECTED_FONT_SIZE + 4
	s.textinput.fg = SELECT_COLOR
	s.textinput.wh = { 0x55, 0x55, 0x55 }
	s.textinput.bgImg = textinputBackground
	s.textinput.wheelImg = textinputWheel
	s.textinput.cursorImg = textinputCursor
	s.textinput.enterImg = Tile:loadImage(imgpath .. "Icons/selection_right.png")

	-- Help menu
	s.help = {}
	s.help.w = screenWidth - 6
	s.help.position = LAYOUT_SOUTH
	s.help.padding = 12
	s.help.font = _font(HELP_FONT_SIZE)
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
	s.softHelp.font = _font(HELP_FONT_SIZE)
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
	s.softButton1.font = _font(HELP_FONT_SIZE + 2)
	s.softButton1.fg = SELECT_COLOR
	s.softButton1.bgImg = softButtonBackground

	s.softButton2 = {}
	s.softButton2.x = (screenWidth / 2) + 5
	s.softButton2.y = screenHeight - 33
	s.softButton2.w = (screenWidth / 2) - 20
	s.softButton2.h = 28
	s.softButton2.position = LAYOUT_NONE
	s.softButton2.align = "center"
	s.softButton2.font = _font(HELP_FONT_SIZE + 2)
	s.softButton2.fg = SELECT_COLOR
	s.softButton2.bgImg = softButtonBackground

	s.window = {}
	s.window.w = screenWidth
	s.window.h = screenHeight


	-- Popup window with Icon, no borders
	s.popupArt = {}
	s.popupArt.border = { 0, 0, 0, 0 }
	s.popupArt.maskImg = popupMask

	-- Popup window with Icon
	s.popupIcon = {}
	s.popupIcon.border = { 25, 0, 25, 0 }
	s.popupIcon.maskImg = popupMask

	s.popupIcon.text = {}
	s.popupIcon.text.border = 15
	s.popupIcon.text.line = {
		{
			font = _boldfont(24),
			height = 24,
		},
		{
			font = _boldfont(20),
		},
	}
	s.popupIcon.text.fg = TEXT_COLOR
	s.popupIcon.text.sh = TEXT_SH_COLOR
	s.popupIcon.text.align = "center"
	s.popupIcon.text.position = LAYOUT_SOUTH

	s.iconPower = {}
	s.iconPower.img = Surface:loadImage(imgpath .. "Alerts/popup_shutdown_icon.png")
	s.iconPower.w = WH_FILL
	s.iconPower.align = 'center'

--FIXME: is this style used anywhere?
	s.iconFavorites = {}
	s.iconFavorites.img = Surface:loadImage(imgpath .. "popup_fav_heart_bkgrd.png")
	s.iconFavorites.frameWidth = 161
	s.iconFavorites.align = 'center'

	-- connecting/connected popup icon
	s.iconConnecting = {}
	s.iconConnecting.img = Surface:loadImage(imgpath .. "Alerts/wifi_connecting.png")
	s.iconConnecting.frameRate = 4
	s.iconConnecting.frameWidth = 161
	s.iconConnecting.w = WH_FILL
	s.iconConnecting.align = "center"

	s.iconConnected = {}
	s.iconConnected.img = Surface:loadImage(imgpath .. "Alerts/connecting_success_icon.png")
	s.iconConnected.w = WH_FILL
	s.iconConnected.align = "center"

	s.iconLocked = {}
	s.iconLocked.img = Surface:loadImage(imgpath .. "Alerts/popup_locked_icon.png")
	s.iconLocked.w = WH_FILL
	s.iconLocked.align = "center"

	s.iconAlarm = {}
	s.iconAlarm.img = Surface:loadImage(imgpath .. "Alerts/popup_alarm_icon.png")
	s.iconAlarm.w = WH_FILL
	s.iconAlarm.align = "center"


	-- wireless icons for menus
	s.wirelessLevel1 = {}
	s.wirelessLevel1.align = "right"
	s.wirelessLevel1.img = Surface:loadImage(imgpath .. "Icons/icon_wireless_1_shadow.png")
	s.wirelessLevel2 = {}
	s.wirelessLevel2.align = "right"
	s.wirelessLevel2.img = Surface:loadImage(imgpath .. "Icons/icon_wireless_2_shadow.png")
	s.wirelessLevel3 = {}
	s.wirelessLevel3.align = "right"
	s.wirelessLevel3.img = Surface:loadImage(imgpath .. "Icons/icon_wireless_3_shadow.png")
	s.wirelessLevel4 = {}
	s.wirelessLevel4.align = "right"
	s.wirelessLevel4.img = Surface:loadImage(imgpath .. "Icons/icon_wireless_4_shadow.png")

	s.navcluster = {}
	s.navcluster.img = Surface:loadImage(imgpath .. "navcluster.png")
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
			return Surface:loadImage(imgpath .. "head_home.png")
		end
--]]


	-- SlimBrowser applet

	s.volumeMin = {}
	s.volumeMin.img = Surface:loadImage(imgpath .. "icon_volume_min.png")
	s.volumeMin.border = { 5, 0, 5, 0 }
	s.volumeMax = {}
	s.volumeMax.img = Surface:loadImage(imgpath .. "icon_volume_max.png")
	s.volumeMax.border = { 5, 0, 5, 0 }

	s.volume            = {}
	s.volume.horizontal = 1
	s.volume.img        = volumeBar
	s.volume.bgImg      = volumeBackground
	s.volume.align      = 'center'
	s.volume.padding     = { 0, 0, 0, 15 }

	s.volumeGroup = {}
	s.volumeGroup.border = { 0, 5, 0, 10 }

	s.volumePopup = {}
	s.volumePopup.x = 50
	s.volumePopup.y = screenHeight - 100
	s.volumePopup.w = screenWidth - (s.volumePopup.x * 2)
	s.volumePopup.h = 100
	s.volumePopup.bgImg = helpBox
	s.volumePopup.title = {}
	s.volumePopup.title.border = 10
	s.volumePopup.title.fg = TEXT_COLOR
	s.volumePopup.title.font = _boldfont(HELP_FONT_SIZE)
	s.volumePopup.title.align = "center"
	s.volumePopup.title.bgImg = false

-- titles with artwork and song info
	s.albumtitle = _uses(s.title, {
				icon = { img = Surface:loadImage(imgpath .. "Icons/Mini/icon_albums.png") }
			}
	)
--[[
	s.albumtitle = {}
	s.albumtitle.position = LAYOUT_NORTH
	s.albumtitle.bgImg = titleBox
	s.albumtitle.order = { "icon", "text" }
	s.albumtitle.w = screenWidth
	s.albumtitle.h = 130
	s.albumtitle.border = 4
	s.albumtitle.text = {}
	s.albumtitle.text.padding = { 10, 15, 8, 10 }
	s.albumtitle.text.align = "top-left"
	s.albumtitle.text.font = _font(ALBUMMENU_FONT_SIZE)
	s.albumtitle.text.lineHeight = ALBUMMENU_FONT_SIZE + 8
	s.albumtitle.text.line = {
		{
			font = _boldfont(ALBUMMENU_FONT_SIZE),
			height = ALBUMMENU_FONT_SIZE + 8,
		}
	}
	s.albumtitle.text.fg = SELECT_COLOR
	s.albumtitle.icon = {}
	s.albumtitle.icon.h = WH_FILL
	s.albumtitle.icon.align = "left"
	s.albumtitle.icon.img = Surface:loadImage(imgpath .. "Icons/Mini/icon_albums.png")
	s.albumtitle.icon.padding = { 9, 0, 0, 0 }
--]]


	-- titles with mini icons
	s.minititle = {}

	setmetatable(s.minititle, { __index = s.title })

	s.minititle.border        = 4
	s.minititle.position      = LAYOUT_NORTH
	s.minititle.bgImg         = titleBox
	s.minititle.text = {}
	s.minititle.text.w        = WH_FILL
	s.minititle.text.padding  = TITLE_PADDING
	s.minititle.text.align    = 'center'
	s.minititle.text.font     = _boldfont(TITLE_FONT_SIZE)
	s.minititle.text.fg       = TEXT_COLOR
	s.minititle.order         = { "icon", "text" }
	s.minititle.icon = {}
	s.minititle.icon.padding  = { 0, 0, 0, 4 }
	s.minititle.icon.align    = 'center'


	-- Based on s.title, this is for internetradio title style
	s.internetradiotitle =
		_uses(s.minititle, {
			      icon = {
				      img = Surface:loadImage(imgpath .. "Icons/Mini/icon_internet_radio.png")
			      }
		      })

	-- Based on s.title, this is for favorites title style
	s.favoritestitle = 
		_uses(s.minititle, {
			      icon = {
				      img = Surface:loadImage(imgpath .. "Icons/Mini/icon_favorites.png")
			      }
		      })

	-- Based on s.title, this is for mymusic title style
	s.mymusictitle =
		_uses(s.minititle, {
			      icon = {
				      img = Surface:loadImage(imgpath .. "Icons/Mini/icon_music_library.png")
			      }
		      })

	-- Based on s.title, this is for search title style
	s.searchtitle =
		_uses(s.minititle, {
			      icon = {
				      img = Surface:loadImage(imgpath .. "Icons/Mini/icon_search.png")
			      }
		      })

	-- Based on s.title, this is for settings title style
	s.hometitle =
		_uses(s.minititle, {
			      icon = {
				      img = Surface:loadImage(imgpath .. "Icons/Mini/icon_home.png")
			      }
		      })

	-- Based on s.title, this is for settings title style
	s.settingstitle =
		_uses(s.minititle, {
			      icon = {
				      img = Surface:loadImage(imgpath .. "Icons/Mini/icon_settings.png")
			      }
		      })

	-- Based on s.title, this is for newmusic title style
	s.newmusictitle =
		_uses(s.minititle, {
			      icon = {
				      img = Surface:loadImage(imgpath .. "Icons/Mini/icon_album_new.png")
			      }
		      })

	-- Based on s.title, this is for infobrowser title style
	s.infobrowsertitle =
		_uses(s.minititle, {
			      icon = {
				      img = Surface:loadImage(imgpath .. "Icons/Mini/icon_info_browser.png")
			      }
		      })

	-- Based on s.title, this is for albumlist title style
	-- NOTE: not to be confused with "album", which is a different style
	s.albumlisttitle =
		_uses(s.minititle, {
			      icon = {
				      img = Surface:loadImage(imgpath .. "Icons/Mini/icon_albums.png")
			      }
		      })


	-- Based on s.title, this is for artists title style
	s.artiststitle =
		_uses(s.minititle, {
			      icon = {
				      img = Surface:loadImage(imgpath .. "Icons/Mini/icon_artist.png")
			      }
		      })
	-- Based on s.title, this is for random title style
	s.randomtitle =
		_uses(s.minititle, {
			      icon = {
				      img = Surface:loadImage(imgpath .. "Icons/Mini/icon_random.png")
			      }
		      })

	-- Based on s.title, this is for musicfolder title style
	s.musicfoldertitle =
		_uses(s.minititle, {
			      icon = {
				      img = Surface:loadImage(imgpath .. "Icons/Mini/icon_music_folder.png")
			      }
		      })

	-- Based on s.title, this is for genres title style
	s.genrestitle =
		_uses(s.minititle, {
			      icon = {
				      img = Surface:loadImage(imgpath .. "Icons/Mini/icon_genres.png")
			      }
		      })

	-- Based on s.title, this is for years title style
	s.yearstitle =
		_uses(s.minititle, {
			      icon = {
				      img = Surface:loadImage(imgpath .. "Icons/Mini/icon_years.png")
			      }
		      })
	-- Based on s.title, this is for playlist title style
	s.playlisttitle =
		_uses(s.minititle, {
			      icon = {
				      img = Surface:loadImage(imgpath .. "Icons/Mini/icon_playlist.png")
			      }
		      })

	-- Based on s.title, this is for currentplaylist title style
	s.currentplaylisttitle =
		_uses(s.minititle, {
			      icon = {
				      img = Surface:loadImage(imgpath .. "Icons/Mini/icon_quarter_note.png")
			      }
		      })





	-- menus with artwork and song info
	-- FIXME: this needs to be tweaked for Fab4Skin
	s.albummenu = {}
	s.albummenu.padding = { 0, 2, 4, 2 }
	s.albummenu.itemHeight = 76
	s.albummenu.fg = {0xbb, 0xbb, 0xbb }
	s.albummenu.font = _boldfont(250)

	-- items with artwork and song info
	s.albumitem = {}
	s.albumitem.order = { "icon", "text", "play" }
	s.albumitem.padding = MENU_ALBUMITEM_PADDING
	s.albumitem.text = {}
	s.albumitem.text.w = WH_FILL
	s.albumitem.text.padding = MENU_ALBUMITEM_TEXT_PADDING
	s.albumitem.text.align = "left"
	s.albumitem.text.font = _font(ALBUMMENU_FONT_SIZE)
	s.albumitem.text.lineHeight = ALBUMMENU_FONT_SIZE + 4
	s.albumitem.text.line = {
		{
			font = _boldfont(ALBUMMENU_FONT_SIZE),
			height = ALBUMMENU_FONT_SIZE + 2
		}
	}
	s.albumitem.text.fg = TEXT_COLOR
	s.albumitem.text.sh = TEXT_SH_COLOR

	s.albumitem.icon = {}
	s.albumitem.icon.w = 70
	s.albumitem.icon.h = WH_FILL
	s.albumitem.icon.align = "left"
-- FIXME: no_artwork image needed in correct size for Fab4Skin; for now, disable it
--	s.albumitem.icon.img = Surface:loadImage(imgpath .. "menu_album_noartwork_125.png")
	s.albumitem.icon.padding = 0

	s.popupToast = _uses(s.albumitem, 
		{
			order = { 'icon', 'text', 'textarea' },
			textarea = { 
				w = WH_FILL, 
				h = WH_FILL, 
				padding = { 12, 20, 12, 12 } 
			},
			text = { 
				padding = { 6, 15, 8, 8 },
				align = 'top-left',
				w = WH_FILL,
				h = WH_FILL
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
	s.albumitemNoAction.text.padding = MENU_ALBUMITEM_TEXT_PADDING
	s.albumitemNoAction.text.align = "top-left"
	s.albumitemNoAction.text.font = _font(ALBUMMENU_FONT_SIZE)
	s.albumitemNoAction.text.lineHeight = ALBUMMENU_FONT_SIZE + 4
	s.albumitemNoAction.text.line = {
		{
			font = _boldfont(ALBUMMENU_FONT_SIZE),
			height = ALBUMMENU_FONT_SIZE + 2
		}
	}
	s.albumitemNoAction.text.fg = TEXT_COLOR
	s.albumitemNoAction.text.sh = TEXT_SH_COLOR


--FIXME: albumitemNoAction can't use _uses because it sticks an icon on the screen
--[[
	s.albumitemNoAction = _uses(s.albumitem, {
					order = { 'text' },
					icon  = nil
				})
--]]
	s.selected.albumitemNoAction = _uses(s.albumitemNoAction)

	-- selected item with artwork and song info
	s.selected.albumitem = _uses(s.albumitem, {
		bgImg = albumSelectionBox,
		text = {
			fg    = SELECT_COLOR,
			sh    = SELECT_SH_COLOR
		},
		play = {
			h      = WH_FILL,
			align  = "right",
			img    = Surface:loadImage(imgpath .. "Icons/selection_right.png"),
		},
		icon = {
			w = 70,
			h = 70
		}
	})
--[[
	s.selected.albumitem = {}
	s.selected.albumitem.text = {}
	s.selected.albumitem.text.fg = SELECT_COLOR
	s.selected.albumitem.text.sh = SELECT_SH_COLOR
	s.selected.albumitem.bgImg = albumSelectionBox

	s.selected.albumitem.play = {}
	s.selected.albumitem.play.h = WH_FILL
	s.selected.albumitem.play.align = "center"
	s.selected.albumitem.play.img = Surface:loadImage(imgpath .. "Icons/selection_right.png")
	s.selected.albumitem.play.border = { 0, 0, 5, 0 }
--]]

	-- locked item with artwork and song info
	s.locked.albumitem = {}
	s.locked.albumitem.text = {}
	s.locked.albumitem.text.fg = SELECT_COLOR
	s.locked.albumitem.text.sh = SELECT_SH_COLOR
	s.locked.albumitem.bgImg = albumSelectionBox


	-- waiting item with spinny
	s.albumitemwaiting = _uses(s.albumitem, {
		icon = {
			--FIXME, need a resized icon_connecting.png image for the correct albumitem thumb size
			img = Surface:loadImage(imgpath .. "icon_connecting.png"),
			frameRate = 4,
			frameWidth = 120
		}
	})

	s.selected.albumitemwaiting = _uses(s.waiting)


	-- titles with artwork and song info
	s.nowplayingtitle = {}
	s.nowplayingtitle.position = LAYOUT_NORTH
	s.nowplayingtitle.bgImg = titleBox
	s.nowplayingtitle.order = { "back", "text", "icon" }
	s.nowplayingtitle.w = screenWidth
	s.nowplayingtitle.h = 70
	s.nowplayingtitle.border = 4
	s.nowplayingtitle.text = {}
	s.nowplayingtitle.text.padding = { 10, 8, 8, 9 }
	s.nowplayingtitle.text.align = "top-left"
	s.nowplayingtitle.text.font = _font(22)
	s.nowplayingtitle.text.lineHeight = 24
	s.nowplayingtitle.text.line = {
		{
			font = _boldfont(22),
			height = 22
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
	s.nowplayingitem.text.font = _font(24)
	s.nowplayingitem.text.lineHeight = 27
	s.nowplayingitem.text.line = {
		{
			font = _boldfont(24),
			height = 24
		}
	}
	s.nowplayingitem.text.fg = TEXT_COLOR
	s.nowplayingitem.text.sh = TEXT_SH_COLOR
	s.nowplayingitem.icon = {}
	s.nowplayingitem.icon.w = 125
	s.nowplayingitem.icon.h = 125
	s.nowplayingitem.icon.align = "left"
--	s.nowplayingitem.icon.img = Surface:loadImage(imgpath .. "menu_album_noartwork_125.png")
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
	s.albumcurrent.order = { "icon", "play", "text" }
	s.albumcurrent.padding = MENU_ALBUMITEM_PADDING
	s.albumcurrent.text = {}
	s.albumcurrent.text.w = WH_FILL
	s.albumcurrent.text.padding = MENU_CURRENTALBUM_TEXT_PADDING
	s.albumcurrent.text.font = _font(ALBUMMENU_FONT_SIZE)
	s.albumcurrent.text.lineHeight = ALBUMMENU_FONT_SIZE + 4
	s.albumcurrent.text.line = {
		{
			font = _boldfont(ALBUMMENU_FONT_SIZE),
			height = ALBUMMENU_FONT_SIZE + 2
		}
	}
	s.albumcurrent.text.fg = TEXT_COLOR
	s.albumcurrent.text.sh = TEXT_SH_COLOR
	s.albumcurrent.icon = {}
	s.albumcurrent.icon.w = 70
	s.albumcurrent.icon.h = WH_FILL
	s.albumcurrent.icon.align = "left"
--	s.albumcurrent.icon.img = Surface:loadImage(imgpath .. "menu_album_noartwork_125.png")
	s.albumcurrent.play = {}
	s.albumcurrent.play.align = 'top-left'
	s.albumcurrent.play.img = Surface:loadImage(imgpath .. "Icons/icon_nowplaying_indicator_w.png")
	s.albumcurrent.play.padding = { 2, 8, 0, 0 }
	

	-- selected now playing menu item
	s.selected.albumcurrent = {}
	s.selected.albumcurrent.bgImg = albumSelectionBox
	s.selected.albumcurrent.text = {}
	s.selected.albumcurrent.text.fg = SELECT_COLOR
	s.selected.albumcurrent.text.sh = SELECT_SH_COLOR
	s.selected.albumcurrent.play = {}
	s.selected.albumcurrent.play.align = 'top-left'
	s.selected.albumcurrent.play.img = Surface:loadImage(imgpath .. "Icons/icon_nowplaying_indicator_b.png")
	s.selected.albumcurrent.play.padding = { 2, 8, 0, 0 }


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
	s.currentsong.font = _font(HELP_FONT_SIZE)
	s.currentsong.albumitem = {}
	s.currentsong.albumitem.border = { 4, 10, 4, 0 }
	s.currentsong.albumitem.icon = { }
	s.currentsong.albumitem.icon.align = "top"

	local POPUP_HEIGHT = 200
	-- Popup window for play/add without artwork
	s.popupplay= {}
	s.popupplay.x = 0
	s.popupplay.y = screenHeight - 96
	s.popupplay.w = screenWidth - 20
	s.popupplay.h = POPUP_HEIGHT

	-- for textarea properties in popupplay
	s.popupplay.padding = { 12, 12, 12, 0 }
	s.popupplay.fg = TEXT_COLOR
	s.popupplay.font = _font(TRACK_FONT_SIZE)
	s.popupplay.align = "top-left"
	s.popupplay.scrollbar = {}
	s.popupplay.scrollbar.w = 0

	s.popupplay.text = {}
	s.popupplay.text.w = screenWidth
	s.popupplay.text.h = POPUP_HEIGHT
	s.popupplay.text.padding = { 20, 20, 20, 20 }
	s.popupplay.text.font = _font(TRACK_FONT_SIZE)
	s.popupplay.text.lineHeight = TRACK_FONT_SIZE + 2
	s.popupplay.text.line = {
		nil,
		{
			font = _boldfont(TRACK_FONT_SIZE),
			height = 32
		}
	}
	s.popupplay.text.fg = TEXT_COLOR
	s.popupplay.text.align = "top-left"

	-- Popup window for information display
	s.popupinfo = {}
	s.popupinfo.x = 0
	s.popupinfo.y = screenHeight - 96
	s.popupinfo.w = screenWidth
	s.popupinfo.h = POPUP_HEIGHT
	s.popupinfo.bgImg = helpBox
	s.popupinfo.text = {}
	s.popupinfo.text.w = screenWidth
	s.popupinfo.text.h = POPUP_HEIGHT
	s.popupinfo.text.padding = { 14, 24, 14, 14 }
	s.popupinfo.text.font = _boldfont(HELP_FONT_SIZE)
	s.popupinfo.text.lineHeight = HELP_FONT_SIZE + 3
	s.popupinfo.text.fg = TEXT_COLOR
	s.popupinfo.text.align = "left"


	-- BEGIN NowPlaying skin code
	-- this skin is established in two forms,
	-- one for the Screensaver windowStyle (ss), one for the browse windowStyle (browse)
	-- a lot of it can be recycled from one to the other

	local npimgpath = "applets/NowPlaying/"

	local screenWidth, screenHeight = Framework:getScreenSize()

	local TEXT_COLOR = { 0xE7, 0xE7, 0xE7 }
	local TEXT_SH_COLOR = { 0x37, 0x37, 0x37 }

	local SELECT_COLOR = { 0x00, 0x00, 0x00 }
	local SELECT_SH_COLOR = { }

	local NP_TRACK_FONT_SIZE = 26

        local titleBox =
                Tile:loadTiles({
				       imgpath .. "Screen Formats/Titlebar/titlebar.png",
				       imgpath .. "Screen Formats/Titlebar/titlebar_tl.png",
				       imgpath .. "Screen Formats/Titlebar/titlebar_t.png",
				       imgpath .. "Screen Formats/Titlebar/titlebar_tr.png",
				       imgpath .. "Screen Formats/Titlebar/titlebar_r.png",
				       imgpath .. "Screen Formats/Titlebar/titlebar_br.png",
				       imgpath .. "Screen Formats/Titlebar/titlebar_b.png",
				       imgpath .. "Screen Formats/Titlebar/titlebar_bl.png",
				       imgpath .. "Screen Formats/Titlebar/titlebar_l.png",
                               })

	-- Title
	s.ssnptitle = _uses(s.title)

	-- nptitle style is the same for both windowStyles
	s.browsenptitle = _uses(s.ssnptitle)

	-- Song
	s.ssnptrack = {}
	s.ssnptrack.border = { 4, 0, 4, 0 }
	s.ssnptrack.text = {}
	s.ssnptrack.text.w = WH_FILL
	s.ssnptrack.text.padding = { 220, 46, 20, 10 }
	s.ssnptrack.text.align = "left"
        s.ssnptrack.text.font = _font(NP_TRACK_FONT_SIZE)
	s.ssnptrack.text.lineHeight = NP_TRACK_FONT_SIZE + 4
	s.ssnptrack.position = LAYOUT_WEST
        s.ssnptrack.text.line = {
		{
			font = _boldfont(NP_TRACK_FONT_SIZE),
			height = NP_TRACK_FONT_SIZE + 4
		}
	}
	s.ssnptrack.text.fg = TEXT_COLOR

	-- nptrack is identical between the two windowStyles
	s.browsenptrack = _uses(s.ssnptrack)

	-- Artwork
	local ARTWORK_SIZE = 190
	local browseArtWidth = ARTWORK_SIZE
	local ssArtWidth = ARTWORK_SIZE

--	local ssnoartworkoffset = (screenWidth - ssArtWidth) / 2
	s.ssnpartwork = {}

	s.ssnpartwork.w = ssArtWidth
	s.ssnpartwork.border = { 10, 40, 10, 0 }
	s.ssnpartwork.position = LAYOUT_WEST
	s.ssnpartwork.align = "center"
	s.ssnpartwork.artwork = {}
	s.ssnpartwork.artwork.align = "center"
	s.ssnpartwork.artwork.padding = 0
	s.ssnpartwork.artwork.img = Surface:loadImage(imgpath .. "Icons/icon_album_noartwork_336.png")
	s.browsenpartwork = _uses(s.ssnpartwork)

	-- Progress bar
        local progressBackground =
                Tile:loadHTiles({
					imgpath .. "Screen Formats/Song Progress Bar/SP Bar Remote/rem_progbar_bkgrd_l.png",
					imgpath .. "Screen Formats/Song Progress Bar/SP Bar Remote/rem_progbar_bkgrd.png",
					imgpath .. "Screen Formats/Song Progress Bar/SP Bar Remote/rem_progbar_bkgrd_r.png",
                               })

        local progressBar =
                Tile:loadHTiles({
					imgpath .. "Screen Formats/Song Progress Bar/SP Bar Remote/rem_progbar_fill_l.png",
					imgpath .. "Screen Formats/Song Progress Bar/SP Bar Remote/rem_progbar_fill.png",
					imgpath .. "Screen Formats/Song Progress Bar/SP Bar Remote/rem_progbar_fill_r.png",
                               })

	s.ssprogress = {}
	s.ssprogress.position = LAYOUT_SOUTH
	s.ssprogress.order = { "elapsed", "slider", "remain" }
	s.ssprogress.elapsed = {}
	s.ssprogress.elapsed.align = 'right'
	s.ssprogress.remain = {}
	s.ssprogress.remain.align = 'left'
	s.ssprogress.text = {}
	s.ssprogress.text.w = 75 
	s.ssprogress.text.align = 'right'
	s.ssprogress.padding = { 10, 10, 10, 5 }
	s.ssprogress.text.padding = { 8, 0, 8, 15 }
	s.ssprogress.text.font = _boldfont(18)
	s.ssprogress.text.fg = { 0xe7,0xe7, 0xe7 }
	s.ssprogress.text.sh = { 0x37, 0x37, 0x37 }

	s.browseprogress = _uses(s.ssprogress)
	-- browse has different positioning than ss windowStyle
--[[
	s.browseprogress = _uses(s.ssprogress,
				{ 
					padding = { 0, 0, 0, 25 },
					text = {
						padding = { 8, 0, 8, 25 },
					}
				}
			)
--]]

	s.ssprogressB             = {}
        s.ssprogressB.horizontal  = 1
        s.ssprogressB.bgImg       = progressBackground
        s.ssprogressB.img         = progressBar
	s.ssprogressB.position    = LAYOUT_SOUTH
	s.ssprogressB.padding     = { 0, 0, 0, 15 }

	s.browseprogressB = _uses(s.ssprogressB)

	-- special style for when there shouldn't be a progress bar (e.g., internet radio streams)
	s.ssprogressNB = {}
	s.ssprogressNB.position = LAYOUT_SOUTH
	s.ssprogressNB.order = { "elapsed" }
	s.ssprogressNB.text = {}
	s.ssprogressNB.text.w = WH_FILL
	s.ssprogressNB.text.align = "center"
	s.ssprogressNB.padding = { 0, 0, 0, 5 }
	s.ssprogressNB.text.padding = { 0, 0, 0, 5 }
	s.ssprogressNB.text.font = _boldfont(18) 
	s.ssprogressNB.text.fg = { 0xe7, 0xe7, 0xe7 }
	s.ssprogressNB.text.sh = { 0x37, 0x37, 0x37 }

	s.browseprogressNB = _uses(s.ssprogressNB)

	-- background style should start at x,y = 0,0
        s.iconbg = {}
        s.iconbg.x = 0
        s.iconbg.y = 0
        s.iconbg.h = screenHeight
        s.iconbg.w = screenWidth
	s.iconbg.border = { 0, 0, 0, 0 }
	s.iconbg.position = LAYOUT_NONE


end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

