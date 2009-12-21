local _assert, pairs = _assert, pairs
local os	       = require("os")	
local table            = require("jive.utils.table")
local string	       = require("jive.utils.string")
local debug	       = require("jive.utils.debug")
local datetime         = require("jive.utils.datetime")

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
local iconbar           = iconbar
local jiveMain          = jiveMain
local jnt               = jnt

module(..., Framework.constants)
oo.class(_M, Applet)

function init(self, ...)

	self.alarmNext = self:getSettings()['alarmNext']

	jnt:subscribe(self)
	self.alarmTone = "applets/AlarmSnooze/alarm.mp3"

	local timeToAlarm
	local startTimer = false
	if self.alarmNext then
		if self:_inFuture() then
			timeToAlarm = self.alarmNext
			startTimer  = true
		else
			timeToAlarm = 86400000
		end
	else
		-- arbitrarily set timeToAlarm if there isn't one, 
		-- as it will be set again whenever it is invoked by an self.alarmNext param
		timeToAlarm = 86400000
	end
	self.RTCAlarmTimer = Timer(timeToAlarm,
			function ()
				log:warn("RTC ALARM FIRING")
				self:openAlarmWindow()
			end,
			true
	)
	
	if startTimer then
		self:_startTimer()
	end

	return self
end


function notify_playerAlarmState(self, player, alarmState, alarmNext)

	if player:isLocal() then

		log:warn(alarmState)
		-- store alarmNext data as epoch seconds
		if alarmNext and alarmNext > 0 then
			self.alarmNext = alarmNext
			log:info('storing epochseconds of next alarm:  ', self:_timerToAlarm())
	                self:getSettings()['alarmNext'] = alarmNext
			self:storeSettings()
			self:_setWakeupTime()
			self:_startTimer()
		end

		if alarmState == 'active' then
			if self.alarmWindow then
				self.alarmWindow:hide()
				self.alarmWindow = nil
			end

			log:info('open alarm window')
			self:openAlarmWindow()

		elseif alarmState == 'none' then
			self.alarmNext = false
			log:info('no alarm set, unset this')
			self:getSettings()['alarmNext'] = false
			self:storeSettings()
			self:_setWakeupTime('none')
			self:_stopTimer()
		end
	end
end


function notify_playerLoaded(self, player)
	log:debug('notify_playerLoaded()')
	if self.pendingAlarm then
		self.pendingAlarm = nil
		self:openAlarmWindow()
	end
end


function notify_playerConnected(self, player)
	if player:isLocal() then

		if self.fallbackRunning then
			log:warn('stop the audio on currently running RTC alarm')
			decode:stop()
			self.fallbackRunning = false
		end
	end
end


-- returns milliseconds before the stored alarm from settings, stored in epoch secs
function _timerToAlarm(self)

	_assert(self.alarmNext)

	local now = os.time()
	-- milliseconds to next alarm
	-- if self.alarmNext is > now, assumption is that this is epochSecs self.alarmNext (from settings)
	-- otherwise it's in raw seconds
	if self.alarmNext > now then
		return (self.alarmNext - now) * 1000
	else
		return self.alarmNext * 1000
	end
end


function _setWakeupTime(self, setting)
	if not setting then
		-- wakeup 3 minutes before alarm
		setting = self.alarmNext - 180
	end
	appletManager:callService("setWakeupAlarm", setting)
end


function openAlarmWindow(self)

	log:warn('openAlarmWindow()')

	-- if radio is controlling a different player, switch to the local player (if connected)
	-- and then have notify_playerLoaded then refire openAlarmWindow() for the pending alarm notice
	local localPlayer   = Player:getLocalPlayer()
	local currentPlayer = Player:getCurrentPlayer()

	if currentPlayer ~= localPlayer and localPlayer:isConnected() then
		log:warn('alarm has fired locally, switching squeezeplay control to connected local player')
		self.pendingAlarm = true
		appletManager:callService("setCurrentPlayer", localPlayer)
		return
	end

	self.localPlayer = localPlayer
	appletManager:callService("deactivateScreensaver")

	-- this method is called when the alarm time is hit
	-- when the alarm time is it, unset the wakeup mcu time
	self:_setWakeupTime('none')

	if not self.localPlayer then
		log:warn('cannot play an alarm without a player')
		return
	end
	if self.alarmWindow then
		return
	end

	local window = Window('alarm_popup', self:string('ALARM_SNOOZE_ALARM'))

	if not self.localPlayer:isConnected() then
		log:info('activate RTC alarm')
		self.localPlayer:playFileInLoop(self.alarmTone)
		decode:audioGain(4096, 4096)
		self.fallbackRunning = true
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

	local offAction = function()
		window:playSound("WINDOWHIDE")
		window:hide()
		self.alarmWindow = nil
		return EVENT_UNUSED
	end


	local snoozeAction = function()
		self:_alarmSnooze()
		return EVENT_CONSUME
	end

	menu:addActionListener("back", self, cancelAction)
	menu:addActionListener("power", self, offAction)
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
	if self.localPlayer:isConnected() then
		self.localPlayer:stopAlarm()
	else
		decode:stop()
		iconbar:setAlarm('OFF')
	end
	self:_stopTimer()
	self.alarmWindow:playSound("WINDOWHIDE")
	self.alarmWindow:hide()
	self.alarmWindow = nil
end


function _stopTimer(self)
	if self.RTCAlarmTimer:isRunning() then
		log:error('stopping RTC fallback alarm timer')
		self.RTCAlarmTimer:stop()
	end
end


function _inFuture(self)
	if not self.alarmNext then
		return false
	end

	local now = os.time()
	if self.alarmNext - now > 0 then
		return true
	end
	return false

end


function _startTimer(self, interval)
	if not self.alarmNext then
		return
	end

	local timerTime = self:_timerToAlarm()
	log:warn('starting RTC fallback alarm timer', timerTime)
	if interval then
		self.RTCAlarmTimer:setInterval(interval)
	else
		self.RTCAlarmTimer:setInterval(self:_timerToAlarm())
	end

	if not self.RTCAlarmTimer:isRunning() then
		self.RTCAlarmTimer:start()
	end
end


function _alarmSnooze(self)
	if self.localPlayer:isConnected() then
		self.localPlayer:snooze()
	else
		-- stop playback
		decode:stop() 
		log:warn('RTC alarm snoozing')
		self:_stopTimer()
		-- start another timer for 9 minutes
		self:_startTimer(540000)
	end

	self.alarmWindow:playSound("WINDOWHIDE")
	self.alarmWindow:hide()
	self.alarmWindow = nil

end


function free(self)
	self.alarmWindow = nil
	return false
end
