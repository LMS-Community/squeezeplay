local _assert, pairs = _assert, pairs
local ipairs, tostring = ipairs, tostring
local math             = require("math")
local ltable           = require("table")
local lstring          = require("string")
local os	       = require("os")
local io               = require("io")
local table            = require("jive.utils.table")
local string	       = require("jive.utils.string")
local debug	       = require("jive.utils.debug")
local datetime         = require("jive.utils.datetime")

local oo               = require("loop.simple")

local Applet           = require("jive.Applet")
local System           = require("jive.System")
local Framework        = require("jive.ui.Framework")
local Group            = require("jive.ui.Group")
local Icon             = require("jive.ui.Icon")
local Label            = require("jive.ui.Label")
local StickyMenu       = require("jive.ui.StickyMenu")
local SimpleMenu       = require("jive.ui.SimpleMenu")
local RadioGroup       = require("jive.ui.RadioGroup")
local RadioButton      = require("jive.ui.RadioButton")
local Slider           = require("jive.ui.Slider")
local Textarea         = require("jive.ui.Textarea")
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

--[[
New alarm code with less server dependency

We do not distiguish between 'server' and 'rtc' alarm anymore, because it's impossible to handle all cases like when a player gets disconnected / reconnected before an alarm, during an alarm or during a snooze phase. I also removed most of the 'notify_*' stuff as it does not help the case.

Instead we only use information from the server about the next alarm time. If a next alarm is set from the server we internally start a timer in parallel (RTCAlarmTimer). When the alarm time is reached the server will start to play the playlist and at the same time the internal timer shows the alarm window and checks periodically whether the audio state is indicating sound is actually playing.

- If the player is connected and the audio state test is ok the user hears the originally selected alarm.
- If the player is disconnected the audio state test will fail and the fallback alarm will be heard.

In both cases the user can stop the alarm or snooze as many times as she likes. After each snooze period the same scenario as with the original alarm happens.

If a particular alarm is still ongoing (either playing or snoozing) a new alarm time set from the server only starts the internal (RTCAlarmTimer) again, but does not affect the ongoing alarm. (i.e. snoozeTimer).

What's been changed so far:
- Unyfied log messages
- Server input via alarm notification is only used to set or clear an alarm time
- Server does not actually start the alarm process on the player (that is done by RTCAlarmTimer)
- Server only starts to play the choosen playlist at the alarm time
- A separate timer is used for snoozing (snoozeTimer) instead of sharing the alarm timer (RTCAlarmTimer)
- Check for good audio has been extended to a total of 60 seconds (was 25 seconds) to allow more time for slow radio stations

** Alarm version 2 adds:
- Retrieve one (the next) full alarm, including repeat and weekdays etc. to act upon it in case there is no server connection

TODO:
- Readd fade in for fallback alarm

]]--


function init(self, ...)
	-- Read stored alarm - for instance after reboot
	self.alarmNext = self:getSettings()['alarmNext']
	self.alarmRepeat = self:getSettings()['alarmRepeat']
	self.alarmDays = self:getSettings()['alarmDays']

	-- Get some data about the player
	self.localPlayer = Player:getLocalPlayer()
	self.server = self.localPlayer and self.localPlayer:getSlimServer()

	jnt:subscribe(self)

	self.alarmTone = "applets/AlarmSnooze/alarm.mp3"
	self.alarmInProgress = nil

	local timeToAlarm
	local startRTCAlarmTimer = false
	-- If there is a stored alarm start the RTC timer
	if self.alarmNext then
		timeToAlarm = self:_inFuture()
		if timeToAlarm then
			startRTCAlarmTimer  = true
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
			log:warn("*** Alarm: RTC alarm firing")

			if self.alarmInProgress then
				self:_alarmOff(true)
			end

			-- Stop a settings-menu preview (and its timers) before the alarm
			-- starts: a looping preview would otherwise count as good audio
			-- and keep the configured fallback from starting.
			self:_stopTone()

			self.alarmInProgress = 'rtc'

			-- Rearm fallback alarm (if repeating)
			self:rearmRTCAlarm()

			-- This also starts check about audio state
			self:openAlarmWindow()
		end,
		true	-- once
	)

	self.snoozeTimer = Timer(86400000,
		function ()
			log:warn("*** Alarm: Snooze time passed")
			self.alarmInProgress = 'rtc'
			-- Kick server again to play
			self.localPlayer:play(true)
			-- This also starts check about audio state
			self:openAlarmWindow()
		end,
		true	-- once
	)

	self.failedAudioTicker = 0
	self.decodeStatePoller = Timer(5000, 
		function ()
			self:_pollDecodeState()
		end,
		false	-- repeat
	)

	self.wakeOnLanTimer = Timer(86400000, -- arbitrary countdown, as timer interval will be set by _startTimer(), not here
		function()
			if self.server then
				log:warn("*** Alarm: WOL packet being sent to ", self.server)
				self.server:wakeOnLan()
			else
				log:warn("*** Alarm: WOL timer has been hit, but no self.server is available to send to")
			end
		end,
		true	-- once
	)

	self.statusPoller = Timer(1000, 
		function ()
			local status = decode:status()
			log:warn("*** Alarm ------------------------")
			log:warn("*** self.alarmInProgress:         ", self.alarmInProgress)
			log:warn("*** status.audioState:            ", status.audioState)
			log:warn("*** self.localPlayer.alarmState:  ", self.localPlayer:getAlarmState())
			log:warn("*** RTC fallback running?:        ", self.RTCAlarmTimer:isRunning())
			log:warn("*** self.server:                  ", self.server)

			if self.fallbackAlarmTimeout and self.fallbackAlarmTimeout:isRunning() then
				log:warn("*** Fallback timeout running?:    ", self.fallbackAlarmTimeout:isRunning())
			end

			if self.server then
				log:warn("*** self.server.mac:              ", self.server.mac)
			end
		end,
		false	-- repeat
	)

	-- this timer is for debug purposes only, to log state information every second for tracking purposes
	-- very useful when needed...
	--self.statusPoller:start()

	if startRTCAlarmTimer then
		self:_startRTCAlarmTimer()
	end
	
	return self
end

-- When an alarm fires, check if it's a repeating alarm and if yes, set the timer
--  according to the next day it should fire
-- This will be overwritten if the player is still connected or gets reconnected
function rearmRTCAlarm(self)
	if self.alarmRepeat and self.alarmRepeat == 1 and self.alarmDays and self.alarmDays != "0000000" then
		log:info("*** Alarm: Set repeating fallback alarm.")

		-- os.date("%w") returns 0-6 for Sun-Sat convert to 1-7 for Sun-Sat
		local weekDay = os.date("%w") + 1

		log:debug("*** Alarm: weekDay (1-7 => Sun-Sat): ", weekDay)
		log:debug("*** Alarm: days: ", self.alarmDays)

		-- Add alarm days at the end of itself to avoid dealing with wrapping
		local alarmDaysList = self.alarmDays .. self.alarmDays

		-- Find next day the alarm should fire
		local start, stop = string.find( alarmDaysList, "1", weekDay + 1)

		if not start then
			return
		end

		local numDays = start - weekDay

		log:debug("*** Alarm: nuber of days the next alarm is away: ", numDays)

		-- Calculate the next alarm time
		self.alarmNext = os.time() + numDays * (24 * 60 * 60)

		log:info("*** Alarm: Storing epochseconds of next alarm: ", self.alarmNext, " now: ", os.time())
	        self:getSettings()['alarmNext'] = self.alarmNext
		self:storeSettings()
		-- This is Baby only
		self:_setWakeupTime()
		-- Restart local timer
		self:_stopRTCAlarmTimer()
		self:_startRTCAlarmTimer()
	end
end


-- This notification is player status info from the server
-- OLD ALARM CODE
-- alarmNext > 0 sets an alarm (max 24 hours later)
-- alarmState == 'none' clears next alarm (but not an ongoing alarm), all other states are ignored as
--  it can hold old information and restart an old alarm if connection is reestablished

-- NEW ALARM CODE - handles repeated alarm that can be later than 24 hours
-- alarmNext2: epoch seconds to the next alarm (if any) or nil
-- alarmRepeat: 0/1/nil
-- alarmDays: string with alarm days starting with Sunday. Sample weekdays: "0111110"
function notify_playerAlarmState(self, player, alarmState, alarmNext, alarmVersion, alarmNext2, alarmRepeat, alarmDays)
	log:debug("*** Alarm: notify_playerAlarmState: player: ", player, " alarmState: ", alarmState)

	if not player then
		return
	end

	if not player:isLocal() then
		return
	end
	
	log:debug("*** Alarm: notify_playerAlarmState: alarmState: ", alarmState, " alarmNext: ", alarmNext)
	log:debug("*** Alarm: notify_playerAlarmState: alarmVersion: ", alarmVersion, " alarmNext2: ", alarmNext2, " alarmRepeat: ", alarmRepeat, " alarmDays: ", alarmDays)

	-- Old alarm code
	if not alarmVersion then
		log:debug("*** OLD ALARM CODE ***")
		-- Clear out alarm
		if alarmState == 'none' then
			self.alarmNext = false
			log:info("*** Alarm: No alarm set, clearing settings")
			self:getSettings()['alarmNext'] = false
			self:storeSettings()
			-- This is baby only
			self:_setWakeupTime('none')
			self:_stopRTCAlarmTimer()
		end
		
		-- store alarmNext data as epoch seconds
		if alarmNext and alarmNext > 0 then
			self.alarmNext = alarmNext

			log:info("*** Alarm: Storing epochseconds of next alarm: ", alarmNext, " now: ", os.time())
		        self:getSettings()['alarmNext'] = alarmNext
			self:storeSettings()
			-- This is Baby only
			self:_setWakeupTime()
			-- Restart local timer
			self:_stopRTCAlarmTimer()
			self:_startRTCAlarmTimer()
		end
	end

	-- New alarm code
	-- need to check alarmState too to prevent overriding values when it is 'active' or 'snooze'
	if alarmVersion and alarmVersion == 2 and (alarmState == 'none' or alarmState == 'set') then
		log:debug("*** NEW ALARM CODE ***")
		-- store alarmNext2 as epoch seconds
		if alarmNext2 and alarmNext2 > 0 then
			if alarmNext2 > os.time() then
				log:info("*** Alarm: Storing epochseconds of next alarm: ", alarmNext2, " now: ", os.time())

				-- use existing variable
				self.alarmNext = alarmNext2
				self.alarmRepeat = alarmRepeat
				self.alarmDays = alarmDays

				self:getSettings()['alarmNext'] = self.alarmNext
				self:getSettings()['alarmRepeat'] = self.alarmRepeat
				self:getSettings()['alarmDays'] = self.alarmDays
				self:storeSettings()

				-- This is Baby only
				self:_setWakeupTime()

				-- Restart local timer
				self:_stopRTCAlarmTimer()
				self:_startRTCAlarmTimer()
			else
				log:warn("*** Alarm: ignoring past alarm: ", alarmNext2, " now: ", os.time())
			end
		-- clear out alarm
		else
			log:info("*** Alarm: No alarm set, clearing settings")

			-- use existing variable
			self.alarmNext = false
			self.alarmRepeat = false
			self.alarmDays = false

			-- use existing variable
			self:getSettings()['alarmNext'] = false
			self:getSettings()['alarmRepeat'] = false
			self:getSettings()['alarmDays'] = false
			self:storeSettings()

			-- This is baby only
			self:_setWakeupTime('none')

			self:_stopRTCAlarmTimer()
		end
	end
end


function notify_playerPower(self, player, power)
	if not player then
		return
	end
        if player ~= self.localPlayer then
                return
        end
        log:debug("*** Alarm: notify_playerPower(): ", power)

        -- turning power off while alarm is in progress always means alarm should be cancelled
        if not power then
		if self.alarmInProgress then
			log:warn("*** Alarm: Power turned off while alarm in progress. By design, turn the alarm off")
			self:_alarmOff(true)
		end
        end
end


function notify_playerCurrent(self, player)
	log:info("*** Alarm: notify_playerCurrent: ", player)
	if not player then
		return
	end
	if player:isLocal() then
		self.localPlayer = player
	end
end


function notify_playerConnected(self, player)
	if not player then
		return
	end
	if player == self.localPlayer then
		-- Update our server
		self.server = player:getSlimServer()
	end
end


function _alarmSnooze(self)
	log:warn("*** Alarm: _alarmSnooze: alarmInProgress: ", self.alarmInProgress, " local player connected: ", self.localPlayer:isConnected())

	local alarmSnoozeSeconds = self.localPlayer:getAlarmSnoozeSeconds()
	local fallbackAlarmMsecs = alarmSnoozeSeconds * 1000 

	log:warn("*** Alarm: _alarmSnooze: fallback alarm snoozing for ", alarmSnoozeSeconds, " seconds")

	self:_stopDecodeStatePoller()
	self:_stopSnoozeTimer()
	self:_startSnoozeTimer(fallbackAlarmMsecs)
	
	log:warn("*** Alarm: _alarmSnooze: stopping fallback alarm audio")
	-- stop playback
	self:_silenceFallbackAlarm()

	if self.alarmWindow then
		self.alarmWindow:playSound("WINDOWHIDE")
		self:_hideAlarmWindow()
	end

	-- Inform server
	if self.localPlayer:isConnected() then
		log:warn("*** Alarm: _alarmSnooze: sending snooze command to connected server for connected local player ", self.localPlayer)
		self.localPlayer:snooze()
	end
end


function _alarmOff(self, stopStream)
	log:warn("*** Alarm: _alarmOff: RTC alarm canceled")
	
	self:_silenceFallbackAlarm()
	self.alarmInProgress = nil
	self:_stopSnoozeTimer()

	if self.alarmWindow then
		self.alarmWindow:playSound("WINDOWHIDE")
		self:_hideAlarmWindow()
	end
	self:_stopDecodeStatePoller()

	-- Inform server
	if self.localPlayer:isConnected() then
		log:warn("*** Alarm: _alarmOff: tell server alarm is off, and only pause if stopStream is true")
		self.localPlayer:stopAlarm(not stopStream)
	end
end


--[[
Fallback settings (menu: Instellingen > Geavanceerd > Wekker-fallback)
  fbSound  : sound file (relative path), default the original alarm.mp3
  fbVolume : 5-100, default 43 (original fixed value)
  fbFade   : fade-in seconds, 0 = off (default)
  fbDelay  : seconds of silence before the fallback starts, default 65 (original)
]]--

local FB_DEFAULT_SOUND  = "applets/AlarmSnooze/alarm.mp3"
local FB_DEFAULT_VOLUME = 43
local FB_DEFAULT_FADE   = 0
local FB_DEFAULT_DELAY  = 65
local FB_PREVIEW_MSECS  = 5000

local FB_SOUND_NAMES = {
	["alarm.mp3"]    = "FB_SOUND_ORIGINAL",
	["piep.mp3"]     = "FB_SOUND_BEEP",
	["oplopend.mp3"] = "FB_SOUND_RISING",
	["gong.mp3"]     = "FB_SOUND_GONG",
	["zacht.mp3"]    = "FB_SOUND_SOFT",
	["sirene.mp3"]   = "FB_SOUND_SIREN",
}

local FB_FADE_CHOICES  = { 0, 15, 30, 60, 120 }
local FB_DELAY_CHOICES = { 15, 30, 45, 65 }


function _fbSettings(self)
	local s = self:getSettings()
	local sound = s.fbSound or FB_DEFAULT_SOUND
	-- file removed? use the original sound
	if not System:findFile(sound) then
		sound = FB_DEFAULT_SOUND
	end
	return {
		sound  = sound,
		volume = s.fbVolume or FB_DEFAULT_VOLUME,
		fade   = s.fbFade or FB_DEFAULT_FADE,
		delay  = s.fbDelay or FB_DEFAULT_DELAY,
	}
end


function _fbSet(self, key, value)
	self:getSettings()[key] = value
	self:storeSettings()
end


function _stopFade(self)
	if self.fadeTimer then
		self.fadeTimer:stop()
		self.fadeTimer = nil
	end
end


-- Play a sound file in a loop at volume, optionally fading in over fadeSecs.
-- The volume from before the first tone is restored by _stopTone().
function _startTone(self, file, volume, fadeSecs, alarmState)
	if not self.toneActive then
		-- cache previous volume setting
		self.previousVolume = self.localPlayer:getVolume()
	end
	self.toneActive = true
	self:_stopFade()

	self.localPlayer:stop(true)
	if alarmState then
		-- Bug 16100 - Sound comes from headphones although Radio is set to use speaker
		-- We need to set a valid alarm state for the fallback case
		self.localPlayer:setAlarmState(alarmState)
	end
	self.localPlayer:playFileInLoop(file)

	if fadeSecs and fadeSecs > 0 then
		local startVolume = math.min(5, volume)
		local step = 0
		-- last volume written by the fade; anything else means the user
		-- changed the volume, which ends the fade
		local fadeVolume = startVolume
		self.localPlayer:volumeLocal(startVolume)
		self.fadeTimer = Timer(1000,
			function()
				if self.localPlayer:getVolume() ~= fadeVolume then
					log:warn("*** Alarm: volume changed by user, stopping fade-in")
					self:_stopFade()
					return
				end
				step = step + 1
				local v = startVolume + (volume - startVolume) * step / fadeSecs
				if step >= fadeSecs then
					v = volume
					self:_stopFade()
				end
				fadeVolume = math.floor(v + 0.5)
				self.localPlayer:volumeLocal(fadeVolume)
			end,
			false	-- repeat
		)
		self.fadeTimer:start()
	else
		self.localPlayer:volumeLocal(volume)
	end
end


function _stopTone(self)
	self:_stopFade()
	if self.previewTimer then
		self.previewTimer:stop()
	end
	if not self.toneActive then
		return
	end
	self.toneActive = false
	self.localPlayer:stop(true)
	if self.previousVolume then
		log:warn("*** Alarm: setting player back to self.previousVolume: ", self.previousVolume)
		self.localPlayer:volumeLocal(self.previousVolume)
	end
end


function soundFallbackAlarm(self)
	local fb = self:_fbSettings()
	log:warn("*** Alarm: soundFallbackAlarm() sound: ", fb.sound, " volume: ", fb.volume, " fade: ", fb.fade)
	self:_startTone(fb.sound, fb.volume, fb.fade, "active_fallback")
end


function _silenceFallbackAlarm(self)
	if not self.localPlayer then
		log:error("*** Alarm: No self.localPlayer found!")
		return
	end
	self.localPlayer:stop(true)
	self:_stopTone()
	if self.fallbackAlarmTimeout and self.fallbackAlarmTimeout:isRunning() then
		log:warn("*** Alarm: stopping fallback alarm timeout timer")
		self.fallbackAlarmTimeout:stop()
	end
end


function _pollDecodeState(self)
	local status = decode:status()

	log:warn("*** Alarm: _pollDecodeState: alarmInProgress: ", self.alarmInProgress, " audioState: ", status.audioState)

	if self.alarmInProgress and status.audioState ~= 1 then
		self.failedAudioTicker = self.failedAudioTicker + 1
		log:warn("*** Alarm: Audio failed! failedAudioTicker: ", self.failedAudioTicker)
	else
		self.failedAudioTicker = 0
		log:warn("*** Alarm: Audio ok -> reset failedAudioTicker: ", self.failedAudioTicker)
	end

	-- poller runs every 5 seconds; default 65 s equals the original "> 12 ticks"
	if self.failedAudioTicker * 5 >= self:_fbSettings().delay then
		log:warn("*** Alarm: Decode state bad! failedAudioTicker: ", self.failedAudioTicker, " Trigger fallback alarm!")

		self.failedAudioTicker = 0
		return self:soundFallbackAlarm()
	end
end


function _startDecodeStatePoller(self)
	if self.decodeStatePoller then
		if self.decodeStatePoller:isRunning() then
			log:warn("*** Alarm: restart decodeStatePoller")
			self.decodeStatePoller:restart()
		else
			log:warn("*** Alarm: start decodeStatePoller")
			self.decodeStatePoller:start()
		end
	end
end


function _stopDecodeStatePoller(self)
	if self.decodeStatePoller and self.decodeStatePoller:isRunning() then
		log:warn("*** Alarm: stopping decodeStatePoller")
		self.decodeStatePoller:stop()
	end
end


function _inFuture(self)
	if not self.alarmNext then
		return false
	end

	local now = os.time()
	if self.alarmNext - now > 0 then
		return self.alarmNext - now
	end
	return false
end


function _startRTCAlarmTimer(self)
	
	if not self.alarmNext then
		log:error("*** Alarm: alarmNext has no value!")
		return
	end

	if self.RTCAlarmTimer:isRunning() then
		self.RTCAlarmTimer:stop()
		log:warn("*** Alarm: _startRTCAlarmTimer: stopping RTC fallback alarm timer")
	end
	
	-- get msecs between now and requested alarm
	local rtcSleepMsecs = self:_deltaMsecs(self.alarmNext)

	log:warn("*** Alarm: _startRTCAlarmTimer: starting RTC fallback alarm timer - rtcSleepMsecs: ", rtcSleepMsecs)
	self.RTCAlarmTimer:setInterval(rtcSleepMsecs)

	-- restart the WOL timer for 5 minutes, or immediately send WOL if alarm is within 5 mins
	self:_restartWakeOnLanTimer(rtcSleepMsecs)

	self.RTCAlarmTimer:start()
	iconbar:setAlarm('ON')
end


function _stopRTCAlarmTimer(self)
	if self.RTCAlarmTimer:isRunning() then
		log:warn("*** Alarm: _stopRTCAlarmTimer: stopping RTC fallback alarm timer")
		self.RTCAlarmTimer:stop()
	end

	if self.wakeOnLanTimer:isRunning() then
		log:warn("*** Alarm: _stopRTCAlarmTimer: stopping WOL timer")
		self.wakeOnLanTimer:stop()
	end

	-- no RTC timer means no alarm, so let's go ahead and remove our alarm icon
	iconbar:setAlarm('OFF')
end


function _startSnoozeTimer(self, interval)
	
	if not interval then
		log:error("*** Alarm: interval has no value!")
		return
	end

	if self.snoozeTimer:isRunning() then
		self.snoozeTimer:stop()
		log:warn("*** Alarm: _startSnoozeTimer: stopping snooze timer")
	end
	
	log:warn("*** Alarm: _startSnoozeTimer: starting snooze timer - interval: ", interval)
	self.snoozeTimer:setInterval(interval)

	self.snoozeTimer:start()
	iconbar:setAlarm('ON')
end


function _stopSnoozeTimer(self)
	if self.snoozeTimer:isRunning() then
		log:warn("*** Alarm: _stopSnoozeTimer: stopping snooze timer")
		self.snoozeTimer:stop()
	end

	-- no RTC timer means no alarm, so let's go ahead and remove our alarm icon
	iconbar:setAlarm('OFF')
end


function _restartWakeOnLanTimer(self, msecsToAlarm)
	local wolLeadTime = 1000 * 60 * 5 -- 5 minutes
	if msecsToAlarm > wolLeadTime then
		log:warn("*** Alarm: _wolTimerRestart - Start WOL timer: ", msecsToAlarm - wolLeadTime)
		self.wakeOnLanTimer:setInterval(msecsToAlarm - wolLeadTime)
		if self.wakeOnLanTimer:isRunning() then
			self.wakeOnLanTimer:restart()
		else
			self.wakeOnLanTimer:start()
		end
	-- if it's within 5 minutes, send a WOL packet as a best effort
	elseif self.server then
		log:warn("*** Alarm: _wolTimerRestart - Send WOL now!")
		self.server:wakeOnLan()
	end	
end


function openAlarmWindow(self)

	-- Bug 16230: if self.localPlayer hasn't been set, try to here as it's essential to the alarm working
	if not self.localPlayer then
		log:warn("*** Alarm: openAlarmWindow: called without self.localPlayer being set. try to acquire it now")
		self.localPlayer = Player:getLocalPlayer()
		-- if that returns nil (very unlikely), throw an error and return
		if not self.localPlayer then
			log:error("*** Alarm: openAlarmWindow: without self.localPlayer the alarm cannot sound")
			return
		end
	end

	log:warn("*** Alarm: openAlarmWindow: local player connected: " , self.localPlayer:isConnected())

	-- if UI is controlling a different player, switch to the local player
	local currentPlayer = Player:getCurrentPlayer()

	if currentPlayer ~= self.localPlayer then
		log:warn("*** Alarm: openAlarmWindow: switching squeezeplay control to local player: ", self.localPlayer, " from current player: ", currentPlayer)
		appletManager:callService("setCurrentPlayer", self.localPlayer)
	end

	appletManager:callService("deactivateScreensaver")
	
	-- this method is called when the alarm time is hit
	-- when the alarm time is hit, unset the wakeup mcu time
	self:_setWakeupTime('none')

	self:_startDecodeStatePoller()

	local alarmTimeoutSeconds = self.localPlayer:getAlarmTimeoutSeconds() or ( 60 * 60 ) -- defaults to 1 hour
	if alarmTimeoutSeconds ~= 0 then
		local alarmTimeoutMsecs = alarmTimeoutSeconds * 1000
		log:info("*** Alarm: Fallback alarm will timeout in ", alarmTimeoutSeconds, " seconds")
		self.fallbackAlarmTimeout = Timer(alarmTimeoutMsecs,
				function ()
					if self.alarmInProgress then
						log:warn("*** Alarm: RTC alarm has timed out")
						self:_alarmOff()
					end
				end,
				true
		)
		if self.fallbackAlarmTimeout:isRunning() then
			self.fallbackAlarmTimeout:restart()
		else
			self.fallbackAlarmTimeout:start()
		end
	end

	-- Bug 16100 - Sound comes from headphones although Radio is set to use speaker
	-- Calling _alarmThroughSpeakers() here works for regular, fallback alarm and snooze
	self:_alarmThroughSpeakers()

	if self.alarmWindow then
		return
	end

	local window = Window('alarm_popup')

	self.time = self:_formattedTime()

	local label = Label('alarm_time', self.time)
	local headerGroup = Group('alarm_header', {
		time = label,
	})

	-- Bug 15398: make this menu 6x stickier than a normal menu for scrolling
	local menu = StickyMenu('menu', 6)
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
			self:_alarmOff(true)
			end,
	})	
	menu:setSelectedIndex(1)

	local cancelAction = function()
		window:playSound("WINDOWHIDE")
		self:_alarmOff(false)
		return EVENT_CONSUME
	end

	local pauseAction = function()
		window:playSound("WINDOWHIDE")
		self:_alarmOff(true)
		return EVENT_UNUSED
	end

	local consumeAction = function()
		log:warn("*** Alarm: Consuming this action")
		Framework:playSound("BUMP")
		window:bumpLeft()
		return EVENT_CONSUME
	end

	local offAction = function()
		self:_alarmOff(true)
		return EVENT_UNUSED
	end
	
	local snoozeAction = function()
		self:_alarmSnooze()
		return EVENT_CONSUME
	end

	menu:addActionListener("back", self, cancelAction)
	menu:addActionListener("power", self, offAction)
	menu:addActionListener("mute", self, snoozeAction)
	menu:addActionListener("pause", self, pauseAction)

	window:ignoreAllInputExcept(
		--these actions are not ignored
		{ 'go', 'back', 'power', 'mute', 'volume_up', 'volume_down', 'pause' }, 
		-- consumeAction is the callback issued for all "ignored" input
		consumeAction 
	)

	menu:setHeaderWidget(headerGroup)

	window:setButtonAction('rbutton', 'cancel')
        window:addActionListener("cancel", self, 
		function() 	
			window:hide(Window.transitionNone)
		end 
	)
        window:setButtonAction('lbutton', nil, nil)

	window:addWidget(menu)
	window:setShowFrameworkWidgets(false)
	window:setAllowScreensaver(false)
	window:show(Window.transitionFadeIn)

	window:addTimer(1000, 
			function() 
				self:_updateTime() 
			end
	)

	window:setAlwaysOnTop(true)
	self.alarmWindow = window
	self.timeWidget  = label

end


function _hideAlarmWindow(self)
	if self.alarmWindow then
		self.alarmWindow:hide()
		self.alarmWindow = nil
		self:_revertAudioEndpointOverride()
	end
end


--------------------------------------------------------------------------------
-- Fallback settings menu
--
-- Windows are shown with window:show() and NOT tied to the applet: this applet
-- is resident, and tieWindow() would call free() (clearing alarmWindow) on close.
-- Previews are never played while an alarm is in progress.
--------------------------------------------------------------------------------

function _fbCanPreview(self)
	if self.alarmInProgress then
		log:warn("*** Alarm: preview skipped, alarm in progress")
		return false
	end
	if not self.localPlayer then
		self.localPlayer = Player:getLocalPlayer()
	end
	return self.localPlayer ~= nil
end


-- Stop a menu preview; never touches a real (fallback) alarm
function _fbStopPreview(self)
	if self.alarmInProgress then
		return
	end
	self:_stopTone()
end


function _fbSoundName(self, path)
	local file = lstring.match(path, "([^/]+)$") or path
	if FB_SOUND_NAMES[file] then
		return tostring(self:string(FB_SOUND_NAMES[file]))
	end
	return (lstring.gsub(file, "%.[mM][pP]3$", ""))
end


-- All selectable sounds: the original plus every mp3 in applets/AlarmSnooze/sounds/
function _fbSoundList(self)
	local list = { FB_DEFAULT_SOUND }
	local seen = { [FB_DEFAULT_SOUND] = true }
	for file in self:readdir("sounds") do
		if lstring.match(file, "%.[mM][pP]3$") and not seen[file] then
			seen[file] = true
			list[#list + 1] = file
		end
	end
	ltable.sort(list, function(a, b)
		if a == FB_DEFAULT_SOUND then return true end
		if b == FB_DEFAULT_SOUND then return false end
		return self:_fbSoundName(a) < self:_fbSoundName(b)
	end)
	return list
end


function _fbSecondsText(self, secs)
	if secs == 0 then
		return tostring(self:string("FB_OFF"))
	elseif secs >= 60 and secs % 60 == 0 then
		return self:string("FB_MINUTES", secs / 60)
	end
	return self:string("FB_SECONDS", secs)
end


function _fbRefreshMenu(self)
	if not self.fbMenu then
		return
	end
	local fb = self:_fbSettings()
	local items = self.fbItems
	self.fbMenu:setText(items.sound,  self:string("FB_ITEM_SOUND",  self:_fbSoundName(fb.sound)))
	self.fbMenu:setText(items.volume, self:string("FB_ITEM_VOLUME", fb.volume))
	self.fbMenu:setText(items.fade,   self:string("FB_ITEM_FADE",   self:_fbSecondsText(fb.fade)))
	self.fbMenu:setText(items.delay,  self:string("FB_ITEM_DELAY",  self:_fbSecondsText(fb.delay)))
end


function fallbackSettingsShow(self, menuItem)
	local window = Window("text_list", self:string("ALARM_FALLBACK_SETTINGS"), "settingstitle")
	local menu = SimpleMenu("menu")
	menu:setHeaderWidget(Textarea("help_text", self:string("FB_HELP")))

	local items = {
		sound  = { text = "", callback = function() self:_fbSoundShow() end },
		volume = { text = "", callback = function() self:_fbVolumeShow() end },
		fade   = { text = "", callback = function()
				self:_fbChoiceShow("FB_TITLE_FADE", "fbFade", FB_FADE_CHOICES, self:_fbSettings().fade)
			end },
		delay  = { text = "", callback = function()
				self:_fbChoiceShow("FB_TITLE_DELAY", "fbDelay", FB_DELAY_CHOICES, self:_fbSettings().delay)
			end },
		test   = { text = self:string("FB_ITEM_TEST"), callback = function() self:_fbTestShow() end },
	}
	for _, key in ipairs({ "sound", "volume", "fade", "delay", "test" }) do
		menu:addItem(items[key])
	end

	self.fbMenu = menu
	self.fbItems = items
	self:_fbRefreshMenu()

	window:addWidget(menu)
	window:addListener(EVENT_WINDOW_POP,
		function()
			self.fbMenu = nil
			self.fbItems = nil
		end)
	window:show()
	return window
end


function _fbSoundShow(self)
	local window = Window("text_list", self:string("FB_TITLE_SOUND"), "settingstitle")
	local menu = SimpleMenu("menu")
	local group = RadioGroup()
	local current = self:_fbSettings().sound

	menu:setHeaderWidget(Textarea("help_text", self:string("FB_SOUND_HELP")))

	for _, file in ipairs(self:_fbSoundList()) do
		menu:addItem({
			text = self:_fbSoundName(file),
			style = 'item_choice',
			check = RadioButton("radio", group,
				function()
					log:info("*** Alarm: fallback sound set to ", file)
					self:_fbSet("fbSound", file)
					self:_fbRefreshMenu()
					self:_fbPreview(file)
				end,
				file == current
			),
		})
	end

	window:addWidget(menu)
	window:addListener(EVENT_WINDOW_POP, function() self:_fbStopPreview() end)
	window:show()
	return window
end


-- Play a short preview of a sound at the configured volume (no fade)
function _fbPreview(self, file)
	if not self:_fbCanPreview() then
		return
	end
	self:_startTone(file, self:_fbSettings().volume, 0)
	if not self.previewTimer then
		self.previewTimer = Timer(FB_PREVIEW_MSECS, function() self:_fbStopPreview() end, true)
	end
	self.previewTimer:restart(FB_PREVIEW_MSECS)
end


function _fbVolumeShow(self)
	local window = Window("text_list", self:string("FB_TITLE_VOLUME"), "settingstitle")
	local fb = self:_fbSettings()
	local slider

	local setVolume = function(value)
		if value < 1 then value = 1 end
		if value > 20 then value = 20 end
		local volume = value * 5
		self:_fbSet("fbVolume", volume)
		self:_fbRefreshMenu()
		if self.toneActive and not self.alarmInProgress then
			self.localPlayer:volumeLocal(volume)
		end
		return value
	end

	slider = Slider("volume_slider", 1, 20, math.max(1, math.floor(fb.volume / 5 + 0.5)),
		function(slider, value)
			setVolume(value)
		end)

	slider:addListener(EVENT_KEY_PRESS,
		function(event)
			local code = event:getKeycode()
			if code == KEY_VOLUME_UP then
				slider:setValue(setVolume(slider:getValue() + 1))
				return EVENT_CONSUME
			elseif code == KEY_VOLUME_DOWN then
				slider:setValue(setVolume(slider:getValue() - 1))
				return EVENT_CONSUME
			end
			return EVENT_UNUSED
		end)

	window:addWidget(Textarea("help_text", self:string("FB_VOLUME_HELP")))
	window:addWidget(Group("slider_group", {
		min = Icon("button_volume_min"),
		slider = slider,
		max = Icon("button_volume_max"),
	}))

	-- loop the chosen sound while this window is open
	if self:_fbCanPreview() then
		self:_startTone(fb.sound, fb.volume, 0)
	end
	window:addListener(EVENT_WINDOW_POP, function() self:_fbStopPreview() end)

	window:show()
	return window
end


function _fbChoiceShow(self, title, key, choices, current)
	local window = Window("text_list", self:string(title), "settingstitle")
	local menu = SimpleMenu("menu")
	local group = RadioGroup()

	for _, secs in ipairs(choices) do
		local text = self:_fbSecondsText(secs)
		if key == "fbDelay" and secs == FB_DEFAULT_DELAY then
			text = self:string("FB_DEFAULT", text)
		end
		menu:addItem({
			text = text,
			style = 'item_choice',
			check = RadioButton("radio", group,
				function()
					log:info("*** Alarm: ", key, " set to ", secs)
					self:_fbSet(key, secs)
					self:_fbRefreshMenu()
				end,
				secs == current
			),
		})
	end

	window:addWidget(menu)
	window:show()
	return window
end


function _fbTestShow(self)
	local window = Window("text_list", self:string("FB_ITEM_TEST"), "settingstitle")
	local fb = self:_fbSettings()

	if self:_fbCanPreview() then
		window:addWidget(Textarea("help_text", self:string("FB_TEST_HELP",
			self:_fbSoundName(fb.sound), fb.volume, self:_fbSecondsText(fb.fade))))
		self:_startTone(fb.sound, fb.volume, fb.fade)
	else
		window:addWidget(Textarea("help_text", self:string("FB_TEST_BUSY")))
	end

	window:addListener(EVENT_WINDOW_POP, function() self:_fbStopPreview() end)
	window:setAllowScreensaver(false)
	window:show()
	return window
end


function free(self)
	self.alarmWindow = nil
	return false
end


function _updateTime(self)
	local time = self:_formattedTime()
	if time ~= self.time then 	 
		log:debug("*** Alarm: updating time in alarm window") 	 
		self.time = time 	 
		self.timeWidget:setValue(time) 	 
	end 	 
end


function _formattedTime(self)
	if not self.clockFormat then
		self.clockFormat = datetime:getHours()
	end

	local time
	if self.clockFormat == '12' then
		time = datetime:getCurrentTime('%I:%M')
	else
		time = datetime:getCurrentTime()
	end
	return time
end


-- returns the millisecond delta between now (current time) and the epochsecs parameter
-- returns default of 1000ms if epochsecs is in the past...
function _deltaMsecs(self, epochsecs)

	local deltaSecs = epochsecs - os.time() 
	if deltaSecs <= 0 then
		log:warn("*** Alarm: _deltaMsecs: epochsecs is in the past, deltaSecs: ", deltaSecs)
		return(1000)
	end
	-- else
	return(deltaSecs * 1000)
end


-- This is Baby only
function _setWakeupTime(self, setting)
	if not setting then
		-- wakeup 3 minutes before alarm
		setting = self.alarmNext - 180
	end
	appletManager:callService("setWakeupAlarm", setting)
end


-- On player with multiple audio output endpoints guarantee that alarm audio
-- comes through speakers even even Headphones (or some other output) is enabled
function _alarmThroughSpeakers(self)
	appletManager:callService("overrideAudioEndpoint", 'Speaker')
end

-- If alarm was overridden to the speaker then, when alarm is turned off, we need to 
-- revert the audio endpoint
--
-- note: this method is called from the _hideAlarmWindow() method, so if at some future date
-- there are options added to allow a user to have an alarm with no notification window, 
-- where the revert method is called  needs rethinking
function _revertAudioEndpointOverride(self)
	appletManager:callService("overrideAudioEndpoint", nil)
end

--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
