
--[[
=head1 NAME

applets.SqueezeboxSkin.SqueezeboxSkinApplet - The squeezeplay skin for the Squeezebox Touch

=head1 DESCRIPTION

This applet implements the Squeezebox skin

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 
SqueezeboxSkin overrides the following methods:

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
local function _icon(x, y, img)
	local var = {}
	var.x = x
	var.y = y
	var.img = _loadImage(self, img)
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
	Framework:setVideoMode(480, 272, 0, false)

	local screenWidth, screenHeight = Framework:getScreenSize()

	-- Images and Tiles
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
	local buttonBox =
		Tile:loadTiles({
					imgpath .. "Buttons/button_selection_box.png",
					imgpath .. "Buttons/button_sbox_tl.png",
					imgpath .. "Buttons/button_sbox_t.png",
					imgpath .. "Buttons/button_sbox_tr.png",
					imgpath .. "Buttons/button_sbox_r.png",
					imgpath .. "Buttons/button_sbox_br.png",
					imgpath .. "Buttons/button_sbox_b.png",
					imgpath .. "Buttons/button_sbox_bl.png",
					imgpath .. "Buttons/button_sbox_l.png",
				})

-- FIXME: do these need updating for Fab4Skin?
	local helpBox = 
		Tile:loadTiles({
				       imgpath .. "Screen_Formats/Popup_Menu/helpbox.png",
				       imgpath .. "Screen_Formats/Popup_Menu/helpbox_tl.png",
				       imgpath .. "Screen_Formats/Popup_Menu/helpbox_t.png",
				       imgpath .. "Screen_Formats/Popup_Menu/helpbox_tr.png",
				       imgpath .. "Screen_Formats/Popup_Menu/helpbox_r.png",
				       imgpath .. "Screen_Formats/Popup_Menu/helpbox_br.png",
				       imgpath .. "Screen_Formats/Popup_Menu/helpbox_b.png",
				       imgpath .. "Screen_Formats/Popup_Menu/helpbox_bl.png",
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

	local regionMask = Tile:loadTiles({
					imgpath .. "Screen_Formats/Setup/overlay_region_map.png"
				})

	-- FIXME: no popupBox in Fab4? there is a defined popupBox in DefaultSkin...

	local textinputBackground =
		Tile:loadHTiles({
				-- FIXME: need to use Noah's assets for this
				--[[
				       imgpath .. "Screen_Formats/Text_Entry/Classic/text_entry_bac",
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
	local POPUP_TEXT_SIZE_1 = 24
	local POPUP_TEXT_SIZE_2 = 12
	local TRACK_FONT_SIZE = 18
	local TEXTAREA_FONT_SIZE = 18
	local CENTERED_TEXTAREA_FONT_SIZE = 28
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
	s.title.padding = { 5, 5, 10, 0 }
	s.title.position = LAYOUT_NORTH
	s.title.bgImg = titleBox
	s.title.order = { "back", "icon", "text", "nowplaying" }
	s.title.text = {}
        s.title.text.w = WH_FILL
	s.title.text.padding = TITLE_PADDING
	s.title.text.align = "center"
	s.title.text.font = _boldfont(TITLE_FONT_SIZE)
	s.title.text.fg = TEXT_COLOR

	s.title.back = {}
	s.title.back.img = _loadImage(self, "Icons/Mini/left_arrow.png")
	s.title.back.bgImg = buttonBox
	s.title.back.align = "left"
	s.title.back.padding = { 0, 0, 5, 5 }

	s.title.nowplaying = {}
	--FIXME, this png path should likely change
	s.title.nowplaying.img = _loadImage(self, "menu_album_noartwork_24.png")
	s.title.nowplaying.bgImg = selectionBox
	s.title.nowplaying.align = "right"

	-- Menu with three basic styles: normal, selected and locked
	-- First define the dimesions of the menu
	s.menu = {}
	s.menu.padding = { 8, 2, 0, 2 }
	s.menu.itemHeight = 46
	s.menu.fg = {0xbb, 0xbb, 0xbb }
	s.menu.font = _boldfont(250)

	-- FIXME: splitmenu will support large icons on the left in the future
	-- for now, make it the same as s.menu
	s.splitmenu = _uses(s.menu)

	--[[
	s.splitmenu = _uses(s.menu, {
			padding = { 150, 2, 0, 2 }
	})
	--]]

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
					--FIXME: icon_check_14x30.png should probably be changed to something like icon_check.png
				      img = _loadImage(self, "Icons/icon_check_14x30.png")

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
				      img = _loadImage(self, "Icons/selection_right.png")
			      }
		      })


	s.selected.itemplay =
		_uses(s.selected.item, {
			      icon = {
					--FIXME: need this image
				      img = _loadImage(self, "Icons/selection_play.png")
			      }
		      })

	s.selected.itemadd =
		_uses(s.selected.item, {
			      icon = {
					--FIXME: need this image
				      img = _loadImage(self, "Icons/selection_add.png")
			      }
		      })

	s.selected.checked = _uses(s.selected.item, {
			      		order = { "text", "check", "icon" },
					icon = {
						img = _loadImage(self, "Icons/selection_right.png")
					},
					check = {
						align = ITEM_ICON_ALIGN,
						padding = CHECK_PADDING,
						img = _loadImage(self, "Icons/icon_check_selected_14x30.png")
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
					img = _loadImage(self, "Icons/icon_check_selected.png")
			      }
		      })


	-- locked menu item (with loading animation)
	s.locked = {}
	s.locked.item = _uses(s.selected.item, {
					icon = {
						img = _loadImage(self, "Icons/selection_waiting.png"),
						frameRate = 5,
						frameWidth = 30
					}
			})

	s.locked.itemplay = _uses(s.locked.item)
	s.locked.itemadd = _uses(s.locked.item)

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
	
	-- Text for centering on the screen
	s.centeredtextarea = {}
	s.centeredtextarea.position = LAYOUT_CENTER
	s.centeredtextarea.w = screenWidth
	s.centeredtextarea.padding = { 50, 20, 20, 2 }
	s.centeredtextarea.font = _boldfont(CENTERED_TEXTAREA_FONT_SIZE)
	s.centeredtextarea.text = {}
	s.centeredtextarea.text.align = 'center'
	s.centeredtextarea.align = 'center'
	s.centeredtextarea.lineHeight = 40
	s.centeredtextarea.fg = TEXT_COLOR
	s.centeredtextarea.sh = TEXT_SH_COLOR
	s.centeredtextarea.align = "center"
	
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
	s.checkbox.imgOn = _loadImage(self, "Icons/checkbox_on.png")
	s.checkbox.imgOff = _loadImage(self, "Icons/checkbox_off.png")
	s.item.checkbox = {}
	s.item.checkbox.padding = CHECKBOX_RADIO_PADDING
	s.item.checkbox.align = "right"


	-- Radio button
	s.radio = {}
	s.radio.imgOn = _loadImage(self, "Icons/radiobutton_on.png")
	s.radio.imgOff = _loadImage(self, "Icons/radiobutton_off.png")
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
	s.sliderMin.img = _loadImage(self, "slider_icon_negative.png")
	s.sliderMin.border = { 5, 0, 5, 0 }
	s.sliderMax = {}
	s.sliderMax.img = _loadImage(self, "slider_icon_positive.png")
	s.sliderMax.border = { 5, 0, 5, 0 }

	s.sliderGroup = {}
	s.sliderGroup.border = { 7, 5, 25, 10 }

	-- Text input
	s.textinput = {}
	s.textinput.h = 55
	s.textinput.border = { 8, -5, 8, 0 }
	s.textinput.padding = { 6, 0, 6, 0 }
	s.textinput.font = _font(TEXTINPUT_FONT_SIZE)
	s.textinput.cursorFont = _boldfont(TEXTINPUT_SELECTED_FONT_SIZE)
	s.textinput.wheelFont = _boldfont(TEXTINPUT_FONT_SIZE)
	s.textinput.charHeight = TEXTINPUT_SELECTED_FONT_SIZE + 4
	s.textinput.fg = SELECT_COLOR
	s.textinput.wh = { 0x55, 0x55, 0x55 }
	s.textinput.bgImg = textinputBackground
--	s.textinput.wheelImg = textinputWheel
	s.textinput.cursorImg = textinputCursor
	s.textinput.enterImg = Tile:loadImage(imgpath .. "Icons/selection_right.png")

	-- Keyboard
	s.keyboard = {}
	s.keyboard.w = WH_FILL
	s.keyboard.h = WH_FILL
	s.keyboard.border = { 8, 0, 8, 0 }

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

	s.regionWindow = _uses(s.window, { 
					bgImg = regionMask
				})

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
	s.popupIcon.border = { 25, 0, 25, 0 }
	s.popupIcon.maskImg = popupMask

	s.popupIcon.text = {}
	s.popupIcon.text.border = 15
	s.popupIcon.text.font = _boldfont(POPUP_TEXT_SIZE_1)
	s.popupIcon.text.fg = TEXT_COLOR
	s.popupIcon.text.lineHeight = POPUP_TEXT_SIZE_1 + 2
	s.popupIcon.text.sh = TEXT_SH_COLOR
	s.popupIcon.text.align = "center"
	s.popupIcon.text.position = LAYOUT_NORTH

	s.popupIcon.text2 = {}
	s.popupIcon.text2.border = 15
	s.popupIcon.text2.font = _boldfont(POPUP_TEXT_SIZE_2)
	s.popupIcon.text2.fg = TEXT_COLOR
	s.popupIcon.text2.sh = TEXT_SH_COLOR
	s.popupIcon.text2.align = "center"
	s.popupIcon.text2.position = LAYOUT_SOUTH


	s.iconPower = {}
	s.iconPower.img = _loadImage(self, "Alerts/popup_shutdown_icon.png")
	s.iconPower.w = WH_FILL
	s.iconPower.align = 'center'

--FIXME: is this style used anywhere?
	s.iconFavorites = {}
	s.iconFavorites.img = _loadImage(self, "popup_fav_heart_bkgrd.png")
	s.iconFavorites.frameWidth = 161
	s.iconFavorites.align = 'center'

	-- connecting/connected popup icon
	s.iconConnecting = {}
	s.iconConnecting.img = _loadImage(self, "Alerts/wifi_connecting.png")
	s.iconConnecting.frameRate = 4
	s.iconConnecting.frameWidth = 161
	s.iconConnecting.w = 161
	s.iconConnecting.align = "left"
	s.iconConnecting.padding = { 25, 0, 0, 0 }
	s.iconConnecting.position = LAYOUT_WEST

	s.iconConnected = {}
	s.iconConnected.img = _loadImage(self, "Alerts/connecting_success_icon.png")
	s.iconConnected.w = WH_FILL
	s.iconConnected.align = "center"

	s.iconLocked = {}
	s.iconLocked.img = _loadImage(self, "Alerts/popup_locked_icon.png")
	s.iconLocked.w = WH_FILL
	s.iconLocked.align = "center"

	s.iconAlarm = {}
	s.iconAlarm.img = _loadImage(self, "Alerts/popup_alarm_icon.png")
	s.iconAlarm.w = WH_FILL
	s.iconAlarm.align = "center"

	s.touchButton = {}
        s.touchButton.padding = { 4, 10, 0, 10 }
        s.touchButton.font = _font(22)
        s.touchButton.fg = TEXT_COLOR_BLACK
        s.touchButton.bgImg = selectionBox
        s.touchButton.align = 'center'
	s.touchButton.order = { 'text', 'icon' }
        s.touchButton.text  = { align = 'center' }
        s.touchButton.text.padding = { 0, 15, 0, 15 }
	s.touchButton.icon = { 
			img = _loadImage(self, "Icons/selection_right.png"), 
			padding = { 0, 15, 5, 15 },
			align = 'center' 
	}
	s.touchButton.position = LAYOUT_NONE
	s.touchButton.x = screenWidth/2 - 80
	s.touchButton.y = screenHeight - 80

	s.helpTouchButton = {}
	s.helpTouchButton.padding = { 10, 16, 10, 16 }
	s.helpTouchButton.font = _boldfont(14)
	s.helpTouchButton.fg = TEXT_COLOR_BLACK
        s.helpTouchButton.bgImg = selectionBox
        s.helpTouchButton.align = 'center'
        s.helpTouchButton.text = {}
        s.helpTouchButton.text.align = "center"
	s.helpTouchButton.position = LAYOUT_NONE
	s.helpTouchButton.x = screenWidth - 60
	s.helpTouchButton.y = 8
	s.helpTouchButton.h = 22

	
	s.keyboardButton   = _uses(s.touchButton, { padding = 2, w = 35, h = 35 } )
	s.keyboardShift    = _uses(s.touchButton, { padding = 2, w = 75, h = 35 } )
	s.keyboardSpace    = _uses(s.touchButton, { padding = 2, w = 100, h = 35 } )
	s.keyboardBack     = _uses(s.keyboardButton, { img = _loadImage(self, "Icons/Mini/left_arrow.png") } )
	-- FIXME: icon_search.png is incorrect here
	s.keyboardGo       = _uses(s.keyboardButton, { img = _loadImage(self, "Icons/Mini/right_arrow.png") } )
	s.keyboardSearch   = _uses(s.keyboardButton, { img = _loadImage(self, "Icons/Mini/icon_search.png") } )
	s.keyboardSpaceBar = _uses(s.touchButton, { w = WH_FILL } )

	-- wired/wireless text for setup
	s.networkchoiceText = {}
	s.networkchoiceText.order = { 'wifi', 'wired' }
	s.networkchoiceText.position = LAYOUT_NONE

	s.networkchoiceText.x = 0
	s.networkchoiceText.y = screenHeight - 225
	
	s.networkchoiceText.wifi = {}
	s.networkchoiceText.wifi.align = 'center'
	s.networkchoiceText.wifi.font = _boldfont(22)
	s.networkchoiceText.wifi.fg = TEXT_COLOR
	s.networkchoiceText.wifi.w = WH_FILL
	
	s.networkchoiceText.wired = {}
	s.networkchoiceText.wired.align = 'center'
	s.networkchoiceText.wired.font = _boldfont(22)
	s.networkchoiceText.wired.fg = TEXT_COLOR
	s.networkchoiceText.wired.w = WH_FILL


	-- wired/wireless buttons for setup
	s.networkchoice = {}
	s.networkchoice.order = { 'wifi', 'wired' }
	s.networkchoice.position = LAYOUT_NONE

	s.networkchoice.x = screenWidth - 450
	s.networkchoice.y = screenHeight - 200
	
	s.networkchoice.wifi = {}
	s.networkchoice.wifi.align = 'center'
	s.networkchoice.wifi.padding = { 0, 0, 10, 0 }
	s.networkchoice.wifi.img = _loadImage(self, "Setup/wifi.png")
	
	s.networkchoice.wired = {}
	s.networkchoice.wired.align = 'center'
	s.networkchoice.wired.padding = { 10, 0, 0, 0 }
	s.networkchoice.wired.img = _loadImage(self, "Setup/wired.png")

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

	-- XXXX need artwork
	s.wiredEthernetLink = {}
	s.wiredEthernetLink.align = "right"
	s.wiredEthernetLink.img = _loadImage(self, "Icons/icon_nowplaying_indicator_w.png")

	s.wiredEthernetNoLink = {}
	s.wiredEthernetNoLink.align = "right"
	s.wiredEthernetNoLink.img = _loadImage(self, "Icons/icon_nowplaying_indicator_b.png")

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
			return _loadImage(self, "head_home.png")
		end
--]]


	-- SlimBrowser applet

	s.volumeMin = {}
	s.volumeMin.img = _loadImage(self, "volume_speaker_l.png")
	s.volumeMin.border = { 5, 0, 5, 0 }
	s.volumeMax = {}
	s.volumeMax.img = _loadImage(self, "volume_speaker_r.png")
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
				icon = { 
					img = _loadImage(self, "Icons/Mini/icon_albums.png"),
        				padding = { 10, 0, 0, 0 },
				},
				nowplaying = {
        				img     = _loadImage(self, "menu_album_noartwork_24.png"),
        				padding = { 5, 10, 15, 5 },
					align   = "top-right"
				},
				text = { 
					align = 'left',  
					lineHeight = TITLE_FONT_SIZE + 2,
					padding = { 10, 5, 8, 5 }
				},
				-- FIXME: this needs a box like titleBox, but titleBox does not work for a style of this height
				bgImg = false
			}
	)


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
	s.minititle.order         = { "back", "icon", "text", "nowplaying" }
	s.minititle.icon = {}
	s.minititle.icon.padding  = { 0, 0, 0, 4 }
	s.minititle.icon.align    = 'center'
	s.minititle.nowplaying = {}
	s.minititle.nowplaying.img = _loadImage(self, "menu_album_noartwork_24.png")
	s.minititle.nowplaying.bgImg  = selectionBox


	-- Based on s.title, this is for internetradio title style
	s.internetradiotitle =
		_uses(s.minititle, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_internet_radio.png")
			      }
		      })

	-- Based on s.title, this is for favorites title style
	s.favoritestitle = 
		_uses(s.minititle, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_favorites.png")
			      }
		      })

	-- Based on s.title, this is for mymusic title style
	s.mymusictitle =
		_uses(s.minititle, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_music_library.png")
			      }
		      })

	-- Based on s.title, this is for search title style
	s.searchtitle =
		_uses(s.minititle, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_search.png")
			      }
		      })

	-- Based on s.title, this is for settings title style
	s.hometitle =
		_uses(s.minititle, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_home.png")
			      }
		      })

	-- Based on s.title, this is for settings title style
	s.setuptitle =
		_uses(s.minititle, {
				order = { 'back', 'icon', 'text', 'nowplaying' },
				nowplaying = { img = false  },
			      icon = {
				      --img = _loadImage(self, "Icons/Mini/icon_settings.png")
				      img = false
			      }
		      })

	-- first setup page has no back button
	s.setupfirsttitle = 
		_uses(s.setuptitle, {
				back = { img = false },
		
		})

	-- Based on s.title, this is for settings title style
	s.settingstitle =
		_uses(s.minititle, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_settings.png")
			      }
		      })

	-- Based on s.title, this is for newmusic title style
	s.newmusictitle =
		_uses(s.minititle, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_album_new.png")
			      }
		      })

	-- Based on s.title, this is for infobrowser title style
	s.infobrowsertitle =
		_uses(s.minititle, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_info_browser.png")
			      }
		      })

	-- Based on s.title, this is for albumlist title style
	-- NOTE: not to be confused with "album", which is a different style
	s.albumlisttitle =
		_uses(s.minititle, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_albums.png")
			      }
		      })


	-- Based on s.title, this is for artists title style
	s.artiststitle =
		_uses(s.minititle, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_artist.png")
			      }
		      })
	-- Based on s.title, this is for random title style
	s.randomtitle =
		_uses(s.minititle, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_random.png")
			      }
		      })

	-- Based on s.title, this is for musicfolder title style
	s.musicfoldertitle =
		_uses(s.minititle, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_music_folder.png")
			      }
		      })

	-- Based on s.title, this is for genres title style
	s.genrestitle =
		_uses(s.minititle, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_genres.png")
			      }
		      })

	-- Based on s.title, this is for years title style
	s.yearstitle =
		_uses(s.minititle, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_years.png")
			      }
		      })
	-- Based on s.title, this is for playlist title style
	s.playlisttitle =
		_uses(s.minititle, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_playlist.png")
			      }
		      })

	-- Based on s.title, this is for currentplaylist title style
	s.currentplaylisttitle =
		_uses(s.minititle, {
			      icon = {
				      img = _loadImage(self, "Icons/Mini/icon_quarter_note.png")
			      }
		      })


	-- "buttonlike" menu. all items with selection box and icon
	s.buttonmenu = {}
	s.buttonmenu.padding = { 60, 2, 80, 2 }
	s.buttonmenu.itemHeight = 90

	-- items with artwork and song info
	s.buttonitem = {}
	s.buttonitem.order = { "text", "icon" }
	s.buttonitem.padding = { 0, 10, 0, 10 }
	s.buttonitem.bgImg = selectionBox
	s.buttonitem.text = {}
	s.buttonitem.text.w = WH_FILL
	s.buttonitem.text.padding = { 26, 10, 0, 10 }
	s.buttonitem.text.align = "left"
	s.buttonitem.text.font = _boldfont(24)
	s.buttonitem.text.fg = SELECT_COLOR
	s.buttonitem.text.sh = SELECT_SH_COLOR
	s.buttonitem.icon = {
			img   = _loadImage(self, "Icons/selection_right.png"), 
			h     = WH_FILL,
			padding = 25
	}

	-- two button menu specifically for laying out two button menu nicely on fab4 screen
	s.twobuttonmenu = _uses(s.buttonmenu, {
				padding = { 60, 30, 80, 2 }
	})

	-- menus with artwork and song info
	-- FIXME: this needs to be tweaked for Fab4Skin
	s.albummenu = {}
	s.albummenu.padding = { 0, 2, 4, 2 }
	s.albummenu.itemHeight = 76
	s.albummenu.fg = {0xbb, 0xbb, 0xbb }
	s.albummenu.font = _boldfont(250)

	s.multilinemenu = _uses(s.albummenu)

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

	s.multilineitem = _uses(s.albumitem, {
					order = {'text', 'play'}
				})
	-- checked albummenu item
	s.albumchecked =
		_uses(s.albumitem, {
			      order = { "icon", "text", "check" },
			      check = {
				      img = _loadImage(self, "Icons/icon_check_selected.png"),
				      align = "right"

			      }
		      })

	s.multilinechecked = _uses(s.albumchecked, {
					order = {'text', 'check' },
				})

	-- styles for choose player menu
	s.chooseplayer = _uses(s.albumitem, {
				text = { font = FONT_BOLD_13px }
			})
	s.transporter = _uses(s.chooseplayer, {
				icon = {
					img = _loadImage(self, "Icons/Players/transporter.png"),
					w = 56,
				}
			})
	s.transporterchecked = _uses(s.transporter, {
	      		order = { "icon", "text", "check" },
			check = {
				align = "right",
				img = _loadImage(self, "Icons/icon_check_selected.png")
			}
	})

	s.squeezebox = _uses(s.chooseplayer, {
				icon = {
					img = _loadImage(self, "Icons/Players/squeezebox.png"),
				}
			})
	s.squeezeboxchecked = _uses(s.squeezebox, {
	      		order = { "icon", "text", "check" },
			check = {
				align = "right",
				img = _loadImage(self, "Icons/icon_check_selected.png")
			}
	})
	s.squeezebox2 = _uses(s.chooseplayer, {
				icon = {
					img = _loadImage(self, "Icons/Players/squeezebox.png"),
				}
			})
	s.squeezebox2checked = _uses(s.squeezebox2, {
	      		order = { "icon", "text", "check" },
			check = {
				align = "right",
				img = _loadImage(self, "Icons/icon_check_selected.png")
			}
	})
	s.squeezebox3 = _uses(s.chooseplayer, {
				icon = {
					img = _loadImage(self, "Icons/Players/squeezebox3.png"),
				}
			})
	s.squeezebox3checked = _uses(s.squeezebox3, {
	      		order = { "icon", "text", "check" },
			check = {
				align = "right",
				img = _loadImage(self, "Icons/icon_check_selected.png")
			}
	})

	s.boom = _uses(s.chooseplayer, {
				icon = {
					img = _loadImage(self, "Icons/Players/boom.png"),
					w = 56,
				}
			})
	s.boomchecked = _uses(s.boom, {
	      		order = { "icon", "text", "check" },
			check = {
				align = "right",
				img = _loadImage(self, "Icons/icon_check_selected.png")
			}
	})
	s.slimp3 = _uses(s.chooseplayer, {
				icon = {
					img = _loadImage(self, "Icons/Players/slimp3.png"),
				}
			})
	s.slimp3checked = _uses(s.slimp3, {
	      		order = { "icon", "text", "check" },
			check = {
				align = "right",
				img = _loadImage(self, "Icons/icon_check_selected.png")
			}
	})
	s.softsqueeze = _uses(s.chooseplayer, {
				icon = {
					img = _loadImage(self, "Icons/Players/softsqueeze.png"),
				}
			})
	s.softsqueezechecked = _uses(s.softsqueeze, {
	      		order = { "icon", "text", "check" },
			check = {
				align = "right",
				img = _loadImage(self, "Icons/icon_check_selected.png")
			}
	})
	s.controller = _uses(s.chooseplayer, {
				icon = {
					img = _loadImage(self, "Icons/Players/controller.png"),
				}
			})
	s.controllerchecked = _uses(s.controller, {
	      		order = { "icon", "text", "check" },
			check = {
				align = "right",
				img = _loadImage(self, "Icons/icon_check_selected.png")
			}
	})
	s.receiver = _uses(s.chooseplayer, {
				icon = {
					img = _loadImage(self, "Icons/Players/receiver.png"),
				}
			})
	s.receiverchecked = _uses(s.receiver, {
	      		order = { "icon", "text", "check" },
			check = {
				align = "right",
				img = _loadImage(self, "Icons/icon_check_selected.png")
			}
	})
	s.squeezeplay = _uses(s.chooseplayer, {
				icon = {
					img = _loadImage(self, "Icons/Players/squeezeplay.png"),
				}
			})
	s.squeezeplaychecked = _uses(s.squeezeplay, {
	      		order = { "icon", "text", "check" },
			check = {
				align = "right",
				img = _loadImage(self, "Icons/icon_check_selected.png")
			}
	})
	s.http = _uses(s.chooseplayer, {
				icon = {
					img = _loadImage(self, "Icons/Players/http.png"),
				}
			})
	s.httpchecked = _uses(s.http, {
	      		order = { "icon", "text", "check" },
			check = {
				align = "right",
				img = _loadImage(self, "Icons/icon_check_selected.png")
			}
	})
	
	s.albumitemplay = _uses(s.albumitem)
	s.albumitemadd  = _uses(s.albumitem)


	s.albumitem.icon = {}
	s.albumitem.icon.w = 70
	s.albumitem.icon.h = WH_FILL
	s.albumitem.icon.align = "left"
-- FIXME: no_artwork image needed in correct size for Fab4Skin; for now, disable it
--	s.albumitem.icon.img = _loadImage(self, "menu_album_noartwork_125.png")
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
	s.selected.albumitem = _uses(s.albumitem, {
		bgImg = albumSelectionBox,
		text = {
			fg    = SELECT_COLOR,
			sh    = SELECT_SH_COLOR
		},
		play = {
			h      = WH_FILL,
			align  = "right",
			img    = _loadImage(self, "Icons/selection_right.png"),
		},
		icon = {
			w = 70,
			h = 70
		}
	})
	s.selected.multilineitem = _uses(s.selected.albumitem, {
				order = { 'text', 'play' },
			})

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
	s.selected.multilinechecked = _uses(s.selected.multilineitem, {
	      		order = { "text", "check", "play" },
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

	s.selected.transporter = _uses(s.selected.chooseplayer, {
				icon = {
					img = _loadImage(self, "Icons/Players/transporter.png"),
				}
			})
	s.selected.transporterchecked = _uses(s.selected.transporter, {
	      		order = { "icon", "text", "check", "play" },
			check = {
				align = "right",
				img = _loadImage(self, "Icons/icon_check_selected.png")
			}
	})

	s.selected.squeezebox = _uses(s.selected.chooseplayer, {
				icon = {
					img = _loadImage(self, "Icons/Players/squeezebox.png"),
				}
			})
	s.selected.squeezeboxchecked = _uses(s.selected.squeezebox, {
	      		order = { "icon", "text", "check", "play" },
			check = {
				align = "right",
				img = _loadImage(self, "Icons/icon_check_selected.png")
			}
	})


	s.selected.squeezebox2 = _uses(s.selected.chooseplayer, {
				icon = {
					img = _loadImage(self, "Icons/Players/squeezebox.png"),
				}
			})
	s.selected.squeezebox2checked = _uses(s.selected.squeezebox2, {
	      		order = { "icon", "text", "check", "play" },
			check = {
				align = "right",
				img = _loadImage(self, "Icons/icon_check_selected.png")
			}
	})

	s.selected.squeezebox3 = _uses(s.selected.chooseplayer, {
				icon = {
					img = _loadImage(self, "Icons/Players/squeezebox3.png"),
				}
			})
	s.selected.squeezebox3checked = _uses(s.selected.squeezebox3, {
	      		order = { "icon", "text", "check", "play" },
			check = {
				align = "right",
				img = _loadImage(self, "Icons/icon_check_selected.png")
			}
	})


	s.selected.boom = _uses(s.selected.chooseplayer, {
				icon = {
					img = _loadImage(self, "Icons/Players/boom.png"),
				}
			})
	s.selected.boomchecked = _uses(s.selected.boom, {
	      		order = { "icon", "text", "check", "play" },
			check = {
				align = "right",
				img = _loadImage(self, "Icons/icon_check_selected.png")
			}
	})


	s.selected.slimp3 = _uses(s.selected.chooseplayer, {
				icon = {
					img = _loadImage(self, "Icons/Players/slimp3.png"),
				}
			})

	s.selected.slimp3checked = _uses(s.selected.slimp3, {
	      		order = { "icon", "text", "check", "play" },
			check = {
				align = "right",
				img = _loadImage(self, "Icons/icon_check_selected.png")
			}
	})

	s.selected.softsqueeze = _uses(s.selected.chooseplayer, {
				icon = {
					img = _loadImage(self, "Icons/Players/softsqueeze.png"),
				}
			})
	s.selected.softsqueezechecked = _uses(s.selected.softsqueeze, {
	      		order = { "icon", "text", "check", "play" },
			check = {
				align = "right",
				img = _loadImage(self, "Icons/icon_check_selected.png")
			}
	})
	s.selected.controller = _uses(s.selected.chooseplayer, {
				icon = {
					img = _loadImage(self, "Icons/Players/controller.png"),
				}
			})
	s.selected.controllerchecked = _uses(s.selected.controller, {
	      		order = { "icon", "text", "check", "play" },
			check = {
				align = "right",
				img = _loadImage(self, "Icons/icon_check_selected.png")
			}
	})
	s.selected.receiver = _uses(s.selected.chooseplayer, {
				icon = {
					img = _loadImage(self, "Icons/Players/receiver.png"),
				}
			})
	s.selected.receiverchecked = _uses(s.selected.receiver, {
	      		order = { "icon", "text", "check", "play" },
			check = {
				align = "right",
				img = _loadImage(self, "Icons/icon_check_selected.png")
			}
	})
	s.selected.squeezeplay = _uses(s.selected.chooseplayer, {
				icon = {
					img = _loadImage(self, "Icons/Players/squeezeplay.png"),
				}
			})
	s.selected.squeezeplaychecked = _uses(s.selected.squeezeplay, {
	      		order = { "icon", "text", "check", "play" },
			check = {
				align = "right",
				img = _loadImage(self, "Icons/icon_check_selected.png")
			}
	})
	s.selected.http = _uses(s.selected.chooseplayer, {
				icon = {
					img = _loadImage(self, "Icons/Players/http.png"),
				}
			})
	s.selected.httpchecked = _uses(s.selected.http, {
	      		order = { "icon", "text", "check", "play" },
			check = {
				align = "right",
				img = _loadImage(self, "Icons/icon_check_selected.png")
			}
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
			--FIXME, need a resized icon_connecting.png image for the correct albumitem thumb size
			img = _loadImage(self, "Alerts/wifi_connecting_sm.png"),
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
--	s.nowplayingitem.icon.img = _loadImage(self, "menu_album_noartwork_125.png")
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
	s.albumcurrent.play = {}
	s.albumcurrent.play.align = 'top-left'
	s.albumcurrent.play.img = _loadImage(self, "Icons/icon_nowplaying_indicator_w.png")
	s.albumcurrent.play.padding = { 2, 8, 0, 0 }
	

	-- selected now playing menu item
	s.selected.albumcurrent = {}
	s.selected.albumcurrent.bgImg = albumSelectionBox
	s.selected.albumcurrent.text = {}
	s.selected.albumcurrent.text.fg = SELECT_COLOR
	s.selected.albumcurrent.text.sh = SELECT_SH_COLOR
	s.selected.albumcurrent.play = {}
	s.selected.albumcurrent.play.align = 'top-left'
	s.selected.albumcurrent.play.img = _loadImage(self, "Icons/icon_nowplaying_indicator_b.png")
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

	local TEXT_COLOR = { 0xE7, 0xE7, 0xE7 }
	local TEXT_SH_COLOR = { 0x37, 0x37, 0x37 }

	local SELECT_COLOR = { 0x00, 0x00, 0x00 }
	local SELECT_SH_COLOR = { }

	local NP_TRACK_FONT_SIZE = 26

	-- Title
	s.ssnptitle = _uses(s.title, {
				order     = { "back", "text", "playlist" },
				playlist  = {
						padding = { 10, 5, 10, 5 },
						border  = { 0, 0, 0, 5},
						font    = _font(14),
						fg      = TEXT_COLOR_BLACK,
						bgImg   = selectionBox,
						align   = "top-right",
				}
	})

	-- nptitle style is the same for all windowStyles
	s.browsenptitle = _uses(s.ssnptitle)
	s.largenptitle  = _uses(s.ssnptitle)

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

	-- nptrack is identical between all windowStyles
	s.browsenptrack = _uses(s.ssnptrack)
	s.largenptrack  = _uses(s.ssnptrack)

	-- Artwork
	local ARTWORK_SIZE = 190
	local browseArtWidth = ARTWORK_SIZE
	local ssArtWidth = ARTWORK_SIZE

	s.ssnpartwork = {}

	s.ssnpartwork.w = ssArtWidth
	s.ssnpartwork.border = { 10, 40, 10, 0 }
	s.ssnpartwork.position = LAYOUT_WEST
	s.ssnpartwork.align = "center"
	s.ssnpartwork.artwork = {}
	s.ssnpartwork.artwork.align = "center"
	s.ssnpartwork.artwork.padding = 0
	-- FIXME: change name to not be specific to icon width in filename
	s.ssnpartwork.artwork.img = _loadImage(self, "Icons/icon_album_noartwork_336.png")
	s.browsenpartwork = _uses(s.ssnpartwork)
	s.largenpartwork = _uses(s.ssnpartwork)

	s.ssnpcontrols = {}
	s.ssnpcontrols.order = { 'rew', 'play', 'fwd', 'vol' }
	s.ssnpcontrols.position = LAYOUT_NONE

	local topPadding = screenHeight/2 + 10
	local rightPadding = screenWidth/2 - 15
	local buttonPadding = { 10, 5, 10, 5 }
	s.ssnpcontrols.x = rightPadding
	s.ssnpcontrols.y = topPadding
	s.ssnpcontrols.bgImg = softButtonBackground
	
	s.ssnpcontrols.rew = {}
	s.ssnpcontrols.rew.align = 'center'
	s.ssnpcontrols.rew.padding = buttonPadding
	s.ssnpcontrols.rew.img = _loadImage(self, "Screen_Formats/Player_Controls/icon_toolbar_rew.png")
	
	s.ssnpcontrols.play = {}
	s.ssnpcontrols.play.align = 'center'
	s.ssnpcontrols.play.padding = buttonPadding
	s.ssnpcontrols.play.img = _loadImage(self, "Screen_Formats/Player_Controls/icon_toolbar_play.png")
	
	s.ssnpcontrols.pause = {}
	s.ssnpcontrols.pause.align = 'center'
	s.ssnpcontrols.pause.padding = buttonPadding
	s.ssnpcontrols.pause.img = _loadImage(self, "Screen_Formats/Player_Controls/icon_toolbar_pause.png")
	
	
	s.ssnpcontrols.fwd = {}
	s.ssnpcontrols.fwd.align = 'center'
	s.ssnpcontrols.fwd.padding = buttonPadding
	s.ssnpcontrols.fwd.img = _loadImage(self, "Screen_Formats/Player_Controls/icon_toolbar_ffwd.png")

	s.ssnpcontrols.vol = {}
	s.ssnpcontrols.vol.align = 'center'
	s.ssnpcontrols.vol.padding = buttonPadding
	s.ssnpcontrols.vol.img = _loadImage(self, "Screen_Formats/Player_Controls/icon_toolbar_vol_up.png")
	
	s.browsenpcontrols = _uses(s.ssnpcontrols)
	s.largenpcontrols  = _uses(s.ssnpcontrols)

	-- Progress bar
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

	s.ssprogress.elapsed = _uses(s.ssprogress.text)
	s.ssprogress.remain = _uses(s.ssprogress.text)

	s.browseprogress = _uses(s.ssprogress)
	s.largeprogress  = _uses(s.ssprogress)

	s.ssprogressB             = {}
        s.ssprogressB.horizontal  = 1
        s.ssprogressB.bgImg       = sliderBackground
        s.ssprogressB.img         = sliderBar
	s.ssprogressB.position    = LAYOUT_SOUTH
	s.ssprogressB.padding     = { 0, 0, 0, 15 }

	s.browseprogressB = _uses(s.ssprogressB)
	s.largeprogressB  = _uses(s.ssprogressB)

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

	s.ssprogressNB.elapsed = _uses(s.ssprogressNB.text)

	s.browseprogressNB = _uses(s.ssprogressNB)
	s.largeprogressNB  = _uses(s.ssprogressNB)

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

