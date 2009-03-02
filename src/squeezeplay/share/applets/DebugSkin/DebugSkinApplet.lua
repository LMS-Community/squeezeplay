
local ipairs, pairs = ipairs, pairs

local oo            = require("loop.simple")
local table         = require("jive.utils.table")

local Applet        = require("jive.Applet")

local Canvas        = require("jive.ui.Canvas")
local Framework     = require("jive.ui.Framework")
local Widget        = require("jive.ui.Widget")

local debug         = require("jive.utils.debug")
local log           = require("jive.utils.log").logger("ui")

local appletManager = appletManager


module(..., Framework.constants)
oo.class(_M, Applet)


local styles -- defined below



function _debugWidget(self, screen, widget)
	if self.mouseEvent and widget:mouseInside(self.mouseEvent) then
		local x,y,w,h = widget:getBounds()
		local l,t,r,b = widget:getBorder()

		screen:filledRectangle(x-l,y-t, x+w+r,y, 0x00FF003F)
		screen:filledRectangle(x-l,y+h, x+w+r,y+h+b, 0x00FF003F)

		screen:filledRectangle(x-l,y, x,y+h, 0x00FF003F)
		screen:filledRectangle(x+w,y, x+w+r,y+h, 0x00FF003F)

		screen:filledRectangle(x,y, x+w,y+h, 0xFF00003F)

		--log:info("-> ", widget, " (", x, ",", y, " ", w, "x", h, ")")

		local kids = 0
		widget:iterate(function(child)
			kids = kids + 1
		end)

		if kids == 0 then
			-- use C cached stylePath where possible, naughtly but nice ;)
			log:info("style: ", widget._stylePath)
		end
	end

	widget:iterate(function(child)
		_debugWidget(self, screen, child)
	end)
end


function debugSkin(self)
	if self.colorEnabled then
		self.colorEnabled = nil

		self.validStyles = nil
		self.invalidStyles = nil

		Framework:removeWidget(self.canvas)
		Framework:removeListener(self.mouseListener)
		Framework:removeListener(self.windowListener)

		return
	end

	self.colorEnabled = true

	self.canvas = Canvas("blank", function(screen)
		local window = Framework.windowStack[1]

		--log:info("Mouse in: ", window)
		window:iterate(function(w)
			_debugWidget(self, screen, w)
		end)
	end)
	Framework:addWidget(self.canvas)

	self.mouseListener = Framework:addListener(EVENT_MOUSE_ALL,
		function(event)
			self.mouseEvent = event
			Framework:reDraw(nil)
		end, -99)
end


function debugStyle(self)
	if self.styleEnabled then
		self.styleEnabled = nil

		self.validStyles = nil
		self.invalidStyles = nil

		Widget.checkSkin = self.widgetCheckSkin

		return
	end

	self.styleEnabled = true

	self.validStyles = {}
	self.invalidStyles = {}

	for i,style in ipairs(styles) do
		self.validStyles[style] = true
	end

	-- hook into Widget:checkSkin(), naughty but nice ;)
	self.widgetCheckSkin = Widget.checkSkin
	Widget.checkSkin = function(widget)
		self.widgetCheckSkin(widget)

		self:auditStyles(Framework.windowStack[1])
	end

end

		
function _auditWidgetStyle(self, widget, parentStyle, invalidWindow)
	local kids = 0
	widget:iterate(function(child)
		kids = kids + 1
	end)

	local style = widget:getStyle()

	-- use C cached stylePath where possible, naughtly but nice ;)
	local path = widget._stylePath or parentStyle .. "." .. style

	if kids == 0 then
		if not (self.validStyles[style] or self.validStyles[path]) then
			self.invalidStyles[path] = true
			invalidWindow[path] = true
		end
	else
		widget:iterate(function(widget)
			_auditWidgetStyle(self, widget, path, invalidWindow)
		end)
	end
end


function _sortList(list)
	local keys = {}
	for path in pairs(list) do
		keys[#keys + 1] = path
	end

	table.sort(keys)
	return keys
end


function auditStyles(self, window)
	local invalidWindow = {}

	local style = window:getStyle()
	window:iterate(function(widget)
		_auditWidgetStyle(self, widget, style, invalidWindow)
	end)

	-- don't print if all window styles are valid
	local sortedInvalidWindow = _sortList(invalidWindow)
	if #sortedInvalidWindow == 0 then
		return
	end

	-- don't print if the invalid styles in this window have not changed
	if self.lastWindow == window and self.numLastWindow == #sortedInvalidWindow then
		return
	end

	self.lastWindow = window
	self.numLastWindow = #sortedInvalidWindow

	log:warn("Unknown styles in window:\n", window, "\n", table.concat(sortedInvalidWindow, "\n"))

	-- don't print if the all invalid styles have not changed
	local sortedInvalidStyles = _sortList(self.invalidStyles)
	if self.numInvalidStyles == #sortedInvalidStyles then
		return
	end

	self.numInvalidStyles = #sortedInvalidStyles
	log:warn("All unknown styles:\n", table.concat(sortedInvalidStyles, "\n"))
end


-- all valid styles
styles = {
	-- global icons
	"iconBackground",
	"iconBatteryNONE",
	"iconPlaylistModeOFF",
	"iconPlaylistModePARTY",
	"iconPlaymodeOFF",
	"iconPlaymodeSTOP",
	"iconPlaymodePLAY",
	"iconPlaymodePAUSE",
	"iconRepeatOFF",
	"iconRepeat0",
	"iconRepeat1",
	"iconRepeat2",
	"iconShuffleOFF",
	"iconShuffle0",
	"iconShuffle1",
	"iconShuffle2",
	"iconTime",
	"iconWirelessNONE",
	"iconWireless1",
	"iconWireless2",
	"iconWireless3",
	"iconWireless4",
	"iconWirelessERROR",
	"iconWirelessSERVERERROR",
	"icon_no_artwork",

	-- global buttons
	"button_back",
	"button_go_now_playing",
	"button_none",

	-- window styles
	"buttonlist.menu.scrollbar",
	"buttonlist.text",
	"buttonlist.title.button_help",
	"buttonlist.title.setup",
	"buttonlist.title.text",
	"buttonlist.menu.item.arrow",
	"buttonlist.menu.item.check",
	"buttonlist.menu.item.region_XX",
	"buttonlist.menu.item.region_US",
	"buttonlist.menu.item.text",
	"buttonlist.menu.pressed.item.arrow",
	"buttonlist.menu.pressed.item.region_US",
	"buttonlist.menu.pressed.item.region_XX",
	"buttonlist.menu.pressed.item.text",
	"buttonlist.menu.selected.item.arrow",
	"buttonlist.menu.selected.item.check",
	"buttonlist.menu.selected.item.region_US",
	"buttonlist.menu.selected.item.region_XX",
	"buttonlist.menu.selected.item.text",

	"currentsong.xxxx.icon",
	"currentsong.xxxx.popupplay",
	"currentsong.xxxx.text",

	"error.menu.scrollbar",
	"error.text",
	"error.title.setup",
	"error.title.text",
	"error.menu.item.arrow",
	"error.menu.item.check",
	"error.menu.item.icon",
	"error.menu.item.text",
	"error.menu.selected.item.arrow",
	"error.menu.selected.item.check",
	"error.menu.selected.item.icon",
	"error.menu.selected.item.text",

	"help.text",
	"help.title.setup",
	"help.title.text",

	"icon_list.menu.scrollbar",
	"icon_list.title.artists",
	"icon_list.title.text",
	"icon_list.title.icon",
	"icon_list.menu.item.arrow",
	"icon_list.menu.item.check",
	"icon_list.menu.item.icon",
	"icon_list.menu.item.text",
	"icon_list.menu.selected.item.arrow",
	"icon_list.menu.selected.item.check",
	"icon_list.menu.selected.item.icon",
	"icon_list.menu.selected.item.text",
	"icon_list.menu.locked.itemChecked.arrow",
	"icon_list.menu.locked.itemChecked.check",
	"icon_list.menu.locked.itemChecked.icon",
	"icon_list.menu.locked.itemChecked.text",
	"icon_list.menu.pressed.item.arrow",
	"icon_list.menu.pressed.item.icon",
	"icon_list.menu.pressed.item.text",
	"icon_list.menu.pressed.itemChecked.arrow",
	"icon_list.menu.pressed.itemChecked.check",
	"icon_list.menu.pressed.itemChecked.icon",
	"icon_list.menu.pressed.itemChecked.text",
	"icon_list.menu.selected.itemChecked.arrow",
	"icon_list.menu.selected.itemChecked.check",
	"icon_list.menu.selected.itemChecked.icon",
	"icon_list.menu.selected.itemChecked.text",

	"icontoast.xxxx.icon",
	"icontoast.xxxx.text",

	"information.text",
	"information.title.text",

	"input.keyboard.button",
	"input.keyboard.enter",
	"input.keyboard.keyboardBack",
	"input.keyboard.qwertyUpper",
	"input.keyboard.shift",
	"input.keyboard.space",
	"input.textinput",
	"input.title.setup",
	"input.title.text",
	"input.keyboard.pressed.enter",
	"input.keyboard.pressed.button",

	"onebutton.menu.scrollbar",
	"onebutton.text",
	"onebutton.title.text",
	"onebutton.menu.selected.item.arrow",
	"onebutton.menu.selected.item.check",
	"onebutton.menu.selected.item.icon",
	"onebutton.menu.selected.item.text",
	"onebutton.title.setup",
	"onebutton.menu.pressed.item.arrow",
	"onebutton.menu.pressed.item.text",

	"playlist.menu.scrollbar",
	"playlist.title.artists",
	"playlist.title.text",
	"playlist.menu.item.arrow",
	"playlist.menu.item.check",
	"playlist.menu.item.icon",
	"playlist.menu.item.text",
	"playlist.menu.selected.item.arrow",
	"playlist.menu.selected.item.check",
	"playlist.menu.selected.item.icon",
	"playlist.menu.selected.item.text",
	"playlist.menu.locked.itemChecked.arrow",
	"playlist.menu.locked.itemChecked.check",
	"playlist.menu.locked.itemChecked.icon",
	"playlist.menu.locked.itemChecked.text",
	"playlist.menu.pressed.item.arrow",
	"playlist.menu.pressed.item.icon",
	"playlist.menu.pressed.item.text",
	"playlist.menu.pressed.itemChecked.arrow",
	"playlist.menu.pressed.itemChecked.check",
	"playlist.menu.pressed.itemChecked.icon",
	"playlist.menu.pressed.itemChecked.text",
	"playlist.menu.selected.itemChecked.arrow",
	"playlist.menu.selected.itemChecked.check",
	"playlist.menu.selected.itemChecked.icon",
	"playlist.menu.selected.itemChecked.text",

	"setuplist.helptext",
	"setuplist.menu.scrollbar",
	"setuplist.title.setup",
	"setuplist.title.text",
	"setuplist.menu.item.arrow",
	"setuplist.menu.item.check",
	"setuplist.menu.item.icon",
	"setuplist.menu.item.text",
	"setuplist.menu.selected.item.arrow",
	"setuplist.menu.selected.item.check",
	"setuplist.menu.selected.item.icon",
	"setuplist.menu.selected.item.text",
	"setuplist.menu.pressed.item.arrow",
	"setuplist.menu.pressed.item.text",
	"setuplist.menu.pressed.itemChecked.arrow",
	"setuplist.menu.pressed.itemChecked.check",
	"setuplist.menu.pressed.itemChecked.text",
	"setuplist.menu.selected.itemChecked.arrow",
	"setuplist.menu.selected.itemChecked.check",
	"setuplist.menu.selected.itemChecked.text",

	"text_list.menu.scrollbar",
	"text_list.title.home",
	"text_list.title.text",
	"text_list.title.icon",
	"text_list.menu.item.arrow",
	"text_list.menu.item.check",
	"text_list.menu.item.icon",
	"text_list.menu.item.text",
	"text_list.menu.itemAdd.arrow",
	"text_list.menu.itemAdd.check",
	"text_list.menu.itemAdd.icon",
	"text_list.menu.itemAdd.text",
	"text_list.menu.itemPlay.arrow",
	"text_list.menu.itemPlay.check",
	"text_list.menu.itemPlay.icon",
	"text_list.menu.itemPlay.text",
	"text_list.menu.selected.item.arrow",
	"text_list.menu.selected.item.check",
	"text_list.menu.selected.item.icon",
	"text_list.menu.selected.item.text",
	"text_list.menu.selected.itemPlay.arrow",
	"text_list.menu.selected.itemPlay.check",
	"text_list.menu.selected.itemPlay.icon",
	"text_list.menu.selected.itemPlay.text",
	"text_list.menu.locked.itemChecked.arrow",
	"text_list.menu.locked.itemChecked.check",
	"text_list.menu.locked.itemChecked.text",
	"text_list.menu.pressed.item.arrow",
	"text_list.menu.pressed.item.text",
	"text_list.menu.pressed.itemChecked.arrow",
	"text_list.menu.pressed.itemChecked.check",
	"text_list.menu.pressed.itemChecked.text",
	"text_list.menu.selected.itemChecked.arrow",
	"text_list.menu.selected.itemChecked.check",
	"text_list.menu.selected.itemChecked.text",

	"toast.text",

	"tracklist.menu.scrollbar",
	"tracklist.title.icon",
	"tracklist.title.text",
	"tracklist.menu.item.arrow",
	"tracklist.menu.item.check",
	"tracklist.menu.item.icon",
	"tracklist.menu.item.text",
	"tracklist.menu.selected.item.arrow",
	"tracklist.menu.selected.item.check",
	"tracklist.menu.selected.item.icon",
	"tracklist.menu.selected.item.text",
	"tracklist.menu.locked.itemChecked.arrow",
	"tracklist.menu.locked.itemChecked.check",
	"tracklist.menu.locked.itemChecked.text",
	"tracklist.menu.pressed.item.arrow",
	"tracklist.menu.pressed.item.text",
	"tracklist.menu.pressed.itemChecked.arrow",
	"tracklist.menu.pressed.itemChecked.check",
	"tracklist.menu.pressed.itemChecked.text",
	"tracklist.menu.selected.itemChecked.arrow",
	"tracklist.menu.selected.itemChecked.check",
	"tracklist.menu.selected.itemChecked.text",

	"update.iconSoftwareUpdate",
	"update.progress",
	"update.subtext",
	"update.text",

	"waiting.iconConnecting",
	"waiting.subtext",
	"waiting.text",
}


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
