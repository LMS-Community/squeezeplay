local pairs = pairs
local os	       = require("os")	
local table            = require("jive.utils.table")
local string	       = require("jive.utils.string")
local debug	       = require("jive.utils.debug")
local datetime         = require("jive.utils.datetime")
local log              = require("jive.utils.log").logger('jive.applets.SnoozeAlarm')

local oo               = require("loop.simple")

local Applet           = require("jive.Applet")
local Framework        = require("jive.ui.Framework")
local Group            = require("jive.ui.Group")
local Icon             = require("jive.ui.Icon")
local Label            = require("jive.ui.Label")
local SimpleMenu       = require("jive.ui.SimpleMenu")
local Window           = require("jive.ui.Window")
local Popup            = require("jive.ui.Popup")

local Player           = require("jive.slim.Player")
                       
local appletManager	= appletManager
local jiveMain          = jiveMain
local jnt               = jnt

module(..., Framework.constants)
oo.class(_M, Applet)

function __init(self, ...)
        local obj = oo.rawnew(self, Applet(...))
	jnt:subscribe(obj)
	return obj

end


function notify_playerAlarmState(self, player, alarmState)

	log:warn('alarmState: ', alarmState)
	if player:isLocal() then
		if alarmState == 'active' then
			log:warn('open alarm window')
			if player ~= Player:getCurrentPlayer() then
				-- TODO: switch from current player to local player
				log:warn('switch to local player')
			end
			self.player = player

			if self.alarmWindow then
				self.alarmWindow:hide()
				self.alarmWindow = nil
			end

			appletManager:callService("deactivateScreensaver")
			self:openAlarmWindow()
		end
	end
end


function openAlarmWindow(self)

	if self.alarmWindow then
		return
	end

	local window = Window('alarm_popup', self:string('ALARM_SNOOZE_ALARM'))

	local time = datetime:getCurrentTime()
	local icon = Icon('icon_alarm')
	local label = Label('alarm_time', time)
	local headerGroup = Group('alarm_header', {
		icon = icon,
		time = label,
	})

	local menu = SimpleMenu('menu')
	menu:addItem({
		text = self:string("ALARM_SNOOZE_SNOOZE"),
		sound = "WINDOWHIDE",
		callback = function()
			self:_alarmSnooze()
			end,
	})
	menu:addItem({
		text = self:string("ALARM_SNOOZE_TURN_OFF_ALARM"),
		sound = "WINDOWHIDE",
		callback = function()
			self:_alarmOff()
			end,
	})	
	menu:setSelectedIndex(1)

	local cancelAction = function()
		window:playSound("WINDOWHIDE")
		window:hide()
		self.alarmWindow = nil
		return EVENT_CONSUME
	end

	menu:addActionListener("back", self, cancelAction)
	menu:setHeaderWidget(headerGroup)

	window:addWidget(menu)
	window:setShowFrameworkWidgets(false)
	window:setAllowScreensaver(false)
	window:show(Window.transitionFadeIn)

	self.alarmWindow = window
	self.timeWidget  = label
end


function _alarmOff(self)
	self.player:stopAlarm()
	self.alarmWindow:hide()
	self.alarmWindow = nil
end


function _alarmSnooze(self)
	self.player:snooze()
	self.alarmWindow:hide()
	self.alarmWindow = nil
end


function free(self)
	self.alarmWindow = nil
	return false
end
