
--[[
=head1 NAME

applets.ControllerSkin.ControllerSkinApplet - The skin for the Squeezebox Controller

=head1 DESCRIPTION

This applet implements the skin for the Squeezebox Controller

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>.

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


module(...)
oo.class(_M, Applet)


-- Define useful variables for this skin
local imgpath = "applets/ControllerSkin/images/"
local sndpath = "applets/ControllerSkin/sounds/"
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
local function _icon(self, x, y, img)
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
-- The meta arranges for this to be called to skin Jive.
function skin(self, s, reload, useDefaultSize)
	local screenWidth, screenHeight = Framework:getScreenSize()

	if useDefaultSize or screenWidth < 240 or screenHeight < 320 then
                screenWidth = 240
                screenHeight = 320
        end

        Framework:setVideoMode(screenWidth, screenHeight, 16, jiveMain:isFullscreen())

	--init lastInputType so selected item style is not shown on skin load
	Framework.mostRecentInputType = "scroll"

	-- Images and Tiles
	local background =
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
	local nowPlayingButton        = Tile:loadImage( imgpath .. "Icons/icon_nplay_button_tb.png")
	local textinputBackground =
		Tile:loadHTiles({
				       imgpath .. "text_entry_bkgrd_l.png",
				       imgpath .. "text_entry_bkgrd.png",
				       imgpath .. "text_entry_bkgrd_r.png",
			       })

	local textinputWheel = Tile:loadImage(imgpath .. "text_entry_select.png")

	local textinputCursor = Tile:loadImage(imgpath .. "text_entry_letter.png")

	local textinputRightArrow = Tile:loadImage(imgpath .. "Icons/selection_right.png")

	local buttonBox =
		Tile:loadTiles({
					nil,
					imgpath .. "Text_Entry/Keyboard_Touch/button_qwerty_tl.png",
					imgpath .. "Text_Entry/Keyboard_Touch/button_qwerty_t.png",
					imgpath .. "Text_Entry/Keyboard_Touch/button_qwerty_tr.png",
					imgpath .. "Text_Entry/Keyboard_Touch/button_qwerty_r.png",
					imgpath .. "Text_Entry/Keyboard_Touch/button_qwerty_br.png",
					imgpath .. "Text_Entry/Keyboard_Touch/button_qwerty_b.png",
					imgpath .. "Text_Entry/Keyboard_Touch/button_qwerty_bl.png",
					imgpath .. "Text_Entry/Keyboard_Touch/button_qwerty_l.png",
				})


	local oneLineItemSelectionBox =
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

	local blackBackground = Tile:fillColor(0x000000ff)

	local THUMB_SIZE = self:getSettings().THUMB_SIZE

	local TITLE_PADDING  = 0
	local CHECK_PADDING  = { 0, 0, 0, 0 }
	local CHECKBOX_RADIO_PADDING  = { 2, 8, 8, 0 }

	--FIXME: paddings here need tweaking for Fab4Skin
	local MENU_ALBUMITEM_PADDING = { 4, 2, 4, 2 }
	local MENU_ALBUMITEM_TEXT_PADDING = { 10, 8, 8, 9 }
	local MENU_PLAYLISTITEM_TEXT_PADDING = { 6, 6, 8, 10 }

	local MENU_CURRENTALBUM_TEXT_PADDING = { 6, 20, 0, 10 }
	local TEXTAREA_PADDING = { 13, 8, 8, 8 }

	local TEXT_COLOR = { 0xE7, 0xE7, 0xE7 }
	local TEXT_COLOR_BLACK = { 0x00, 0x00, 0x00 }
	local TEXT_SH_COLOR = { 0x37, 0x37, 0x37 }

	local SELECT_COLOR = { 0x00, 0x00, 0x00 }
	local SELECT_SH_COLOR = { }


        local TITLE_FONT_SIZE = 20
        local ALBUMMENU_TITLE_FONT_SIZE = 14
        local ALBUMMENU_FONT_SIZE = 14
        local ALBUMMENU_SMALL_FONT_SIZE = 14
        local ALBUMMENU_SELECTED_FONT_SIZE = 14
        local ALBUMMENU_SELECTED_SMALL_FONT_SIZE = 14
        local TEXTMENU_FONT_SIZE = 16
        local TEXTMENU_SELECTED_FONT_SIZE = 16
        local POPUP_TEXT_SIZE_1 = 14
        local POPUP_TEXT_SIZE_2 = 22
        local TEXTAREA_FONT_SIZE = 16
        local CENTERED_TEXTAREA_FONT_SIZE = 28
        local TEXTINPUT_FONT_SIZE = 16
        local TEXTINPUT_SELECTED_FONT_SIZE = 24
        local HELP_FONT_SIZE = 16
	local UPDATE_SUBTEXT_SIZE = 20
	local ICONBAR_FONT = 12

	local ITEM_ICON_ALIGN   = 'right'
	local ONE_LINE_ITEM_HEIGHT = 27
	local THREE_LINE_ITEM_HEIGHT = 61
	local TITLE_BUTTON_WIDTH = 76
	local TITLE_BUTTON_HEIGHT = 47
	local TITLE_BUTTON_PADDING = { 4, 0, 4, 0 }


	local smallSpinny = {
		img = _loadImage(self, "Icons/selection_wait.png"),
		frameRate = 5,
		frameWidth = 10,
		padding = { 4, 0, 0, 0 },
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

	-- convenience method for selected items in remote skin menus
	local menuItemSelected = {
		bgImg = oneLineItemSelectionBox,
			text = {
				font = _boldfont(40),
		},
	}

	local playArrow = {
		img = _loadImage(self, "Icons/selection_play.png"),
		h = WH_FILL
	}
	local addArrow  = {
		img = _loadImage(self, "Icons/selection_add.png"),
		h = WH_FILL
	}
	local rightArrow = {
		img = _loadImage(self, "Icons/selection_right.png"),
		padding = { 4, 0, 0, 0 },
		h = WH_FILL,
		align = "center",
	}
	local checkMark = {
		align = ITEM_ICON_ALIGN,
		padding = CHECK_PADDING,
		img = _loadImage(self, "Icons/icon_check.png"),
	}
	local checkMarkSelected = {
		align = ITEM_ICON_ALIGN,
		padding = CHECK_PADDING,
		img = _loadImage(self, "Icons/icon_check_selected.png"),
	}


	---- REVIEWED BELOW THIS LINE ----

--------- CONSTANTS ---------

	local _progressBackground = Tile:loadImage(imgpath .. "Alerts/alert_progress_bar_bkgrd.png")

	local _progressBar = Tile:loadHTiles({
		nil,
		imgpath .. "Alerts/alert_progress_bar_body.png",
		imgpath .. "Alerts/progress_bar_line.png",
	})



--------- DEFINES ---------

	local _buttonMenu = {
		padding = 0,
		w = WH_FILL,
		itemHeight = ONE_LINE_ITEM_HEIGHT,
	}

	local _buttonItem = {
		order = { "text", "arrow" },
		padding = 0,
		text = {
		w = WH_FILL,
		h = WH_FILL,
		padding = { 8, 0, 0, 0 },
		align = "left",
		font = _boldfont(34),
		fg = SELECT_COLOR,
		sh = SELECT_SH_COLOR,
		},
		arrow = {
			img     = _loadImage(self, "Icons/selection_right_3line_off.png"),
			w       = 37,
			h       = WH_FILL,
			padding = { 0, 0, 8, 0}
		}
	}


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
		maskImg = popupMask,
	})

	s.title = {
		h = 31,
		border = 4,
		position = LAYOUT_NORTH,
		bgImg = titleBox,
		order = { "text", "icon" },
		text = {
			w = WH_FILL,
			h = WH_FILL,
			padding = { 8, 7, 0, 9 },
			align = 'top-left',
			font = _boldfont(TITLE_FONT_SIZE),
			fg = SELECT_COLOR,
			sh = SELECT_SH_COLOR,
		},
		xofy = {
			h = WH_FILL,
                	font = _boldfont(TITLE_FONT_SIZE),
			align = "right",
	                fg = TEXT_COLOR,
			padding = { 0, 10, 8, 0},
        	},
        	icon = {
			padding  = { 0, 0, 8, 0 },
			align    = 'right'
		}
	}

	s.menu = {
		h = 243,
		position = LAYOUT_CENTER,
		padding = { 4, 2, 4, 2 },
		border = { 0, 0, 5, 0 },
		itemHeight = ONE_LINE_ITEM_HEIGHT,
	}

	s.item = {
		order = { "text" },
		padding = { 9, 6, 6, 6 },
		text = {
			padding = { 0, 0, 0, 0 },
			align = "left",
			w = WH_FILL,
			font = _boldfont(TEXTMENU_FONT_SIZE),
			fg = TEXT_COLOR,
			sh = TEXT_SH_COLOR,
		},
	}

	s.item_play = _uses(s.item)
	s.item_add = _uses(s.item)

	-- Checkbox
        s.checkbox = {}
        s.checkbox.img_on = _loadImage(self, "Icons/checkbox_on.png")
        s.checkbox.img_off = _loadImage(self, "Icons/checkbox_off.png")


        -- Radio button
        s.radio = {}
        s.radio.img_on = _loadImage(self, "Icons/radiobutton_on.png")
        s.radio.img_off = _loadImage(self, "Icons/radiobutton_off.png")

	s.item_choice = _uses(s.item, {
		order  = { 'text', 'icon' },
		icon = {
			align = 'right',
			font = _boldfont(TEXTMENU_FONT_SIZE),
			fg = TEXT_COLOR,
			sh = TEXT_SH_COLOR,
			h = WH_FILL,
		},
	})
	s.item_checked = _uses(s.item, {
		order = { "text", "check" },
		check = checkMark,
	})

	s.item_no_arrow = _uses(s.item, {
		order = { 'icon', 'text' },
	})
	s.item_checked_no_arrow = _uses(s.item, {
		order = { 'icon', 'text', 'check' },
	})

        -- selected menu item
        s.selected = {}
	s.selected.item = _uses(s.item, {
		order = { 'text', 'arrow' },
		text = {
			font = _boldfont(TEXTMENU_SELECTED_FONT_SIZE),
			fg = SELECT_COLOR,
			sh = SELECT_SH_COLOR
		},
		bgImg = oneLineItemSelectionBox,
		arrow = rightArrow,
	})
	s.selected.item_choice = _uses(s.selected.item, {
		order = { 'text', 'icon' },
		icon = {
			align = 'right',
			font = _boldfont(TEXTMENU_FONT_SIZE),
			fg = SELECT_COLOR,
			sh = SELECT_SH_COLOR,
		},
	})

	s.selected.item_play = _uses(s.selected.item, {
		arrow = playArrow
	})
	s.selected.item_add = _uses(s.selected.item, {
		arrow = addArrow
	})
	s.selected.item_checked = _uses(s.selected.item, {
		order = { "text", "check", "arrow" },
		check = checkMarkSelected,
		arrow = rightArrow,
	})
        s.selected.item_no_arrow = _uses(s.item, {
		order = { 'text' },
	})
        s.selected.item_checked_no_arrow = _uses(s.item, {
		order = { 'text', 'check' },
		check = checkMark,
	})

	s.pressed = {
		item = _uses(s.selected.item, {
			bgImg = threeItemPressedBox,
		}),
		item_checked = _uses(s.selected.item_checked, {
			bgImg = threeItemPressedBox,
		}),
		item_play = _uses(s.selected.item_play, {
			bgImg = threeItemPressedBox,
		}),
		item_add = _uses(s.selected.item_add, {
			bgImg = threeItemPressedBox,
		}),
		item_no_arrow = _uses(s.selected.item_no_arrow, {
			bgImg = threeItemPressedBox,
		}),
		item_checked_no_arrow = _uses(s.selected.item_checked_no_arrow, {
			bgImg = threeItemPressedBox,
		}),
		item_choice = _uses(s.selected.item_choice, {
			bgImg = threeItemPressedBox,
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
		item_no_arrow = _uses(s.pressed.item_no_arrow, {
			arrow = smallSpinny
		}),
		item_checked_no_arrow = _uses(s.pressed.item_checked_no_arrow, {
			arrow = smallSpinny
		}),
	}

	s.help_text = {
		w = screenWidth - 6,
		position = LAYOUT_SOUTH,
		padding = 12,
		font = _font(HELP_FONT_SIZE),
		fg = TEXT_COLOR,
		bgImg = helpBox,
		align = "left",
		scrollbar = {
			w = 0,
		},
	}

	s.scrollbar = {
		w = 9,
		border = { 4, 0, 0, 0 },  -- bug in jive_menu, makes it so bottom and right values are ignored
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
		border = 5,
		w = WH_FILL,
		horizontal = 1,
		bgImg = sliderBackground,
		img = sliderBar,
	}

	s.slider_group = {
		w = WH_FILL,
		border = { 15, 5, 7, 10 },
		order = { "min", "slider", "max" },
	}


--------- SPECIAL WIDGETS ---------


	-- text input
	s.textinput = {
--		h = 35,
		border = { 8, -5, 8, 0 },
		padding = { 6, 0, 6, 0 },
		font = _font(TEXTINPUT_FONT_SIZE),
		cursorFont = _boldfont(TEXTINPUT_SELECTED_FONT_SIZE),
		wheelFont = _boldfont(TEXTINPUT_FONT_SIZE),
		charHeight = TEXTINPUT_SELECTED_FONT_SIZE + 2,
		fg = TEXT_COLOR_BLACK,
		wh = { 0x55, 0x55, 0x55 },
		bgImg = textinputBackground,
		cursorImg = textinputCursor,
		wheelImg = textinputWheel,
		enterImg = textinputRightArrow,
	}


--------- WINDOW STYLES ---------
	--
	-- These styles override the default styles for a specific window

	-- typical text list window
	s.text_list = _uses(s.window)

	-- popup "spinny" window
	s.waiting_popup = _uses(s.popup)

	s.waiting_popup.text = {
		padding = { 0, 0, 0, 40 },
		fg = TEXT_COLOR,
		sh = TEXT_SH_COLOR,
		align = "center",
		position = LAYOUT_SOUTH ,
		h = 16
	}

	s.waiting_popup.text.line = {
		{
			font = _boldfont(POPUP_TEXT_SIZE_1),
			height = 16,
		},
		{
			font = _boldfont(POPUP_TEXT_SIZE_2),
		},
	}

	s.waiting_popup.subtext = {
		padding = { 0, 0, 0, 32 },
		font = _boldfont(POPUP_TEXT_SIZE_2),
		fg = TEXT_COLOR,
		sh = TEXT_SH_COLOR,
		align = "center",
		position = LAYOUT_SOUTH,
--		h = 40,
	}

	-- input window (including keyboard)
	-- XXX: needs layout
	s.input = _uses(s.window, {
		bgImg = blackBackground,
	})

	-- error window
	-- XXX: needs layout
	s.error = _uses(s.window)

	-- update window
	s.update_popup = _uses(s.popup)

	s.update_popup.subtext = {
		padding = { 0, 0, 0, 60 },
		font = _boldfont(POPUP_TEXT_SIZE_1),
		fg = TEXT_COLOR,
		sh = TEXT_SH_COLOR,
		align = "center",
		position = LAYOUT_SOUTH,
	}

	s.update_popup.text = {
		padding = { 0, 14, 0, 0 },
		fg = TEXT_COLOR,
		sh = TEXT_SH_COLOR,
		align = "center",
		position = LAYOUT_SOUTH ,
	}

	s.update_popup.text.line = {
		{
			font = _boldfont(POPUP_TEXT_SIZE_1),
			height = 16,
		},
		{
			font = _boldfont(POPUP_TEXT_SIZE_2),
		},
	}

	-- icon_list window
	s.icon_list = _uses(s.window, {
		menu = _uses(s.menu, {
			itemHeight = THREE_LINE_ITEM_HEIGHT,
			item = {
				order = { "icon", "text" },
				padding = MENU_ALBUMITEM_PADDING,
				text = {
					align = "top-left",
					w = WH_FILL,
					h = WH_FILL,
					padding = MENU_ALBUMITEM_TEXT_PADDING,
					font = _font(ALBUMMENU_SMALL_FONT_SIZE),
					line = {
						{
							font = _boldfont(ALBUMMENU_FONT_SIZE),
							height = ALBUMMENU_FONT_SIZE + 2
						}
					},
					fg = TEXT_COLOR,
					sh = TEXT_SH_COLOR,
				},
				icon = {
					w = THUMB_SIZE,
					h = THUMB_SIZE,
					border = { 8, 0, 0, 0 }
				},
			},
		}),
	})


	s.icon_list.menu.item_checked = _uses(s.icon_list.menu.item, {
		order = { 'icon', 'text', 'check' },
		check = {
			align = ITEM_ICON_ALIGN,
			padding = CHECK_PADDING,
			img = _loadImage(self, "Icons/icon_check_5line.png")
		},
	})
	s.icon_list.menu.item_play = _uses(s.icon_list.menu.item)
	s.icon_list.menu.item_add  = _uses(s.icon_list.menu.item)
	s.icon_list.menu.item_no_arrow = _uses(s.icon_list.menu.item)
	s.icon_list.menu.item_checked_no_arrow = _uses(s.icon_list.menu.item_checked)

	s.icon_list.menu.selected = {}
	s.icon_list.menu.selected.item = _uses(s.icon_list.menu.item, {
		order = { 'icon', 'text', 'arrow' },
		text = {
			fg = SELECT_COLOR,
			sh = SELECT_SH_COLOR,
		},
		bgImg = oneLineItemSelectionBox,
		arrow = rightArrow,
	})

	s.icon_list.menu.selected.item_checked          = _uses(s.icon_list.menu.selected.item, {
		order = { 'icon', 'text', 'check', 'arrow' },
	})
	s.icon_list.menu.selected.item_play             = _uses(s.icon_list.menu.selected.item, {
		arrow = playArrow,
	})
	s.icon_list.menu.selected.item_add              = _uses(s.icon_list.menu.selected.item, {
		arrow = addArrow,
	})
	s.icon_list.menu.selected.item_no_arrow         = _uses(s.icon_list.menu.selected.item, {
		order = { 'icon', 'text' },
	})
	s.icon_list.menu.selected.item_checked_no_arrow = _uses(s.icon_list.menu.selected.item, {
		order = { 'icon', 'text', 'check' },
		check = checkMark,
	})

        s.icon_list.menu.pressed = {
                item = _uses(s.icon_list.menu.selected.item, {
			bgImg = threeItemPressedBox
		}),
                item_checked = _uses(s.icon_list.menu.selected.item_checked, {
			bgImg = threeItemPressedBox
		}),
                item_play = _uses(s.icon_list.menu.selected.item_play, {
			bgImg = threeItemPressedBox
		}),
                item_add = _uses(s.icon_list.menu.selected.item_add, {
			bgImg = threeItemPressedBox
		}),
                item_no_arrow = _uses(s.icon_list.menu.selected.item_no_arrow, {
			bgImg = threeItemPressedBox
		}),
                item_checked_no_arrow = _uses(s.icon_list.menu.selected.item_checked_no_arrow, {
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


	-- information window
	s.information = _uses(s.window)


	-- help window (likely the same as information)
	s.help_info = _uses(s.window)


	--track_list window
	-- XXXX todo
	s.track_list = _uses(s.text_list)

	s.track_list.title = _uses(s.title, {
		h = THREE_LINE_ITEM_HEIGHT - 1,
		border = 4,
		order = { 'icon', 'text' },
		icon  = {
			w = THUMB_SIZE,
			h = WH_FILL,
			padding = { 9,0,0,0 },
		},
		text = {
			padding = MENU_ALBUMITEM_TEXT_PADDING,
			align = "top-left",
			font = _font(ALBUMMENU_TITLE_FONT_SIZE),
			lineHeight = ALBUMMENU_TITLE_FONT_SIZE + 1,
			line = {
					{
						font = _boldfont(ALBUMMENU_TITLE_FONT_SIZE),
						height = ALBUMMENU_TITLE_FONT_SIZE + 2,
					}
			},
		},
	})

	--playlist window
	-- identical to icon_list but with some different formatting on the text
	s.play_list = _uses(s.icon_list, {
		menu = {
			item = {
				text = {
					padding = MENU_PLAYLISTITEM_TEXT_PADDING,
					font = _font(ALBUMMENU_FONT_SIZE),
					lineHeight = 16,
					line = {
						{
							font = _boldfont(ALBUMMENU_FONT_SIZE),
							height = ALBUMMENU_FONT_SIZE + 3
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
			text = {
				fg = SELECT_COLOR,
				sh = SELECT_SH_COLOR,
			},
			bgImg = oneLineItemSelectionBox,
		}),
                item_checked = _uses(s.play_list.menu.item_checked),
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


	-- toast_popup popup
	s.toast_popup = {
		x = 0,
		y = screenHeight - 93,
		w = screenWidth,
		h = 93,
		bgImg = helpBox,
		group = {
			padding = { 12, 12, 12, 0 },
			order = { 'icon', 'text' },
			text = {
				padding = { 6, 3, 8, 8 } ,
				align = 'top-left',
				w = WH_FILL,
				h = WH_FILL,
				font = _font(HELP_FONT_SIZE),
				lineHeight = 17,
				line = {
					{
						font = _boldfont(HELP_FONT_SIZE),
						height = 17
					},
				},
			},
			icon = {
				align = 'top-left',
				border = { 12, 12, 0, 0 },
				img = _loadImage(self, "album_noartwork_56.png"),
				h = WH_FILL,
				w = 56,
			}
		}
	}

	-- slider popup (volume/scanner)
	s.slider_popup = {
		x = 0,
		y = screenHeight - 80,
		w = screenWidth,
		h = 80,
		bgImg = helpBox,
		title = {
		      border = 10,
		      fg = TEXT_COLOR,
		      font = _boldfont(HELP_FONT_SIZE),
		      align = "center",
		      bgImg = false,
		},
		slider_group = {
			w = WH_FILL,
			--border = { 0, 5, 0, 10 },
			order = { "min", "slider", "max" },
			max = {
				align = 'right',
			},
			min = {
				align = 'left',
			},
			text = {
				w = 75,
				align = 'right',
				padding = { 8, 0, 8, 15 },
				font = _boldfont(HELP_FONT_SIZE),
				fg = TEXT_COLOR,
				sh = TEXT_SH_COLOR,
			}
		},
	}

	s.image_popup = _uses(s.popup, {
		image = {
			align = "center",
		},
	})


--------- SLIDERS ---------


	s.volume_slider = _uses(s.slider, {
		img = volumeBar,
		bgImg = volumeBackground,
	})

	s.scanner_slider = _uses(s.slider, {
		img = volumeBar,
		bgImg = volumeBackground,
	})


--------- BUTTONS ---------


	-- XXXX could use a factory function
	local _button = {
		bgImg = titlebarButtonBox,
		w = TITLE_BUTTON_WIDTH,
		h = TITLE_BUTTON_HEIGHT,
		align = 'center',
		border = TITLE_BUTTON_PADDING,
	}
	local _pressed_button = _uses(_button, {
		bgImg = pressedTitlebarButtonBox,
	})


	-- invisible button
	s.button_none = _uses(_button, {
		bgImg    = false
	})

	s.button_back = _uses(_button, {
		img      = backButton,
	})
	s.pressed.button_back = _uses(_pressed_button, {
		img      = backButton,
	})

	s.button_go_now_playing = _uses(_button, {
		img      = nowPlayingButton,
	})
	s.pressed.button_go_now_playing = _uses(_pressed_button, {
		img      = nowPlayingButton,
	})

	s.button_help = _uses(_button, {
		img = helpButton,
	})
	s.pressed.button_help = _uses(_pressed_button, {
		img      = helpButton,
	})

	s.button_volume_min = {
		img = _loadImage(self, "Icons/volume_speaker_l.png"),
		border = { 5, 0, 5, 0 },
	}

	s.button_volume_max = {
		img = _loadImage(self, "Icons/volume_speaker_r.png"),
		border = { 5, 0, 5, 0 },
	}


	local _buttonicon = {
		w = 72,
		h = WH_FILL,
		padding = { 8, 4, 0, 4 },
		img = false
	}

	s.region_US = _uses(_buttonicon, {
		img = _loadImage(self, "Icons/icon_region_americas_64.png")
	})
	s.region_XX = _uses(_buttonicon, {
		img = _loadImage(self, "Icons/icon_region_other_64.png")
	})
	s.wlan = _uses(_buttonicon, {
		img = _loadImage(self, "Icons/icon_wireless_64.png")
	})
	s.wired = _uses(_buttonicon, {
		img = _loadImage(self, "Icons/icon_ethernet_64.png")
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
		img = _loadImage(self, "album_noartwork_56.png"),
		w   = THUMB_SIZE,
		h   = THUMB_SIZE,
	}

	s.icon_connecting = _uses(_icon, {
		img = _loadImage(self, "Alerts/wifi_connecting.png"),
		frameRate = 8,
		frameWidth = 161,
		padding = { 0, 20, 0, 10 }
	})

	s.icon_connected = _uses(_icon, {
		img = _loadImage(self, "Alerts/connecting_success_icon.png"),
	})

	s.icon_software_update = _uses(s.icon_connecting)

	s.icon_power = _uses(_icon, {
		img = _loadImage(self, "Alerts/popup_shutdown_icon.png"),
	})

	s.icon_locked = _uses(_icon, {
		img = _loadImage(self, "Alerts/popup_locked_icon.png"),
	})

	s.icon_alarm = _uses(_icon, {
		img = _loadImage(self, "Alerts/popup_alarm_icon.png"),
	})

	s.icon_keyboard_divider = {
		img = _loadImage(self, "Text_Entry/Keyboard_Touch/toolbar_divide.png"),
		bgImg = _loadImage(self, "Text_Entry/Keyboard_Touch/toolbar_divider.png")
	}


	-- button icons, on left of menus
	local _buttonicon = {
		w = 72,
		h = WH_FILL,
		padding = { 8, 4, 0, 4 },
	}

	s.player_transporter = _uses(_buttonicon, {
		img = _loadImage(self, "Icons/Players/transporter.png"),
	})
	s.player_squeezebox = _uses(_buttonicon, {
		img = _loadImage(self, "Icons/Players/squeezebox.png"),
	})
	s.player_squeezebox2 = _uses(_buttonicon, {
		img = _loadImage(self, "Icons/Players/squeezebox.png"),
	})
	s.player_squeezebox3 = _uses(_buttonicon, {
		img = _loadImage(self, "Icons/Players/squeezebox3.png"),
	})
	s.player_boom = _uses(_buttonicon, {
		img = _loadImage(self, "Icons/Players/boom.png"),
	})
	s.player_slimp3 = _uses(_buttonicon, {
		img = _loadImage(self, "Icons/Players/slimp3.png"),
	})
	s.player_softsqueeze = _uses(_buttonicon, {
		img = _loadImage(self, "Icons/Players/softsqueeze.png"),
	})
	s.player_controller = _uses(_buttonicon, {
		img = _loadImage(self, "Icons/Players/controller.png"),
	})
	s.player_receiver = _uses(_buttonicon, {
		img = _loadImage(self, "Icons/Players/receiver.png"),
	})
	s.player_squeezeplay = _uses(_buttonicon, {
		img = _loadImage(self, "Icons/Players/squeezeplay.png"),
	})
	s.player_http = _uses(_buttonicon, {
		img = _loadImage(self, "Icons/Players/http.png"),
	})


	-- indicator icons, on right of menus
	local _indicator = {
		align = "right",
	}

	s.wirelessLevel1 = _uses(_indicator, {
		img = _loadImage(self, "Icons/icon_wireless_1_shadow.png")
	})

	s.wirelessLevel2 = _uses(_indicator, {
		img = _loadImage(self, "Icons/icon_wireless_2_shadow.png")
	})

	s.wirelessLevel3 = _uses(_indicator, {
		img = _loadImage(self, "Icons/icon_wireless_3_shadow.png")
	})

	s.wirelessLevel4 = _uses(_indicator, {
		img = _loadImage(self, "Icons/icon_wireless_4_shadow.png")
	})


--------- ICONBAR ---------

	-- button icons, on left of menus
	local _iconbar_icon = {
		h = WH_FILL,
		padding = { 0,0,0,0 },
		layer = LAYER_FRAME,
		position = LAYOUT_SOUTH,
	}

	local _button_playmode = _uses(_iconbar_icon, {
		w = 38,
		padding = { 5, 0, 0, 0 },
	})
	s.button_playmode_OFF = _uses(_button_playmode, {
		img = _loadImage(self, "icon_mode_off.png"),
	})
	s.button_playmode_STOP = _uses(_button_playmode, {
		img = _loadImage(self, "icon_mode_off.png"),
	})
	s.button_playmode_PLAY = _uses(_button_playmode, {
		img = _loadImage(self, "icon_mode_play.png"),
	})
	s.button_playmode_PAUSE = _uses(_button_playmode, {
		img = _loadImage(self, "icon_mode_pause.png"),
	})

	local _button_repeat = _uses(_iconbar_icon, {
		w = 34,
	})
	s.button_repeat_OFF = _uses(_button_repeat, {
		img = _loadImage(self, "icon_repeat_off.png"),
	})
	s.button_repeat_0 = _uses(_button_repeat, {
		img = _loadImage(self, "icon_repeat_off.png"),
	})
	s.button_repeat_1 = _uses(_button_repeat, {
		img = _loadImage(self, "icon_repeat_song.png"),
	})
	s.button_repeat_2 = _uses(_button_repeat, {
		img = _loadImage(self, "icon_repeat.png"),
	})

	s.button_playlist_mode_OFF = _uses(_button_repeat, {
		img = _loadImage(self, "icon_repeat_off.png"),
	})
	s.button_playlist_mode_DISABLED = _uses(_button_repeat, {
		img = _loadImage(self, "icon_repeat_off.png"),
	})
	s.button_playlist_mode_ON = _uses(_button_repeat, {
		img = _loadImage(self, "icon_mode_playlist.png"),
	})
	s.button_playlist_mode_PARTY = _uses(_button_repeat, {
		img = _loadImage(self, "icon_mode_party.png"),
	})

	local _button_shuffle = _uses(_iconbar_icon, {
		w = 32,
	})
	s.button_shuffle_OFF = _uses(_button_shuffle, {
		img = _loadImage(self, "icon_shuffle_off.png"),
	})
	s.button_shuffle_0 = _uses(_button_shuffle, {
		img = _loadImage(self, "icon_shuffle_off.png"),
	})
	s.button_shuffle_1 = _uses(_button_shuffle, {
		img = _loadImage(self, "icon_shuffle.png"),
	})
	s.button_shuffle_2 = _uses(_button_shuffle, {
		img = _loadImage(self, "icon_shuffle_album.png"),
	})

	local _button_battery = _uses(_iconbar_icon, {
		w = 37,
	})
	s.button_battery_AC = _uses(_button_battery, {
		img = _loadImage(self, "icon_battery_ac.png"),
	})
	s.button_battery_CHARGING = _uses(_button_battery, {
		img = _loadImage(self, "icon_battery_charging.png"),
		frameRate = 1,
		frameWidth = 37,
	})
	s.button_battery_0 = _uses(_button_battery, {
		img = _loadImage(self, "icon_battery_0.png"),
	})
	s.button_battery_1 = _uses(_button_battery, {
		img = _loadImage(self, "icon_battery_1.png"),
	})
	s.button_battery_2 = _uses(_button_battery, {
		img = _loadImage(self, "icon_battery_2.png"),
	})
	s.button_battery_3 = _uses(_button_battery, {
		img = _loadImage(self, "icon_battery_3.png"),
	})
	s.button_battery_4 = _uses(_button_battery, {
		img = _loadImage(self, "icon_battery_4.png"),
	})
	s.button_battery_NONE = _uses(_button_battery, {
		img = _loadImage(self, "icon_repeat_off.png"),
	})

	local _button_wireless = _uses(_iconbar_icon, {
		w = 30,
	})
	s.button_wireless_1 = _uses(_button_wireless, {
		img = _loadImage(self, "icon_wireless_1.png"),
	})
	s.button_wireless_2 = _uses(_button_wireless, {
		img = _loadImage(self, "icon_wireless_2.png"),
	})
	s.button_wireless_3 = _uses(_button_wireless, {
		img = _loadImage(self, "icon_wireless_3.png"),
	})
	s.button_wireless_4 = _uses(_button_wireless, {
		img = _loadImage(self, "icon_wireless_4.png"),
	})
	s.button_wireless_ERROR = _uses(_button_wireless, {
		img = _loadImage(self, "icon_wireless_off.png"),
	})
	s.button_wireless_SERVERERROR = _uses(_button_wireless, {
		img = _loadImage(self, "icon_wireless_noserver.png"),
	})
	s.button_wireless_NONE = _uses(_button_wireless, {
		img = _loadImage(self, "icon_repeat_off.png"),
	})

	-- time
	s.button_time = {
		w = 55,
		align = "right",
		layer = LAYER_FRAME,
		position = LAYOUT_SOUTH,
		fg = TEXT_COLOR,
		font = _boldfont(ICONBAR_FONT),
	}

	s.iconbar_group = {
		x = 0,
		y = screenHeight - 30,
		w = screenWidth,
		h = 30,
		border = { 4, 0, 4, 0 },
		bgImg = background,
		layer = LAYER_FRAME,
		position = LAYOUT_SOUTH,
		order = {'play', 'repeat_mode', 'shuffle', 'wireless', 'battery', 'button_time' }, --'repeat' is a Lua reserved word

	}


--------- LEGACY STYLES TO KEEP SLIMBROWSER GOING --------
if true then

	-- XXXX todo

	-- BEGIN NowPlaying skin code
	-- this skin is established in two forms,
	-- one for the Screensaver windowStyle (ss), one for the browse windowStyle (browse)
	-- a lot of it can be recycled from one to the other

	local NP_TRACK_FONT_SIZE = 14

	-- Title
	s.ssnptitle = _uses(s.title, {
		rbutton  = {
			font    = _font(14),
			fg      = TEXT_COLOR,
			bgImg   = titlebarButtonBox,
			w       = TITLE_BUTTON_WIDTH,
			h       = TITLE_BUTTON_HEIGHT,
			padding =  TITLE_BUTTON_PADDING,
			padding = { 10, 0, 10, 0},
			align   = 'center',
		}
	})

	local nplargetitleBox = Tile:loadTiles({ imgpath .. "Screen_Formats/Titlebar/titlebar.png" })

	-- nptitle style is the same for all windowStyles
	s.browsenptitle = _uses(s.ssnptitle)
	s.largenptitle  = _uses(s.ssnptitle, {
				bgImg = nplargetitleBox,
				border = { 0, 0, 0, 0 },
				text = {
						padding = { 4, 7, 10, 9 }
				}
			})


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

	-- Song
	s.ssnptrack = {
		border = { 4, 0, 4, 0 },
		position = LAYOUT_CENTER,
		text = {
			w = WH_FILL,
			border = { 10, 10, 8, 4 },
			align = "top-left",
        		font = _font(NP_TRACK_FONT_SIZE),
			lineHeight = NP_TRACK_FONT_SIZE + 3,
			fg = TEXT_COLOR_BLACK,
        		line = {{
				font = _boldfont(NP_TRACK_FONT_SIZE),
				height = NP_TRACK_FONT_SIZE + 3,
				}},
		},
	}

	-- nptrack is identical between all windowStyles
	s.browsenptrack = _uses(s.ssnptrack)
	s.largenptrack  = _uses(s.ssnptrack)

	-- Artwork
	local ARTWORK_SIZE    = self:getSettings().nowPlayingBrowseArtworkSize
	local SS_ARTWORK_SIZE = self:getSettings().nowPlayingSSArtworkSize
	local browseArtWidth  = ARTWORK_SIZE
	local ssArtWidth      = SS_ARTWORK_SIZE

	s.ssnpartwork = {
		w = ssArtWidth,
		border = { 0, 10, 0, 8 },
		position = LAYOUT_CENTER,
		align = "center",
		artwork = {
			align = "center",
			padding = 0,
			-- FIXME: this is a placeholder
			img = _loadImage(self, "Icons/icon_album_noartwork_npss.png"),
		},
	}

	s.browsenpartwork = _uses(s.ssnpartwork)
	s.largenpartwork = _uses(s.ssnpartwork)

	local topPadding = screenHeight/2 + 10
	local rightPadding = screenWidth/2 - 15
	local buttonPadding = { 10, 5, 10, 5 }

--	s.ssnpcontrols = {
--		order = { 'rew', 'play', 'fwd', 'vol' },
--		position = LAYOUT_NONE,
--		x = rightPadding,
--		y = topPadding,
--		bgImg = buttonBox,
--		rew = {
--			align = 'center',
--			padding = buttonPadding,
--			img = _loadImage(self, "Player_Controls/icon_toolbar_rew.png"),
--		},
--		play = {
--			align = 'center',
--			padding = buttonPadding,
--			img = _loadImage(self, "Player_Controls/icon_toolbar_play.png"),
--		},
--		pause = {
--			align = 'center',
--			padding = buttonPadding,
--			img = _loadImage(self, "Player_Controls/icon_toolbar_pause.png"),
--		},
--		fwd = {
--			align = 'center',
--			padding = buttonPadding,
--			img = _loadImage(self, "Player_Controls/icon_toolbar_ffwd.png"),
--		},
--		vol = {
--			align = 'center',
--			padding = buttonPadding,
--			img = _loadImage(self, "Player_Controls/icon_toolbar_vol_up.png"),
--		},
--	}
--
--	s.ssnpcontrols.pressed = {
--		rew = _uses(s.ssnpcontrols.rew),
--		play = _uses(s.ssnpcontrols.play),
--		pause = _uses(s.ssnpcontrols.pause),
--		fwd = _uses(s.ssnpcontrols.fwd),
--		vol = _uses(s.ssnpcontrols.vol),
--	}

	s.browsenpcontrols = _uses(s.ssnpcontrols)
	s.largenpcontrols  = _uses(s.ssnpcontrols)

	s.song_elapsed = {
		w = 75,
		align = 'right',
		padding = { 8, 0, 8, 15 },
		font = _boldfont(18),
		fg = { 0xe7,0xe7, 0xe7 },
		sh = { 0x37, 0x37, 0x37 },
	}
	s.song_remain = {
		w = 75,
		align = 'left',
		padding = { 8, 0, 8, 15 },
		font = _boldfont(18),
		fg = { 0xe7,0xe7, 0xe7 },
		sh = { 0x37, 0x37, 0x37 },
	}
	-- Progress bar
	s.ssprogress = {
		position = LAYOUT_SOUTH,
		padding = { 10, 10, 10, 5 },
		order = { "elapsed", "slider", "remain" },
		elapsed = {
			align = 'right',
		},
		remain = {
			align = 'left',
		},
		text = {
			w = 75,
			align = 'right',
			padding = { 8, 0, 8, 15 },
			font = _boldfont(18),
			fg = { 0xe7,0xe7, 0xe7 },
			sh = { 0x37, 0x37, 0x37 },
		},
	}

	s.browseprogress = _uses(s.ssprogress)
	s.largeprogress  = _uses(s.ssprogress)

	s.ssprogressB = {
		horizontal  = 1,
		bgImg       = sliderBackground,
		img         = sliderBar,
		position    = LAYOUT_SOUTH,
		padding     = { 0, 0, 0, 15 },
	}

	s.browseprogressB = _uses(s.ssprogressB)
	s.largeprogressB  = _uses(s.ssprogressB)

	-- special style for when there shouldn't be a progress bar (e.g., internet radio streams)
	s.ssprogressNB = {
		position = LAYOUT_SOUTH,
		padding = { 0, 0, 0, 5 },
		order = { "elapsed" },
		text = {
			w = WH_FILL,
			align = "center",
			padding = { 0, 0, 0, 5 },
			font = _boldfont(18),
			fg = { 0xe7, 0xe7, 0xe7 },
			sh = { 0x37, 0x37, 0x37 },
		},
	}

	s.ssprogressNB.elapsed = _uses(s.ssprogressNB.text)

	s.browseprogressNB = _uses(s.ssprogressNB)
	s.largeprogressNB  = _uses(s.ssprogressNB)


end -- LEGACY STYLES


end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

