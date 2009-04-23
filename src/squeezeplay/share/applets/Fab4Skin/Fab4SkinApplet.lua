
--[[
=head1 NAME

applets.Fab4Skin.Fab4SkinApplet - The touch skin for the Squeezebox Touch

=head1 DESCRIPTION

This applet implements the Touch skin for the Squeezebox Touch

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

local jiveMain               = jiveMain
local appletManager          = appletManager


module(..., Framework.constants)
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


function param(self)
        return {
		THUMB_SIZE = 40,
		nowPlayingBrowseArtworkSize = 180,
		nowPlayingSSArtworkSize     = 180,
		nowPlayingLargeArtworkSize  = 180,
        }
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
	if parent == nil then
		log:warn("nil parent in _uses at:\n", debug.traceback())
	end
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
-- The meta arranges for this to be called to skin the interface.
function skin(self, s)
	Framework:setVideoMode(480, 272, 0, false)

	local screenWidth, screenHeight = Framework:getScreenSize()

	--init lastInputType so selected item style is not shown on skin load
	Framework.mostRecentInputType = "mouse"

	-- skin
	local thisSkin = 'touch'
	local skinSuffix = "_" .. thisSkin .. ".png"

	-- Images and Tiles
	local inputTitleBox           = Tile:loadImage( imgpath .. "Titlebar/titlebar.png" )
	local fiveItemBox             = Tile:loadImage( imgpath .. "5_line_lists/tch_5line_divder.png")
	local fiveItemSelectionBox    = Tile:loadImage( imgpath .. "5_line_lists/menu_sel_box_5line.png")
	local fiveItemPressedBox      = Tile:loadImage( imgpath .. "5_line_lists/menu_sel_box_5line_press.png")
	local threeItemSelectionBox   = Tile:loadImage( imgpath .. "3_line_lists/menu_sel_box_3line.png")
	local threeItemPressedBox     = Tile:loadImage( imgpath .. "3_line_lists/menu_sel_box_3item_press.png")
	local backButton              = Tile:loadImage( imgpath .. "Icons/icon_back_button_tb.png")
	local helpButton              = Tile:loadImage( imgpath .. "Icons/icon_help_button_tb.png")
	local nowPlayingButton        = Tile:loadImage( imgpath .. "Icons/icon_nplay_button_tb.png")
	local playlistButton          = Tile:loadImage( imgpath .. "Icons/icon_nplay_list_tb.png")
	local deleteKeyBackground     = Tile:loadImage( imgpath .. "Buttons/button_delete_text_entry.png")
	local deleteKeyPressedBackground = Tile:loadImage( imgpath .. "Buttons/button_delete_text_entry_press.png")

	local keyTopLeft = Tile:loadTiles({
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_bkgrd.png",
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_bkgrd_tl.png",
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_bkgrd_t.png",
		nil,
		nil,
		nil,
		nil,
		nil,
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_bkgrd_l.png",
	})

	local keyTopLeftPressed = Tile:loadTiles({
		imgpath .. "Buttons/keybrd_n_button_press.png",
		imgpath .. "Buttons/keybrd_nw_button_press_tl.png",
		imgpath .. "Buttons/keybrd_n_button_press_t.png",
		nil,
		nil,
		nil,
		nil,
		nil,
		imgpath .. "Buttons/keybrd_nw_button_press_l.png",
	})

	local keyTop = Tile:loadTiles({
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_bkgrd.png",
		nil,
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_bkgrd_t_wvert.png",
		nil,
		nil,
		nil,
		nil,
		nil,
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_divider_vert.png",
	})

	local keyTopPressed = Tile:loadTiles({
		imgpath .. "Buttons/keybrd_n_button_press.png",
		nil,
		imgpath .. "Buttons/keybrd_n_button_press_t.png",
		nil,
		nil,
		nil,
		nil,
		nil,
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_divider_vert.png",
	})

	local keyTopRight = Tile:loadTiles({
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_bkgrd.png",
		nil,
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_bkgrd_t_wvert.png",
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_bkgrd_tr.png",
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_bkgrd_r.png",
		nil,
		nil,
		nil,
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_divider_vert.png",
	})

	local keyTopRightPressed = Tile:loadTiles({
		imgpath .. "Buttons/keybrd_n_button_press.png",
		nil,
		imgpath .. "Buttons/keybrd_n_button_press_t.png",
		imgpath .. "Buttons/keybrd_ne_button_press_tr.png",
		imgpath .. "Buttons/keybrd_ne_button_press_r.png",
		nil,
		nil,
		nil,
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_divider_vert.png",
	})

	local keyLeft = Tile:loadTiles({
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_bkgrd.png",
		imgpath .. "Text_Entry/Keyboard_Touch/keyboardLeftEdge.png",
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_divider_hort.png",
		nil,
		nil,
		nil,
		nil,
		nil,
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_bkgrd_l.png",
	})

	local keyLeftPressed = Tile:loadTiles({
		imgpath .. "Buttons/keyboard_button_press.png",
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		imgpath .. "Buttons/keyboard_button_press.png",
	})

	local keyMiddle = Tile:loadTiles({
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_bkgrd.png",
		nil,
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_divider_hort.png",
		nil,
		nil,
		nil,
		nil,
		nil,
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_divider_vert.png",
	})

	local keyMiddlePressed = Tile:loadTiles({
		imgpath .. "Buttons/keyboard_button_press.png",
		nil,
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_divider_hort.png",
		nil,
		nil,
		nil,
		nil,
		nil,
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_divider_vert.png",
	})

	local keyRight = Tile:loadTiles({
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_bkgrd.png",
		nil,
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_divider_hort.png",
		imgpath .. "Text_Entry/Keyboard_Touch/keyboardRightEdge.png",
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_bkgrd_r.png",
		nil,
		nil,
		nil,
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_divider_vert.png",
	})

	local keyRightPressed = Tile:loadTiles({
		imgpath .. "Buttons/keyboard_button_press.png",
		nil,
		nil,
		nil,
		imgpath .. "Buttons/keyboard_button_press.png",
		nil,
		nil,
		nil,
		nil,
	})

	local keyBottomLeft = Tile:loadTiles({
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_bkgrd.png",
		imgpath .. "Text_Entry/Keyboard_Touch/keyboardLeftEdge.png",
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_divider_hort.png",
		nil,
		nil,
		nil,
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_bkgrd_b.png",
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_bkgrd_bl.png",
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_bkgrd_l.png",
	})

	local keyBottomLeftPressed = Tile:loadTiles({
		imgpath .. "Buttons/keybrd_s_button_press.png",
		imgpath .. "Text_Entry/Keyboard_Touch/keyboardLeftEdge.png",
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_divider_hort.png",
		nil,
		nil,
		nil,
		imgpath .. "Buttons/keybrd_s_button_press_b.png",
		imgpath .. "Buttons/keybrd_sw_button_press_bl.png",
		imgpath .. "Buttons/keybrd_sw_button_press_l.png",
	})

	local keyBottom = Tile:loadTiles({
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_bkgrd.png",
		nil,
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_divider_hort.png",
		nil,
		nil,
		nil,
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_bkgrd_b_wvert.png",
		nil,
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_divider_vert.png",
	})

	local keyBottomPressed = Tile:loadTiles({
		imgpath .. "Buttons/keybrd_s_button_press.png",
		nil,
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_divider_hort.png",
		nil,
		nil,
		nil,
		imgpath .. "Buttons/keybrd_s_button_press_b.png",
		nil,
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_divider_vert.png",
	})

	local keyBottomRight = Tile:loadTiles({
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_bkgrd.png",
		nil,
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_divider_hort.png",
		imgpath .. "Text_Entry/Keyboard_Touch/keyboardRightEdge.png",
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_bkgrd_r.png",
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_bkgrd_br.png",
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_bkgrd_b_wvert.png",
		nil,
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_divider_vert.png",
	})

	local keyBottomRightPressed = Tile:loadTiles({
		imgpath .. "Buttons/keybrd_s_button_press.png",
		nil,
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_divider_hort.png",
		imgpath .. "Text_Entry/Keyboard_Touch/keyboardRightEdge.png",
		imgpath .. "Buttons/keybrd_se_button_press_r.png",
		imgpath .. "Buttons/keybrd_se_button_press_br.png",
		imgpath .. "Buttons/keybrd_s_button_press_b.png",
		nil,
		imgpath .. "Text_Entry/Keyboard_Touch/keyboard_divider_vert.png",
	})

	local titleBox                =
		Tile:loadTiles({
				 imgpath .. "Titlebar/titlebar.png",
				 nil,
				 nil,
				 nil,
				 nil,
				 nil,
				 imgpath .. "Titlebar/titlebar_shadow.png",
				 nil,
				 nil,
		})

	local textinputBackground     = 
		Tile:loadTiles({
				 imgpath .. "Text_Entry/Keyboard_Touch/text_entry_titlebar_box.png",
				 imgpath .. "Text_Entry/Keyboard_Touch/text_entry_titlebar_box_tl.png",
				 imgpath .. "Text_Entry/Keyboard_Touch/text_entry_titlebar_box_t.png",
				 imgpath .. "Text_Entry/Keyboard_Touch/text_entry_titlebar_box_tr.png",
				 imgpath .. "Text_Entry/Keyboard_Touch/text_entry_titlebar_box_r.png",
				 imgpath .. "Text_Entry/Keyboard_Touch/text_entry_titlebar_box_br.png",
				 imgpath .. "Text_Entry/Keyboard_Touch/text_entry_titlebar_box_b.png",
				 imgpath .. "Text_Entry/Keyboard_Touch/text_entry_titlebar_box_bl.png",
				 imgpath .. "Text_Entry/Keyboard_Touch/text_entry_titlebar_box_l.png",
				})

	local pressedTitlebarButtonBox =
		Tile:loadTiles({
					imgpath .. "Buttons/button_titlebar_press.png",
					imgpath .. "Buttons/button_titlebar_tl_press.png",
					imgpath .. "Buttons/button_titlebar_t_press.png",
					imgpath .. "Buttons/button_titlebar_tr_press.png",
					imgpath .. "Buttons/button_titlebar_r_press.png",
					imgpath .. "Buttons/button_titlebar_br_press.png",
					imgpath .. "Buttons/button_titlebar_b_press.png",
					imgpath .. "Buttons/button_titlebar_bl_press.png",
					imgpath .. "Buttons/button_titlebar_l_press.png",
				})

	local titlebarButtonBox =
		Tile:loadTiles({
					imgpath .. "Buttons/button_titlebar.png",
					imgpath .. "Buttons/button_titlebar_tl.png",
					imgpath .. "Buttons/button_titlebar_t.png",
					imgpath .. "Buttons/button_titlebar_tr.png",
					imgpath .. "Buttons/button_titlebar_r.png",
					imgpath .. "Buttons/button_titlebar_br.png",
					imgpath .. "Buttons/button_titlebar_b.png",
					imgpath .. "Buttons/button_titlebar_bl.png",
					imgpath .. "Buttons/button_titlebar_l.png",
				})

-- FIXME: do these need updating for Fab4Skin?
	local helpBox = 
		Tile:loadTiles({
				       imgpath .. "Popup_Menu/helpbox.png",
				       imgpath .. "Popup_Menu/helpbox_tl.png",
				       imgpath .. "Popup_Menu/helpbox_t.png",
				       imgpath .. "Popup_Menu/helpbox_tr.png",
				       imgpath .. "Popup_Menu/helpbox_r.png",
				       imgpath .. "Popup_Menu/helpbox_br.png",
				       imgpath .. "Popup_Menu/helpbox_b.png",
				       imgpath .. "Popup_Menu/helpbox_bl.png",
				       imgpath .. "Popup_Menu/helpbox_l.png",
			       })

	local scrollBackground = 
		Tile:loadVTiles({
					imgpath .. "Scroll_Bar/scrollbar_bkgrd_t.png",
					imgpath .. "Scroll_Bar/scrollbar_bkgrd.png",
					imgpath .. "Scroll_Bar/scrollbar_bkgrd_b.png",
			       })

	local scrollBar = 
		Tile:loadVTiles({
					imgpath .. "Scroll_Bar/scrollbar_body_t.png",
					imgpath .. "Scroll_Bar/scrollbar_body.png",
					imgpath .. "Scroll_Bar/scrollbar_body_b.png",
			       })

	local sliderBackground = Tile:loadImage(imgpath .. "Song_Progress_Bar/SP_Bar_Touch/tch_progressbar_bkgrd.png")
	local sliderBar        = Tile:loadImage(imgpath .. "Song_Progress_Bar/SP_Bar_Touch/tch_progressbar_fill.png")

	local popupBackground  = Tile:loadImage(imgpath .. "Alerts/popup_fullscreen_100.png")

	local textinputCursor = Tile:loadImage(imgpath .. "Text_Entry/Keyboard_Touch/tch_cursor.png")

	local THUMB_SIZE = self:param().THUMB_SIZE
	
	local TITLE_PADDING  = { 0, 15, 0, 15 }
	local CHECK_PADDING  = { 2, 0, 6, 0 }
	local CHECKBOX_RADIO_PADDING  = { 2, 0, 0, 0 }

	local MENU_ITEM_ICON_PADDING = { 0, 0, 8, 0 }
	local MENU_PLAYLISTITEM_TEXT_PADDING = { 16, 1, 9, 1 }

	local MENU_CURRENTALBUM_TEXT_PADDING = { 6, 20, 0, 10 }
	local TEXTAREA_PADDING = { 13, 8, 8, 0 }

	local TEXT_COLOR = { 0xE7, 0xE7, 0xE7 }
	local TEXT_COLOR_BLACK = { 0x00, 0x00, 0x00 }
	local TEXT_SH_COLOR = { 0x37, 0x37, 0x37 }

	local SELECT_COLOR = { 0xE7, 0xE7, 0xE7 }
	local SELECT_SH_COLOR = { }

	local TITLE_HEIGHT = 47
	local TITLE_FONT_SIZE = 20
	local ALBUMMENU_FONT_SIZE = 18
	local ALBUMMENU_SMALL_FONT_SIZE = 14
	local TEXTMENU_FONT_SIZE = 20
	local POPUP_TEXT_SIZE_1 = 34
	local POPUP_TEXT_SIZE_2 = 26
	local TRACK_FONT_SIZE = 18
	local TEXTAREA_FONT_SIZE = 18
	local CENTERED_TEXTAREA_FONT_SIZE = 28

	local TEXTINPUT_FONT_SIZE = 20
	local TEXTINPUT_SELECTED_FONT_SIZE = 24

	local HELP_FONT_SIZE = 18
	local UPDATE_SUBTEXT_SIZE = 20

	local ITEM_ICON_ALIGN   = 'center'
	local ITEM_LEFT_PADDING = 12
	local THREE_ITEM_HEIGHT = 72
	local FIVE_ITEM_HEIGHT = 45
	local TITLE_BUTTON_WIDTH = 76

	local smallSpinny = {
		img = _loadImage(self, "Alerts/wifi_connecting_sm.png"),
		frameRate = 8,
		frameWidth = 26,
		padding = 0,
		h = WH_FILL,
	}
	local largeSpinny = {
		img = _loadImage(self, "Alerts/wifi_connecting.png"),
		position = LAYOUT_CENTER,
		w = WH_FILL,
		align = "center",
		frameRate = 8,
		frameWidth = 120,
		padding = { 0, 0, 0, 10 }
	}
	-- convenience method for removing a button from the window
	local noButton = { 
		img = false, 
		bgImg = false, 
		w = 0 
	}

	local playArrow = { 
		img = _loadImage(self, "Icons/selection_play_3line_on.png"),
	}
	local addArrow  = { 
		img = _loadImage(self, "Icons/selection_add_3line_off.png"),
	}


	---- REVIEWED BELOW THIS LINE ----

--------- CONSTANTS ---------

	local _progressBackground = Tile:loadImage(imgpath .. "Alerts/alert_progress_bar_bkgrd.png")

	local _progressBar = Tile:loadHTiles({
		nil,
		imgpath .. "Alerts/alert_progress_bar_body.png",
	})

	local _songProgressBackground = Tile:loadImage(imgpath .. "Song_Progress_Bar/SP_Bar_Touch/tch_progressbar_bkgrd.png")

	local _songProgressBar = Tile:loadHTiles({
		nil,
		imgpath .. "Song_Progress_Bar/SP_Bar_Touch/tch_progressbar_fill.png",
		imgpath .. "Song_Progress_Bar/SP_Bar_Touch/tch_progressbar_slider.png",
	})

	local _volumeSliderBackground = Tile:loadHTiles({
		imgpath .. "Touch_Toolbar/tch_volumebar_bkgrd_l.png",
		imgpath .. "Touch_Toolbar/tch_volumebar_bkgrd.png",
		imgpath .. "Touch_Toolbar/tch_volumebar_bkgrd_r.png",
	})

	local _volumeSliderBar = Tile:loadHTiles({
		imgpath .. "Touch_Toolbar/tch_volumebar_fill_l.png",
		imgpath .. "Touch_Toolbar/tch_volumebar_fill.png",
		imgpath .. "UNOFFICIAL/tch_volume_slider.png",
	})


--------- DEFAULT WIDGET STYLES ---------
	--
	-- These are the default styles for the widgets 

	s.window = {
		w = screenWidth,
		h = screenHeight,
	}

	-- window with absolute positioning
	s.absolute = _uses(s.window, {
		layout = Window.noLayout,
	})

	s.popup = _uses(s.window, {
		border = { 0, 0, 0, 0 },
		bgImg = popupBackground,
	})

	s.title = {
		h = TITLE_HEIGHT,
		border = 0,
		position = LAYOUT_NORTH,
		bgImg = titleBox,
		padding = { 0, 5, 0, 5 },
		order = { "lbutton", "text", "rbutton" },
		lbutton = {
			border = { 8, 0, 8, 0 },
			h = WH_FILL,
		},
		rbutton = {
			border = { 8, 0, 8, 0 },
			h = WH_FILL,
		},
		text = {
			w = WH_FILL,
			padding = TITLE_PADDING,
			align = "center",
			font = _boldfont(TITLE_FONT_SIZE),
			fg = TEXT_COLOR,
		}
	}

	s.menu = {
		position = LAYOUT_CENTER,
		padding = { 0, 0, 0, 0 },
		itemHeight = FIVE_ITEM_HEIGHT,
		fg = {0xbb, 0xbb, 0xbb },
		font = _boldfont(250),
	}

	s.item = {
		order = { "icon", "text", "arrow" },
		padding = { ITEM_LEFT_PADDING, 0, 8, 0 },
		text = {
			padding = { 0, 0, 2, 0 },
			align = "left",
			w = WH_FILL,
			h = WH_FILL,
			font = _boldfont(TEXTMENU_FONT_SIZE),
			fg = TEXT_COLOR,
			sh = TEXT_SH_COLOR,
		},
		icon = {
			padding = MENU_ITEM_ICON_PADDING,
			align = 'center',
		},
		arrow = {
	      		align = ITEM_ICON_ALIGN,
	      		img = _loadImage(self, "Icons/selection_right_5line.png"),
			padding = { 0, 0, 0, 0 },
		},
		bgImg = fiveItemBox,
	}

	s.item_play = _uses(s.item, { 
		arrow = playArrow 
	})
	s.item_add = _uses(s.item, { 
		arrow = addArrow 
	})

	-- Checkbox
        s.checkbox = {}
	s.checkbox.align = 'center'
	s.checkbox.padding = CHECKBOX_RADIO_PADDING
	s.checkbox.h = WH_FILL
        s.checkbox.img_on = _loadImage(self, "Icons/checkbox_on.png")
        s.checkbox.img_off = _loadImage(self, "Icons/checkbox_off.png")


        -- Radio button
        s.radio = {}
	s.radio.align = 'center'
	s.radio.padding = CHECKBOX_RADIO_PADDING
	s.radio.h = WH_FILL
        s.radio.img_on = _loadImage(self, "Icons/radiobutton_on.png")
        s.radio.img_off = _loadImage(self, "Icons/radiobutton_off.png")

	s.item_choice = _uses(s.item, {
		order  = { 'icon', 'text', 'check' },
		choice = {
			h = WH_FILL,
			padding = CHECKBOX_RADIO_PADDING,
			align = 'right',
			font = _boldfont(TEXTMENU_FONT_SIZE),
			fg = TEXT_COLOR,
			sh = TEXT_SH_COLOR,
		},
	})
	s.item_checked = _uses(s.item, {
		order = { "icon", "text", "check", "arrow" },
		check = {
			align = ITEM_ICON_ALIGN,
			padding = CHECK_PADDING,
			img = _loadImage(self, "Icons/icon_check_5line.png")
	      	}
	})

	s.item_no_arrow = _uses(s.item, {
		order = { 'icon', 'text' },
	})
	s.item_checked_no_arrow = _uses(s.item, {
		order = { 'icon', 'text', 'check' },
	})

	s.selected = {
		item               = _uses(s.item, {
			bgImg = fiveItemSelectionBox
		}),
		item_play           = _uses(s.item_play, {
			bgImg = fiveItemSelectionBox
		}),
		item_add            = _uses(s.item_add, {
			bgImg = fiveItemSelectionBox
		}),
		item_checked        = _uses(s.item_checked, {
			bgImg = fiveItemSelectionBox
		}),
		item_no_arrow        = _uses(s.item_no_arrow, {
			bgImg = fiveItemSelectionBox
		}),
		item_checked_no_arrow = _uses(s.item_checked_no_arrow, {
			bgImg = fiveItemSelectionBox
		}),
		item_choice         = _uses(s.item_choice, {
			bgImg = fiveItemSelectionBox
		}),
	}

	s.pressed = {
		item = _uses(s.item, {
			bgImg = fiveItemPressedBox,
		}),
		item_checked = _uses(s.item_checked, {
			bgImg = fiveItemPressedBox,
		}),
		item_play = _uses(s.item_play, {
			bgImg = fiveItemPressedBox,
		}),
		item_add = _uses(s.item_add, {
			bgImg = fiveItemPressedBox,
		}),
		item_no_arrow = _uses(s.item_no_arrow, {
			bgImg = fiveItemPressedBox,
		}),
		item_checked_no_arrow = _uses(s.item_checked_no_arrow, {
			bgImg = fiveItemPressedBox,
		}),
		item_choice = _uses(s.item_choice, {
			bgImg = fiveItemPressedBox,
		}),
	}

	s.locked = {
		item = _uses(s.pressed.item, {
			arrow = smallSpinny
		}),
		item_checked = _uses(s.pressed.item_checked, {
			arrow = smallSpinny
		}),
		item_play = _uses(s.pressed.item_play, {
			arrow = smallSpinny
		}),
		item_add = _uses(s.pressed.item_add, {
			arrow = smallSpinny
		}),
		item_no_arrow = _uses(s.item_no_arrow, {
			arrow = smallSpinny
		}),
		item_checked_no_arrow = _uses(s.item_checked_no_arrow, {
			arrow = smallSpinny
		}),
	}

	s.help_text = {
		w = WH_FILL,
		position = LAYOUT_CENTER,
		font = _font(HELP_FONT_SIZE),
		fg = TEXT_COLOR,
		bgImg = titleBox,
		align = "left",
		scrollbar = {
			w = 0,
		},
		padding = { 18, 18, 10, 18},
		lineHeight = 23,
	}

	s.help_text_small = _uses(s.help_text, {
		font = _font(14),
		lineHeight = 16,
		padding = { 18, 6, 0, 2 },
	})

	s.scrollbar = {
		w = 42,
		border = 0,
		padding = { 0, 0, 0, 0 },
		horizontal = 0,
		bgImg = scrollBackground,
		img = scrollBar,
		layer = LAYER_CONTENT_ON_STAGE,
	}

	s.text = {
		w = screenWidth,
		padding = TEXTAREA_PADDING,
		font = _boldfont(TEXTAREA_FONT_SIZE),
		fg = TEXT_COLOR,
		sh = TEXT_SH_COLOR,
		align = "left",
	}

	s.slider = {
		border = 10,
                position = LAYOUT_SOUTH,
                horizontal = 1,
                bgImg = _progressBackground,
                img = _progressBar,
	}

	s.slider_group = {
		w = WH_FILL,
		border = { 0, 5, 0, 10 },
		order = { "min", "slider", "max" },
	}


--------- SPECIAL WIDGETS ---------


	-- text input
	s.textinput = {
		h = 36,
		padding = { 6, 0, 6, 0 },
		font = _boldfont(TEXTINPUT_FONT_SIZE),
		cursorFont = _boldfont(TEXTINPUT_SELECTED_FONT_SIZE),
		wheelFont = _boldfont(TEXTINPUT_FONT_SIZE),
		charHeight = TEXTINPUT_SELECTED_FONT_SIZE,
		fg = TEXT_COLOR_BLACK,
		charOffsetY = 8,
		wh = { 0x55, 0x55, 0x55 },
		cursorImg = textinputCursor,
	}

	-- keyboard
	s.keyboard = {
		w = WH_FILL,
		h = WH_FILL,
		border = { 8, 6, 8, 0 },
		padding = { 2, 0, 2, 0 },
	}

	s.keyboard_textinput = {
		bgImg = textinputBackground,
		w = WH_FILL,
		order = { "textinput", "backspace" },
		border = 0,
		textinput = {
			padding = { 16, 0, 0, 4 },
		},
	}

	s.keyboard.key = {
        	font = _boldfont(24),
        	fg = { 0xDC, 0xDC, 0xDC },
        	align = 'center',
		bgImg = keyMiddle,
	}

	s.keyboard.key_topLeft     = _uses(s.keyboard.key, { bgImg = keyTopLeft })
	s.keyboard.key_top         = _uses(s.keyboard.key, { bgImg = keyTop })
	s.keyboard.key_topRight    = _uses(s.keyboard.key, { bgImg = keyTopRight })
	s.keyboard.key_left        = _uses(s.keyboard.key, { bgImg = keyLeft })
	s.keyboard.key_middle      = _uses(s.keyboard.key, { bgImg = keyMiddle })
	s.keyboard.key_right       = _uses(s.keyboard.key, { bgImg = keyRight })
	s.keyboard.key_bottomLeft  = _uses(s.keyboard.key, { bgImg = keyBottomLeft })
	s.keyboard.key_bottom      = _uses(s.keyboard.key, { bgImg = keyBottom })
	s.keyboard.key_bottomRight = _uses(s.keyboard.key, { bgImg = keyBottomRight })

	-- styles for keys that use smaller font 
	s.keyboard.key_bottom_small      = _uses(s.keyboard.key_bottom, { font = _boldfont(18) } )
	s.keyboard.key_bottomRight_small = _uses(s.keyboard.key_bottomRight, { 
			font = _boldfont(18), 
			fg = { 0xe7, 0xe7, 0xe7 },
	} )
	s.keyboard.key_bottomLeft_small  = _uses(s.keyboard.key_bottomLeft, { font = _boldfont(18) } )
	s.keyboard.key_left_small        = _uses(s.keyboard.key_left, { font = _boldfont(18) } )


	s.keyboard.spacer_topLeft     = _uses(s.keyboard.key_topLeft)
	s.keyboard.spacer_top         = _uses(s.keyboard.key_top)
	s.keyboard.spacer_topRight    = _uses(s.keyboard.key_topRight)
	s.keyboard.spacer_left        = _uses(s.keyboard.key_left)
	s.keyboard.spacer_middle      = _uses(s.keyboard.key_middle)
	s.keyboard.spacer_right       = _uses(s.keyboard.key_right)
	s.keyboard.spacer_bottomLeft  = _uses(s.keyboard.key_bottomLeft)
	s.keyboard.spacer_bottom      = _uses(s.keyboard.key_bottom)
	s.keyboard.spacer_bottomRight = _uses(s.keyboard.key_bottomRight)

	s.keyboard.shiftOff = _uses(s.keyboard.key_left, {
		img = _loadImage(self, "Icons/icon_shift_off.png"),
		padding = { 1, 0, 0, 0 },
	})
	s.keyboard.shiftOn = _uses(s.keyboard.key_left, {
		img = _loadImage(self, "Icons/icon_shift_on.png"),
		padding = { 1, 0, 0, 0 },
	})

	s.keyboard.arrow_left_middle = _uses(s.keyboard.key_middle, {
		img = _loadImage(self, "Icons/icon_arrow_left.png")
	})
	s.keyboard.arrow_right_right = _uses(s.keyboard.key_right, {
		img = _loadImage(self, "Icons/icon_arrow_right.png")
	})
	s.keyboard.arrow_left_bottom = _uses(s.keyboard.key_bottom, {
		img = _loadImage(self, "Icons/icon_arrow_left.png")
	})
	s.keyboard.arrow_right_bottom = _uses(s.keyboard.key_bottom, {
		img = _loadImage(self, "Icons/icon_arrow_right.png")
	})


	s.keyboard.done = {
		text = _uses(s.keyboard.key_bottomRight_small, {
			text = self:string("ENTER_SMALL"),
			fg = { 0x00, 0xbe, 0xbe },
			h = WH_FILL,
			padding = { 0, 0, 0, 1 },
		}),
		icon = { hidden = 1 },
	}

	s.keyboard.doneDisabled =  _uses(s.keyboard.done, {
		text = {
			fg = { 0x66, 0x66, 0x66 },
		}
	})

	s.keyboard.doneSpinny =  {
                icon = _uses(s.keyboard.key_bottomRight, {
			bgImg = keyBottomRight,
			hidden = 0,
                        img = _loadImage(self, "Alerts/wifi_connecting_sm.png"),
			frameRate = 8,
			frameWidth = 26,
			w = WH_FILL, 
			h = WH_FILL,
			align = 'center',
		}),
		text = { hidden = 1, w = 0 },
        }


	s.keyboard.space = _uses(s.keyboard.key_bottom_small, {
		bgImg = keyBottom,
		text = self:string("SPACEBAR_SMALL"),
	})

	s.keyboard.pressed = {
		shiftOff = _uses(s.keyboard.shiftOff, {
			bgImg = keyLeftPressed
		}),
		shiftOn = _uses(s.keyboard.shiftOn, {
			bgImg = keyLeftPressed
		}),
		done = _uses(s.keyboard.done, {
			bgImg = keyBottomRightPressed,
		}),
		doneDisabled = _uses(s.keyboard.doneDisabled, {
			-- disabled, not set
		}),
		doneSpinny = _uses(s.keyboard.doneSpinny, {
			-- disabled, not set
		}),
		space = _uses(s.keyboard.space, {
			bgImg = keyBottomPressed
		}),
		arrow_right_bottom = _uses(s.keyboard.arrow_right_bottom, {
			bgImg = keyBottomPressed
		}),
		arrow_right_right = _uses(s.keyboard.arrow_right_right, {
			bgImg = keyRightPressed
		}),
		arrow_left_bottom = _uses(s.keyboard.arrow_left_bottom, {
			bgImg = keyBottomPressed
		}),
		arrow_left_middle = _uses(s.keyboard.arrow_left_middle, {
			bgImg = keyMiddlePressed
		}),
		key = _uses(s.keyboard.key, {
			bgImg = keyMiddlePressed
		}),
		key_topLeft     = _uses(s.keyboard.key_topLeft, {
			bgImg = keyTopLeftPressed
		}),
		key_top         = _uses(s.keyboard.key_top, {
			bgImg = keyTopPressed
		}),
		key_topRight    = _uses(s.keyboard.key_topRight, {
			bgImg = keyTopRightPressed
		}),
		key_left        = _uses(s.keyboard.key_left, {
			bgImg = keyLeftPressed
		}),
		key_middle      = _uses(s.keyboard.key_middle, {
			bgImg = keyMiddlePressed
		}),
		key_right       = _uses(s.keyboard.key_right, {
			bgImg = keyRightPressed
		}),
		key_bottomLeft  = _uses(s.keyboard.key_bottomLeft, {
			bgImg = keyBottomLeftPressed
		}),
		key_bottom      = _uses(s.keyboard.key_bottom, {
			bgImg = keyBottomPressed
		}),
		key_bottomRight = _uses(s.keyboard.key_bottomRight, {
			bgImg = keyBottomRightPressed
		}),
		key_left_small  = _uses(s.keyboard.key_left_small, {
			bgImg = keyLeftPressed
		}),
		key_bottomLeft_small  = _uses(s.keyboard.key_bottomLeft_small, {
			bgImg = keyBottomLeftPressed
		}),
		key_bottom_small      = _uses(s.keyboard.key_bottom_small, {
			bgImg = keyBottomPressed
		}),
		key_bottomRight_small = _uses(s.keyboard.key_bottomRight_small, {
			bgImg = keyBottomRightPressed
		}),

		spacer_topLeft     = _uses(s.keyboard.spacer_topLeft),
		spacer_top         = _uses(s.keyboard.spacer_top),
		spacer_topRight    = _uses(s.keyboard.spacer_topRight),
		spacer_left        = _uses(s.keyboard.spacer_left),
		spacer_middle      = _uses(s.keyboard.spacer_middle),
		spacer_right       = _uses(s.keyboard.spacer_right),
		spacer_bottomLeft  = _uses(s.keyboard.spacer_bottomLeft),
		spacer_bottom      = _uses(s.keyboard.spacer_bottom),
		spacer_bottomRight = _uses(s.keyboard.spacer_bottomRight),
}

	-- one set for buttons, one for spacers

--------- WINDOW STYLES ---------
	--
	-- These styles override the default styles for a specific window

	-- typical text list window
	s.text_list = _uses(s.window)

	-- popup "spinny" window
	s.waiting_popup = _uses(s.popup)

	s.waiting_popup.text = {
		w = WH_FILL,
		h = (POPUP_TEXT_SIZE_1 + 8 ) * 2,
		position = LAYOUT_NORTH,
		border = { 0, 14, 0, 4 },
		padding = { 15, 0, 15, 0 },
		align = "center",
		font = _font(POPUP_TEXT_SIZE_1),
		lineHeight = POPUP_TEXT_SIZE_1 + 8,
		fg = TEXT_COLOR,
		sh = TEXT_SH_COLOR,
	}

	s.waiting_popup.subtext = {
		w = WH_FILL,
		h = 47,
		position = LAYOUT_SOUTH,
		border = 0,
		padding = { 15, 0, 15, 0 },
		--padding = { 0, 0, 0, 26 },
		align = "top",
		font = _boldfont(POPUP_TEXT_SIZE_2),
		fg = TEXT_COLOR,
		sh = TEXT_SH_COLOR,
	}

	-- input window (including keyboard)
	s.input = _uses(s.window)
	s.input.title = _uses(s.title, {
		-- remove 3px from the height and 3px from the bottom padding
		h = 44,
		padding = { 0, 5, 0, 2 },
		bgImg = inputTitleBox,
	})

	-- update window
	s.update_popup = _uses(s.popup)

	s.update_popup.text = {
		w = WH_FILL,
		h = (POPUP_TEXT_SIZE_1 + 8 ) * 2,
		position = LAYOUT_NORTH,
		border = { 0, 20, 0, 4 },
		padding = { 15, 0, 15, 0 },
		align = "center",
		font = _font(POPUP_TEXT_SIZE_1),
		lineHeight = POPUP_TEXT_SIZE_1 + 8,
		fg = TEXT_COLOR,
		sh = TEXT_SH_COLOR,
	}

	s.update_popup.subtext = {
		w = WH_FILL,
		-- note this is a hack as the height and padding push
		-- the content out of the widget bounding box.
		h = 30,
		padding = { 0, 0, 0, 30 },
		font = _boldfont(UPDATE_SUBTEXT_SIZE),
		fg = TEXT_COLOR,
		sh = TEXT_SH_COLOR,
		align = "bottom",
		position = LAYOUT_SOUTH,
	}

	s.update_popup.progress = {
		border = { 24, 7, 24, 7 },
		position = LAYOUT_SOUTH,
		horizontal = 1,
		bgImg = _progressBackground,
		img = _progressBar,
	}

	-- icon_list window
	s.icon_list = _uses(s.window, {
		menu = {
			item = {
				order = { "icon", "text", "arrow" },
				padding = { ITEM_LEFT_PADDING, 0, 0, 0 },
				text = {
					w = WH_FILL,
					h = WH_FILL,
					align = 'left',
					font = _font(ALBUMMENU_SMALL_FONT_SIZE),
					line = {
						{
							font = _boldfont(ALBUMMENU_FONT_SIZE),
							height = 22,
						},
						{
							font = _font(ALBUMMENU_SMALL_FONT_SIZE),
						},
					},
					fg = TEXT_COLOR,
					sh = TEXT_SH_COLOR,
				},
				icon = {
					h = THUMB_SIZE,
					padding = MENU_ITEM_ICON_PADDING,
					align = 'center',
				},
				arrow = _uses(s.item.arrow),
			},
		},
	})


	s.icon_list.menu.item_checked = _uses(s.icon_list.menu.item, {
		order = { 'icon', 'text', 'check', 'arrow' },
		check = {
			align = ITEM_ICON_ALIGN,
			padding = CHECK_PADDING,
			img = _loadImage(self, "Icons/icon_check_5line.png")
		},
	})
	s.icon_list.menu.albumcurrent = _uses(s.icon_list.menu.item_checked)
	s.icon_list.menu.item_play = _uses(s.icon_list.menu.item, { 
		arrow = playArrow, 
	})
	s.icon_list.menu.item_add  = _uses(s.icon_list.menu.item, { 
		arrow = addArrow,
	})
	s.icon_list.menu.item_no_arrow = _uses(s.icon_list.menu.item, {
		order = { 'icon', 'text' },
	})
	s.icon_list.menu.item_checked_no_arrow = _uses(s.icon_list.menu.item_checked, {
		order = { 'icon', 'text', 'check' },
	})

	s.icon_list.menu.selected = {
                item               = _uses(s.icon_list.menu.item, {
			bgImg = fiveItemSelectionBox
		}),
                albumcurrent       = _uses(s.icon_list.menu.albumcurrent, {
			bgImg = fiveItemSelectionBox
		}),
                item_checked        = _uses(s.icon_list.menu.item_checked, {
			bgImg = fiveItemSelectionBox
		}),
		item_play           = _uses(s.icon_list.menu.item_play, {
			bgImg = fiveItemSelectionBox
		}),
		item_add            = _uses(s.icon_list.menu.item_add, {
			bgImg = fiveItemSelectionBox
		}),
		item_no_arrow        = _uses(s.icon_list.menu.item_no_arrow, {
			bgImg = fiveItemSelectionBox
		}),
		item_checked_no_arrow = _uses(s.icon_list.menu.item_checked_no_arrow, {
			bgImg = fiveItemSelectionBox
		}),
        }
        s.icon_list.menu.pressed = {
                item = _uses(s.icon_list.menu.item, { 
			bgImg = threeItemPressedBox 
		}),
                item_checked = _uses(s.icon_list.menu.item_checked, { 
			bgImg = threeItemPressedBox 
		}),
                item_play = _uses(s.icon_list.menu.item_play, { 
			bgImg = threeItemPressedBox 
		}),
                item_add = _uses(s.icon_list.menu.item_add, { 
			bgImg = threeItemPressedBox 
		}),
                item_no_arrow = _uses(s.icon_list.menu.item_no_arrow, { 
			bgImg = threeItemPressedBox 
		}),
                item_checked_no_arrow = _uses(s.icon_list.menu.item_checked_no_arrow, { 
			bgImg = threeItemPressedBox 
		}),
        }
	s.icon_list.menu.locked = {
		item = _uses(s.icon_list.menu.pressed.item, {
			arrow = smallSpinny
		}),
		item_checked = _uses(s.icon_list.menu.pressed.item_checked, {
			arrow = smallSpinny
		}),
		item_play = _uses(s.icon_list.menu.pressed.item_play, {
			arrow = smallSpinny
		}),
		item_add = _uses(s.icon_list.menu.pressed.item_add, {
			arrow = smallSpinny
		}),
	}


	-- list window with help text
	s.help_list = _uses(s.text_list)

--[[
	-- BUG 11662, help_list used to have the top textarea fill the available space. That's been removed, but leaving this code in for now as an example of how to do that
	s.help_list = _uses(s.window)

	s.help_list.menu = _uses(s.menu, {
		position = LAYOUT_SOUTH,
		maxHeight = FIVE_ITEM_HEIGHT * 3,
		itemHeight = FIVE_ITEM_HEIGHT,
	})

	s.help_list.help_text = _uses(s.help_text, {
		h = WH_FILL,
		align = "left"
	})
--]]

	-- error window
	-- XXX: needs layout
	s.error = _uses(s.help_list)


	-- information window
	s.information = _uses(s.window)

	s.information.text = {
		font = _font(TEXTAREA_FONT_SIZE),
		fg = TEXT_COLOR,
		sh = TEXT_SH_COLOR,
		padding = { 18, 18, 10, 0},
		lineHeight = 23,
	}

	-- help window (likely the same as information)
	s.help_info = _uses(s.information)


	--track_list window
	-- XXXX todo
	-- identical to text_list but has icon in upper left of titlebar
	s.track_list = _uses(s.text_list)

	s.track_list.title = _uses(s.title, {
		order = { 'lbutton', 'icon', 'text', 'rbutton' },
		icon  = {
			w = THUMB_SIZE,
			h = WH_FILL,
			padding = { 10, 1, 8, 1 },
		},
	})

	--playlist window
	-- identical to icon_list but with some different formatting on the text
	s.play_list = _uses(s.icon_list, {
		menu = {
			item = {
				text = {
					padding = MENU_PLAYLISTITEM_TEXT_PADDING,
					line = {
						{
							font = _boldfont(ALBUMMENU_FONT_SIZE),
							height = ALBUMMENU_FONT_SIZE
						},
						{
							height = ALBUMMENU_SMALL_FONT_SIZE + 2
						},
						{
							height = ALBUMMENU_SMALL_FONT_SIZE + 2
						},
					},	
				},
			},
		},
	})
	s.play_list.menu.item_checked = _uses(s.play_list.menu.item, {
		order = { 'icon', 'text', 'check', 'arrow' },
		check = {
			align = ITEM_ICON_ALIGN,
			padding = CHECK_PADDING,
			img = _loadImage(self, "Icons/icon_check_5line.png")
		},
	})
	s.play_list.menu.selected = {
                item = _uses(s.play_list.menu.item, {
			bgImg = fiveItemSelectionBox
		}),
                item_checked = _uses(s.play_list.menu.item_checked, {
			bgImg = fiveItemSelectionBox
		}),
        }
        s.play_list.menu.pressed = {
                item = _uses(s.play_list.menu.item, { bgImg = threeItemPressedBox }),
                item_checked = _uses(s.play_list.menu.item_checked, { bgImg = threeItemPressedBox }),
        }
	s.play_list.menu.locked = {
		item = _uses(s.play_list.menu.pressed.item, {
			arrow = smallSpinny
		}),
		item_checked = _uses(s.play_list.menu.pressed.item_checked, {
			arrow = smallSpinny
		}),
	}


	-- toast_popup popup with art and text
	s.toast_popup = {
		x = 5,
		y = screenHeight/2 - 93/2,
		w = screenWidth - 10,
		h = 93,
		bgImg = helpBox,
		group = {
			padding = 10,
			order = { 'icon', 'text' },
		text = { 
				padding = { 10, 12, 12, 12 } ,
				align = 'top-left',
				w = WH_FILL,
				h = WH_FILL,
				font = _font(HELP_FONT_SIZE),
				lineHeight = HELP_FONT_SIZE + 5,
			},
			icon = { 
				align = 'top-left', 
				border = { 12, 12, 0, 0 },
				img = _loadImage(self, "UNOFFICIAL/menu_album_noartwork_64.png"),
				h = WH_FILL,
				w = 64,
			}
		}
	}
	-- toast popup with textarea
	s.toast_popup_text = _uses(s.toast_popup, {
		group = {
			order = { 'text' },
			text = {
				w = WH_FILL,
				h = WH_FILL,
				align = 'top-left',
				padding = { 10, 12, 12, 12 },
			},
		}
	})
	
	-- slider popup (volume/scanner)
	s.slider_popup = {
		x = 50,
		y = screenHeight/2 - 50,
		w = screenWidth - 100,
		h = 100,
		bgImg = helpBox,
		title = {
		      border = 10,
		      fg = TEXT_COLOR,
		      font = FONT_BOLD_15px,
		      align = "center",
		      bgImg = false,
		},
		text = _uses(s.text, {
			padding = { 20, 20, 0, 10 },
		}),
		slider_group = {
			w = WH_FILL,
			padding = { 10, 0, 10, 0 },
			order = { "min", "slider", "max" },
		},
	}

	s.image_popup = _uses(s.popup, {
		image = {
			align = "center",
		},
	})


--------- SLIDERS ---------


	s.volume_slider = {
		w = WH_FILL,
		border = { 0, 0, 0, 10 },
                bgImg = _volumeSliderBackground,
                img = _volumeSliderBar,
	}

--------- BUTTONS ---------

	-- base button
	local _button = {
		bgImg = titlebarButtonBox,
		w = TITLE_BUTTON_WIDTH,
		h = WH_FILL,
		border = { 8, 0, 8, 0 },
		icon = {
			w = WH_FILL,
			h = WH_FILL,
			hidden = 1,
			align = 'center',
			img = false,
		},
		text = {
			w = WH_FILL,
			h = WH_FILL,
			hidden = 1,
			border = 0,
			padding = 0,
			align = 'center',
			font = _font(16),
			fg = { 0xdc,0xdc, 0xdc },
		},
	}
	local _pressed_button = _uses(_button, {
		bgImg = pressedTitlebarButtonBox,
	})


	-- icon button factory
	local _titleButtonIcon = function(name, icon, attr)
		s[name] = _uses(_button)
		s.pressed[name] = _uses(_pressed_button)

		attr = {
			hidden = 0,
			img = icon
		}

		s[name].icon = _uses(_button.icon, attr)
		s[name].w = 65
		s.pressed[name].icon = _uses(_pressed_button.icon, attr)
		s.pressed[name].w = 65
	end

	-- text button factory
	local _titleButtonText = function(name, string)
		s[name] = _uses(_button)
		s.pressed[name] = _uses(_pressed_button)

		attr = {
			hidden = 0,
			text = string,
		}

		s[name].text = _uses(_button.text, attr)
		s[name].w = 65
		s.pressed[name].text = _uses(_pressed_button.text, attr)
		s.pressed[name].w = 65
	end


	-- invisible button
	s.button_none = _uses(_button, {
		bgImg    = false
	})

	_titleButtonIcon("button_back", backButton)
	_titleButtonIcon("button_playlist", playlistButton)
	_titleButtonIcon("button_go_now_playing", nowPlayingButton)
	_titleButtonIcon("button_help", helpButton)
	_titleButtonText("button_more_help", self:string("MORE_HELP"))

	s.button_back.padding = { 2, 0, 0, 2 }

	s.button_volume_min = {
		img = _loadImage(self, "Icons/icon_toolbar_vol_down.png"),
		border = { 5, 0, 5, 0 },
	}

	s.button_volume_max = {
		img = _loadImage(self, "Icons/icon_toolbar_vol_up.png"),
		border = { 5, 0, 5, 0 },
	}

	s.button_keyboard_back = {
		align = 'left',
		w = 48,
		h = 33,
		padding = { 8, 0, 0, 0 },
		border = { 0, 2, 9, 5}, 
		img = _loadImage(self, "Icons/icon_delete_tch_text_entry.png"),
		bgImg = deleteKeyBackground,
	}
	s.pressed.button_keyboard_back = _uses(s.button_keyboard_back, {
                bgImg = deleteKeyPressedBackground,
	})


	local _buttonicon = {
		h   = THUMB_SIZE,
		padding = MENU_ITEM_ICON_PADDING,
		align = 'center',
		img = false,
	}

	s.region_US = _uses(_buttonicon, { 
		img = _loadImage(self, "IconsResized/icon_region_americas" .. skinSuffix),
	})
	s.region_XX = _uses(_buttonicon, { 
		img = _loadImage(self, "IconsResized/icon_region_other" .. skinSuffix),
	})
	s.wlan = _uses(_buttonicon, {
		img = _loadImage(self, "IconsResized/icon_wireless" .. skinSuffix),
	})
	s.wired = _uses(_buttonicon, {
		img = _loadImage(self, "IconsResized/icon_ethernet" .. skinSuffix),
	})


--------- ICONS --------

	-- icons used for 'waiting' and 'update' windows
	local _icon = {
		w = WH_FILL,
		align = "center",
		position = LAYOUT_CENTER,
		padding = { 0, 0, 0, 10 }
	}

	-- icon for albums with no artwork
	s.icon_no_artwork = {
		img = _loadImage(self, "IconsResized/icon_album_noart" .. skinSuffix ),
		h   = THUMB_SIZE,
		padding = MENU_ITEM_ICON_PADDING,
		align = 'center',
	}

	s.icon_connecting = _uses(_icon, {
		img = _loadImage(self, "Alerts/wifi_connecting.png"),
		frameRate = 8,
		frameWidth = 120,
	})

	s.icon_connected = _uses(_icon, {
		img = _loadImage(self, "Alerts/connecting_success_icon.png"),
	})

	s.icon_software_update = _uses(_icon, {
		img = _loadImage(self, "IconsResized/icon_firmware_update" .. skinSuffix),
	})

	s.icon_restart = _uses(_icon, {
		img = _loadImage(self, "IconsResized/icon_restart" .. skinSuffix),
	})


	s.icon_power = _uses(_icon, {
-- FIXME no asset for this (needed?)
--		img = _loadImage(self, "Alerts/popup_shutdown_icon.png"),
	})

	s.icon_locked = _uses(_icon, {
-- FIXME no asset for this (needed?)
--		img = _loadImage(self, "Alerts/popup_locked_icon.png"),
	})

	s.icon_alarm = _uses(_icon, {
-- FIXME no asset for this (needed?)
--		img = _loadImage(self, "Alerts/popup_alarm_icon.png"),
	})

	s.player_transporter = _uses(_buttonicon, {
		img = _loadImage(self, "IconsResized/icon_transporter" .. skinSuffix),
	})
	s.player_squeezebox = _uses(_buttonicon, {
		img = _loadImage(self, "IconsResized/icon_SB1n2" .. skinSuffix),
	})
	s.player_squeezebox2 = _uses(_buttonicon, {
		img = _loadImage(self, "IconsResized/icon_SB1n2" .. skinSuffix),
	})
	s.player_squeezebox3 = _uses(_buttonicon, {
		img = _loadImage(self, "IconsResized/icon_SB3" .. skinSuffix),
	})
	s.player_boom = _uses(_buttonicon, {
		img = _loadImage(self, "IconsResized/icon_boom" .. skinSuffix),
	})
	s.player_slimp3 = _uses(_buttonicon, {
		img = _loadImage(self, "IconsResized/icon_slimp3" .. skinSuffix),
	})
	s.player_softsqueeze = _uses(_buttonicon, {
		img = _loadImage(self, "IconsResized/icon_softsqueeze" .. skinSuffix),
	})
	s.player_controller = _uses(_buttonicon, {
		img = _loadImage(self, "IconsResized/icon_controller" .. skinSuffix),
	})
	s.player_receiver = _uses(_buttonicon, {
		img = _loadImage(self, "IconsResized/icon_receiver" .. skinSuffix),
	})
	s.player_squeezeplay = _uses(_buttonicon, {
		img = _loadImage(self, "IconsResized/icon_squeezeplay" .. skinSuffix),
	})
	s.player_http = _uses(_buttonicon, {
		img = _loadImage(self, "IconsResized/icon_softsqueeze" .. skinSuffix),
	})
	s.player_fab4 = _uses(_buttonicon, {
		img = _loadImage(self, "IconsResized/icon_fab4" .. skinSuffix),
	})

	-- indicator icons, on right of menus
	local _indicator = {
		align = "center",
	}

	s.wirelessLevel1 = _uses(_indicator, {
		img = _loadImage(self, "Icons/icon_wireless_1.png")
	})

	s.wirelessLevel2 = _uses(_indicator, {
		img = _loadImage(self, "Icons/icon_wireless_2.png")
	})

	s.wirelessLevel3 = _uses(_indicator, {
		img = _loadImage(self, "Icons/icon_wireless_3.png")
	})

	s.wirelessLevel4 = _uses(_indicator, {
		img = _loadImage(self, "Icons/icon_wireless_4.png")
	})


--------- ICONBAR ---------

	s.iconbar_group = {
		hidden = 1,
	}

	-- time (hidden off screen)
	s.button_time = {
		hidden = 1,
	}



--------- LEGACY STYLES TO KEEP SLIMBROWSER GOING --------
if true then

	-- XXXX todo

	-- BEGIN NowPlaying skin code
	-- this skin is established in two forms,
	-- one for the Screensaver windowStyle (ss), one for the browse windowStyle (browse)
	-- a lot of it can be recycled from one to the other

	local NP_ARTISTALBUM_FONT_SIZE = 20
	local NP_TRACK_FONT_SIZE = 24

	-- Title
	s.ssnptitle = _uses(s.title, {
		rbutton  = {
			font    = _font(14),
			fg      = TEXT_COLOR,
			bgImg   = titlebarButtonBox,
			w       = TITLE_BUTTON_WIDTH,
			padding = { 8, 0, 8, 0},
			align   = 'center',
		}
	})

	-- nptitle style is the same for all windowStyles
	s.browsenptitle = _uses(s.ssnptitle)
	s.largenptitle  = _uses(s.ssnptitle)


	-- pressed styles
	s.ssnptitle.pressed = _uses(s.ssnptitle, {
		lbutton = {
			bgImg = pressedTitlebarButtonBox,
		},
		rbutton = {
			bgImg = pressedTitlebarButtonBox,
		},
	})

	s.browsenptitle.pressed = _uses(s.ssnptitle.pressed)
	s.largenptitle.pressed = _uses(s.ssnptitle.pressed)

	-- Artwork
	local ARTWORK_SIZE    = self:param().nowPlayingBrowseArtworkSize
	local SS_ARTWORK_SIZE = self:param().nowPlayingSSArtworkSize
	local browseArtWidth  = ARTWORK_SIZE
	local ssArtWidth      = SS_ARTWORK_SIZE

	-- Song
	s.nptrack =  {
		border = { 4, 0, 4, 0 },
		position = LAYOUT_NORTH,
		w = WH_FILL,
		padding = { ARTWORK_SIZE + 18, TITLE_HEIGHT + 20, 20, 10 },
		align = "left",
		font = _boldfont(NP_TRACK_FONT_SIZE), 
		lineHeight = NP_TRACK_FONT_SIZE,
		fg = TEXT_COLOR,
	}
	s.npartist  = _uses(s.nptrack, { 
		padding = { ARTWORK_SIZE + 18, TITLE_HEIGHT + 55, 20, 10 },
		font = _font(NP_ARTISTALBUM_FONT_SIZE),
	})
	s.npalbum = _uses(s.npartist, { 
		padding = { ARTWORK_SIZE + 18, TITLE_HEIGHT + 85, 20, 10 },
		font = _font(NP_ARTISTALBUM_FONT_SIZE),
	})

	s.ssnpartwork = {
		w = ssArtWidth,
		border = { 8, TITLE_HEIGHT + 4, 10, 0 },
		position = LAYOUT_WEST,
		align = "center",
		artwork = {
			align = "center",
			padding = 0,
			-- FIXME: this is a placeholder
			img = _loadImage(self, "UNOFFICIAL/icon_album_noartwork_190.png"),
		},
	}

	s.browsenpartwork = _uses(s.ssnpartwork)
	s.largenpartwork = _uses(s.ssnpartwork)

	local controlHeight = 38
	local controlWidth = 45
	local volumeBarWidth = 150
	local remainingToolbarSpace = screenWidth - 5*controlWidth - volumeBarWidth
	local buttonPadding = 0

	local _transportControlButton = {
		w = controlWidth,
		h = controlHeight,
		align = 'center',
		padding = buttonPadding,
		--FIXME, wrong asset to use for these. this is a placeholder
		bgImg = keyMiddle,
	}

	s.toolbar_spacer = _uses(_transportControlButton, {
		w = remainingToolbarSpace,
	})

	s.ssnpcontrols = {
		order = { 'rew', 'play', 'fwd', 'spacer', 'volDown', 'volSlider', 'volUp' },
		position = LAYOUT_SOUTH,
		h = controlHeight,
		--FIXME, this bgImg is incorrect
		bgImg = keyMiddle,
		rew   = _uses(_transportControlButton, {
			img = _loadImage(self, "Icons/icon_toolbar_rew.png"),
		}),
		play  = _uses(_transportControlButton, {
			img = _loadImage(self, "Icons/icon_toolbar_play.png"),
		}),
		pause = _uses(_transportControlButton, {
			img = _loadImage(self, "Icons/icon_toolbar_pause.png"),
		}),
		fwd   = _uses(_transportControlButton, {
			img = _loadImage(self, "Icons/icon_toolbar_ffwd.png"),
		}),
		volDown   = _uses(_transportControlButton, {
			img = _loadImage(self, "Icons/icon_toolbar_vol_down.png"),
		}),
		volUp   = _uses(_transportControlButton, {
			img = _loadImage(self, "Icons/icon_toolbar_vol_up.png"),
		}),
	}

	s.ssnpcontrols.pressed = {
		rew = _uses(s.ssnpcontrols.rew, { bgImg = keyMiddlePressed }),
		play = _uses(s.ssnpcontrols.play, { bgImg = keyMiddlePressed }),
		pause = _uses(s.ssnpcontrols.pause, { bgImg = keyMiddlePressed }),
		fwd = _uses(s.ssnpcontrols.fwd, { bgImg = keyMiddlePressed }),
		volDown = _uses(s.ssnpcontrols.volDown, { bgImg = keyMiddlePressed }),
		volUp = _uses(s.ssnpcontrols.volUp, { bgImg = keyMiddlePressed }),
	}
	
	s.browsenpcontrols = _uses(s.ssnpcontrols)
	s.largenpcontrols  = _uses(s.ssnpcontrols)

	-- Progress bar
	s.ssprogress = {
		position = LAYOUT_NONE,
		x = 140,
		y = TITLE_HEIGHT + ARTWORK_SIZE - 50,
		padding = { 0, 10, 0, 0 },
		order = { "elapsed", "slider", "remain" },
		elapsed = {
			w = 90,
			align = 'right',
			padding = { 8, 0, 8, 10 },
			font = _boldfont(12),
			fg = { 0xe7,0xe7, 0xe7 },
			sh = { 0x37, 0x37, 0x37 },
		},
		remain = {
			w = 90,
			align = 'left',
			padding = { 8, 0, 8, 10 },
			font = _boldfont(12),
			fg = { 0xe7,0xe7, 0xe7 },
			sh = { 0x37, 0x37, 0x37 },
		},
	}

	s.browseprogress = _uses(s.ssprogress)
	s.largeprogress  = _uses(s.ssprogress)

	s.ssprogressB = {
		w = 200,
		padding     = { 0, 0, 0, 18 },
                position = LAYOUT_SOUTH,
                horizontal = 1,
                bgImg = _songProgressBackground,
                img = _songProgressBar,
	}

	s.browseprogressB = _uses(s.ssprogressB)
	s.largeprogressB  = _uses(s.ssprogressB)

	s.volumeB = {
		w = volumeBarWidth,
		border = { 5, 3, 5, 0 },
                position = LAYOUT_SOUTH,
                horizontal = 1,
                bgImg = _volumeSliderBackground,
                img = _volumeSliderBar,
	}


	-- special style for when there shouldn't be a progress bar (e.g., internet radio streams)
	s.ssprogressNB = {
		position = LAYOUT_NONE,
		x = 120,
		y = TITLE_HEIGHT + ARTWORK_SIZE - 5,
		padding = { 0, 0, 0, 5 },
		order = { "elapsed" },
		text = {
			w = WH_FILL,
			align = "center",
			padding = { 0, 0, 0, 5 },
			font = _boldfont(12),
			fg = { 0xe7, 0xe7, 0xe7 },
			sh = { 0x37, 0x37, 0x37 },
		},
	}

	s.ssprogressNB.elapsed = _uses(s.ssprogressNB.text)

	s.browseprogressNB = _uses(s.ssprogressNB)
	s.largeprogressNB  = _uses(s.ssprogressNB)


end -- LEGACY STYLES

	s.debug_canvas = {
			zOrder = 9999
	}


end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

