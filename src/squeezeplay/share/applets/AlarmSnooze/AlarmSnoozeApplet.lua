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
local Timer            = require("jive.ui.Timer")

local Player           = require("jive.slim.Player")
local LocalPlayer      = require("jive.slim.LocalPlayer")
local decode           = require("squeezeplay.decode")
                       
local appletManager	= appletManager
local jiveMain          = jiveMain
local jnt               = jnt

module(..., Framework.constants)
oo.class(_M, Applet)

function init(self, ...)

	local alarmNext = self:getSettings()['alarmNext']
	log:warn(alarmNext)

	jnt:subscribe(self)
	self.alarmTone = "applets/AlarmSnooze/alarm.mp3"

	local timeToAlarm
	if alarmNext then
		timeToAlarm = alarmNext
	else
		-- arbitrarily set timeToAlarmif there isn't one, 
		-- as it will be set again whenever it is invoked by an alarmNext param
		timeToAlarm = 86400
	end
	log:warn('RTC alarm timer: ', timeToAlarm)
	self.RTCAlarmTimer = Timer(timeToAlarm,
			function ()
				log:warn("RTC ALARM FIRING")
				appletManager:callService("deactivateScreensaver")
				self:openAlarmWindow(true)
			end,
			true
	)
	
	if alarmNext then
		log:warn('starting RTC alarm timer')
		self.RTCAlarmTimer:start()
	end

	return self
end
	



function notify_playerAlarmState(self, player, alarmState, alarmNext)

	if player:isLocal() then

		self.player = player
		-- store alarmNext data as epoch seconds
		if alarmNext then
			log:warn('storing epochseconds of next alarm:  ', alarmNext)
			local now = os.time()
	                self:getSettings()['alarmNext'] = alarmNext
			self:storeSettings()
			if self.RTCAlarmTimer:isRunning() then
				self.RTCAlarmTimer:stop()
			end
			self.RTCAlarmTimer:setInterval(self:_timerToAlarm(alarmNext))
			self.RTCAlarmTimer:start()
		end

		if alarmState == 'active' then
			if player ~= Player:getCurrentPlayer() then
				log:warn('alarm has fired locally, switching to local player')
                        	appletManager:callService("setCurrentPlayer", player)
			end

			if self.alarmWindow then
				self.alarmWindow:hide()
				self.alarmWindow = nil
			end

			if self.RTCAlarmTimer:isRunning() then
				self.RTCAlarmTimer:stop()
			end

			appletManager:callService("deactivateScreensaver")
			log:warn('open alarm window')
			self:openAlarmWindow()

		elseif alarmState == 'none' then
			log:warn('no alarm, unset this')
			self:getSettings()['alarmNext'] = nil
			self:storeSettings()
			if self.RTCAlarmTimer:isRunning() then
				self.RTCAlarmTimer:stop()
			end
		end
	end
end


function notify_playerConnected(self, player)
	if player:isLocal() then
		self.player = player
		decode:stop()
	end
end


-- returns milliseconds before the stored alarm from settings, stored in epoch secs
function _timerToAlarm(self, alarmNext)

	local now = os.time()
	-- milliseconds to next alarm
	-- if alarmNext is > now, assumption is that this is epochSecs alarmNext (from settings)
	-- otherwise it's in raw seconds
	if alarmNext > now then
		return (alarmNext - now) * 1000
	else
		return alarmNext * 1000
	end
end

function openAlarmWindow(self, fallback)

	if self.alarmWindow then
		return
	end

	local window = Window('alarm_popup', self:string('ALARM_SNOOZE_ALARM'))

	if not self.player:isConnected() or fallback then
		log:warn('activate RTC alarm')
		self.player:playFileInLoop(self.alarmTone)
		decode:audioGain(4096, 4096)
	end

	self.time = datetime:getCurrentTime()
	local icon = Icon('icon_alarm')
	local label = Label('alarm_time', self.time)
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

	local snoozeAction = function()
		self:_alarmSnooze()
		return EVENT_CONSUME
	end

	menu:addActionListener("back", self, cancelAction)
	menu:setHeaderWidget(headerGroup)

	menu:addActionListener("mute", self, snoozeAction)

        window:addTimer(1000, function() self:_updateTime() end)

	window:addWidget(menu)
	window:setShowFrameworkWidgets(false)
	window:setAllowScreensaver(false)
	window:show(Window.transitionFadeIn)

	self.alarmWindow = window
	self.timeWidget  = label
end


function _updateTime(self)
	local time = datetime:getCurrentTime()
	if time ~= self.time then
		log:debug('updating time in alarm window')
		self.time = time
		self.timeWidget:setValue(time)
	end
end

function _alarmOff(self)
	if self.player:isConnected() then
		self.player:stopAlarm()
	else
		decode:stop()
	end
	self.alarmWindow:playSound("WINDOWHIDE")
	self.alarmWindow:hide()
	self.alarmWindow = nil
end


function _alarmSnooze(self)
	if self.player:isConnected() then
		self.player:snooze()
	else
		-- stop playback
		decode:stop() 
		-- start another timer for 9 minutes
		log:warn('RTC alarm snoozing')
		if self.RTCAlarmTimer:isRunning() then
			self.RTCAlarmTimer:stop()
		end
		self.RTCAlarmTimer:restart(540000)
	end

	self.alarmWindow:playSound("WINDOWHIDE")
	self.alarmWindow:hide()
	self.alarmWindow = nil

end


function free(self)
	self.alarmWindow = nil
	return false
end
