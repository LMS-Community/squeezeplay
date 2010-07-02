
local ipairs, pairs = ipairs, pairs

local oo            = require("loop.simple")
local table         = require("jive.utils.table")

local Applet        = require("jive.Applet")

local Canvas        = require("jive.ui.Canvas")
local Framework     = require("jive.ui.Framework")
local Widget        = require("jive.ui.Widget")

local debug         = require("jive.utils.debug")

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

		-- use C cached stylePath where possible, naughtly but nice ;)
		local stylePath = widget._stylePath
		local peerToString = widget:peerToString()
		local indentString = ""
		if kids == 0 then
			if self.lastPeerToString ~= peerToString then
				log:warn("style: ", widget._stylePath , " | widget: ", peerToString, " ", widget:shortWidgetToString())
				local parent = widget:getParent()
				while parent do
					indentString = indentString .. "--"
					log:warn(indentString, "style: ", parent._stylePath , " | widget: ", parent:peerToString(), " ", parent:shortWidgetToString())
					parent = parent:getParent()
				end

				self.lastPeerToString = peerToString
			end
		end
	end

	widget:iterate(function(child)
		_debugWidget(self, screen, child)
	end)
end


function debugSkin(self)
	if self.colorEnabled then
		self.colorEnabled = nil

		self.validStyles = {}
		self.invalidStyles = {}

		Framework:removeWidget(self.canvas)
		Framework:removeListener(self.mouseListener)

		--reload skin, so existing windows will pick up the canvas change
		Framework:pushAction("reload_skin")

		return
	end

	self.colorEnabled = true

	self.canvas = Canvas("debug_canvas", function(screen)
		local window = Framework.windowStack[1]

		--log:info("Mouse in: ", window)
		window:iterate(function(w)
			_debugWidget(self, screen, w)
		end)
	end)
	Framework:addWidget(self.canvas)

	--reload skin, so existing windows will pick up the canvas change
	Framework:pushAction("reload_skin")

	self.mouseListener = Framework:addListener(EVENT_MOUSE_ALL,
		function(event)
			self.mouseEvent = event
			Framework:reDraw(nil)
		end, -99)
end


function debugStyle(self)
	if self.styleEnabled then
		self.styleEnabled = nil

		self.validStyles = {}
		self.invalidStyles = {}
		self.lastPeerToString = nil

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

	log:debug("Unknown styles in window:\n", window, "\n", table.concat(sortedInvalidWindow, "\n"))

	-- don't print if the all invalid styles have not changed
	local sortedInvalidStyles = _sortList(self.invalidStyles)
	if self.numInvalidStyles == #sortedInvalidStyles then
		return
	end

	self.numInvalidStyles = #sortedInvalidStyles
	log:debug("All unknown styles:\n", table.concat(sortedInvalidStyles, "\n"))
end


-- all valid styles
styles = {
	-- global icons
	"background",
	"button_battery_NONE",
	"button_playmode_OFF",
	"button_playmode_STOP",
	"button_playmode_PLAY",
	"button_playmode_PAUSE",
	"button_repeat_OFF",
	"button_repeat_0",
	"button_repeat_1",
	"button_repeat_2",
	"button_shuffle_OFF",
	"button_shuffle_0",
	"button_shuffle_1",
	"button_shuffle_2",
	"button_time",
	"button_wireless_NONE",
	"button_wireless_1",
	"button_wireless_2",
	"button_wireless_3",
	"button_wireless_4",
	"button_wireless_ERROR",
	"button_wireless_SERVERERROR",
	"button_no_artwork",

	-- global buttons
	"button_back",
	"button_go_now_playing",
	"button_none",

	-- window styles
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
	"icon_list.menu.locked.item_checked.arrow",
	"icon_list.menu.locked.item_checked.check",
	"icon_list.menu.locked.item_checked.icon",
	"icon_list.menu.locked.item_checked.text",
	"icon_list.menu.pressed.item.arrow",
	"icon_list.menu.pressed.item.icon",
	"icon_list.menu.pressed.item.text",
	"icon_list.menu.pressed.item_checked.arrow",
	"icon_list.menu.pressed.item_checked.check",
	"icon_list.menu.pressed.item_checked.icon",
	"icon_list.menu.pressed.item_checked.text",
	"icon_list.menu.selected.item_checked.arrow",
	"icon_list.menu.selected.item_checked.check",
	"icon_list.menu.selected.item_checked.icon",
	"icon_list.menu.selected.item_checked.text",

	"information.text",
	"information.title.text",

	"input.keyboard.button_back",
	"input.keyboard.button_pushed",
	"input.keyboard.button",
	"input.keyboard.button_enter",
	"input.keyboard.keyboardBack",
	"input.keyboard.qwerty",
	"input.keyboard.qwertyUpper",
	"input.keyboard.button_shift",
	"input.keyboard.button_space",
	"input.textinput",
	"input.title.setup",
	"input.title.text",
	"input.keyboard.pressed.button_enter",
	"input.keyboard.pressed.button",
	"input.keyboard.pressed.button_shift",
	"input.keyboard.pressed.button_pushed",

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
	"playlist.menu.locked.item_checked.arrow",
	"playlist.menu.locked.item_checked.check",
	"playlist.menu.locked.item_checked.icon",
	"playlist.menu.locked.item_checked.text",
	"playlist.menu.pressed.item.arrow",
	"playlist.menu.pressed.item.icon",
	"playlist.menu.pressed.item.text",
	"playlist.menu.pressed.item_checked.arrow",
	"playlist.menu.pressed.item_checked.check",
	"playlist.menu.pressed.item_checked.icon",
	"playlist.menu.pressed.item_checked.text",
	"playlist.menu.selected.item_checked.arrow",
	"playlist.menu.selected.item_checked.check",
	"playlist.menu.selected.item_checked.icon",
	"playlist.menu.selected.item_checked.text",

	"text_list.help_text",
	"text_list.menu.scrollbar",
	"text_list.title.setup",
	"text_list.title.text",
	"text_list.menu.item.arrow",
	"text_list.menu.item.check",
	"text_list.menu.item.icon",
	"text_list.menu.item.text",
	"text_list.menu.selected.item.arrow",
	"text_list.menu.selected.item.check",
	"text_list.menu.selected.item.icon",
	"text_list.menu.selected.item.text",
	"text_list.menu.pressed.item.arrow",
	"text_list.menu.pressed.item.text",
	"text_list.menu.pressed.item_checked.arrow",
	"text_list.menu.pressed.item_checked.check",
	"text_list.menu.pressed.item_checked.text",
	"text_list.menu.selected.item_checked.arrow",
	"text_list.menu.selected.item_checked.check",
	"text_list.menu.selected.item_checked.text",

	"text_list.menu.scrollbar",
	"text_list.title.home",
	"text_list.title.text",
	"text_list.title.icon",
	"text_list.menu.item.arrow",
	"text_list.menu.item.check",
	"text_list.menu.item.icon",
	"text_list.menu.item.text",
	"text_list.menu.item_add.arrow",
	"text_list.menu.item_add.check",
	"text_list.menu.item_add.icon",
	"text_list.menu.item_add.text",
	"text_list.menu.item_play.arrow",
	"text_list.menu.item_play.check",
	"text_list.menu.item_play.icon",
	"text_list.menu.item_play.text",
	"text_list.menu.selected.item.arrow",
	"text_list.menu.selected.item.check",
	"text_list.menu.selected.item.icon",
	"text_list.menu.selected.item.text",
	"text_list.menu.selected.item_play.arrow",
	"text_list.menu.selected.item_play.check",
	"text_list.menu.selected.item_play.icon",
	"text_list.menu.selected.item_play.text",
	"text_list.menu.locked.item_checked.arrow",
	"text_list.menu.locked.item_checked.check",
	"text_list.menu.locked.item_checked.text",
	"text_list.menu.pressed.item.arrow",
	"text_list.menu.pressed.item.text",
	"text_list.menu.pressed.item_checked.arrow",
	"text_list.menu.pressed.item_checked.check",
	"text_list.menu.pressed.item_checked.text",
	"text_list.menu.selected.item_checked.arrow",
	"text_list.menu.selected.item_checked.check",
	"text_list.menu.selected.item_checked.text",

	"text_list.menu.pressed.item.icon",
	"text_list.title.settingstitle",

	"toast_popup.text",

	"track_list.menu.scrollbar",
	"track_list.title.icon",
	"track_list.title.text",
	"track_list.menu.item.arrow",
	"track_list.menu.item.check",
	"track_list.menu.item.icon",
	"track_list.menu.item.text",
	"track_list.menu.selected.item.arrow",
	"track_list.menu.selected.item.check",
	"track_list.menu.selected.item.icon",
	"track_list.menu.selected.item.text",
	"track_list.menu.locked.item_checked.arrow",
	"track_list.menu.locked.item_checked.check",
	"track_list.menu.locked.item_checked.text",
	"track_list.menu.pressed.item.arrow",
	"track_list.menu.pressed.item.text",
	"track_list.menu.pressed.item_checked.arrow",
	"track_list.menu.pressed.item_checked.check",
	"track_list.menu.pressed.item_checked.text",
	"track_list.menu.selected.item_checked.arrow",
	"track_list.menu.selected.item_checked.check",
	"track_list.menu.selected.item_checked.text",

	"update.icon_software_update",
	"update.progress",
	"update.subtext",
	"update.text",

	"waiting_popup.icon_connecting",
	"waiting_popup.subtext",
	"waiting_popup.subtext_connected",
	"waiting_popup.text",
}


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
