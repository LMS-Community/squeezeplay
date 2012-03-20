local _assert, pairs = _assert, pairs
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
	self.localPlayer = Player:getLocalPlayer()
	self.server = self.localPlayer and self.localPlayer:getSlimServer()

	jnt:subscribe(self)
	self.alarmTone = "applets/AlarmSnooze/alarm.mp3"
	
	self.alarmInProgress = nil

	local timeToAlarm
	local startTimer = false
	if self.alarmNext then
		timeToAlarm = self:_inFuture()
		if timeToAlarm then
			startTimer  = true
		else
			timeToAlarm = 86400000
		end
	else
		-- arbitrarily set timeToAlarm if there isn't one, 
		-- as it will be set again whenever it is invoked by an self.alarmNext param
		timeToAlarm = 86400000
	end

	self.debugRTCTime = timeToAlarm
	self.debugWOLTime = 0
	self.failedAudioTicker = 0
	self.RTCAlarmTimer = Timer(timeToAlarm,
			function ()
				log:warn("*** Alarm: RTC alarm firing")
				self:openAlarmWindow('rtc')
			end,
			true
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
			true
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
			if self.RTCAlarmTimer:isRunning() and self.debugRTCTime and self.debugRTCTime > 0 then
				local timeToAlarm = self.debugRTCTime / 1000
				log:warn("*** RTC time:                     ", timeToAlarm)
				if self.debugRTCTime > 0 then	
					self.debugRTCTime = self.debugRTCTime - 1000
				end
			end
			if self.wakeOnLanTimer:isRunning() and self.debugWOLTime and self.debugWOLTime > 0 then
				local timeToWOL = self.debugWOLTime / 1000
				log:warn("*** WOL timer:                    ", timeToWOL)
				if self.debugWOLTime > 0 then	
					self.debugWOLTime = self.debugWOLTime - 1000
				end
			end
		end,
	false)

	-- this timer is for debug purposes only, to log state information every second for tracking purposes
	-- very useful when needed...
	--self.statusPoller:start()

	if startTimer then
		self:_startTimer()
	end

	self.decodeStatePoller = Timer(5000, 
		function ()
			self:_pollDecodeState()
		end,
	false)
	
	return self
end


function notify_playerAlarmState(self, player, alarmState, alarmNext)

	log:warn("*** Alarm: notify_playerAlarmState: player: ", player, " alarmState: ", alarmState)
	if not player then
		return
	end
	if player:isLocal() then
		log:warn("*** Alarm: notify_playerAlarmState: alarmState: ", alarmState, " alarmNext: ", alarmNext)
		-- if there's an existing alarm window on the screen and the RTC alarm isn't firing, 
		-- we're going to hide it in the event of this notification. if alarmState is 'active', we bring up a new one
		if self.alarmInProgress ~= 'rtc' then
			self:_hideAlarmWindow()
		end

		if alarmState == 'active' then
			if player ~= Player:getCurrentPlayer() then
				log:warn("*** Alarm: Local alarm has fired -> switching to local player")
                        	appletManager:callService("setCurrentPlayer", player)
			end

			-- ignore server alarm if an alarm is already in progress
			if self.alarmInProgress == 'rtc' then
				log:warn("*** Alarm: Ignore server alarm because fallback fired prior")
				return
			elseif self.alarmInProgress == 'server' then
				log:info("*** Alarm: [likely post-snooze] alarm notification received while alarm already in progress")
			    -- keep going 
			end

			-- stop fallback timer and proceed
			self.alarmInProgress = 'server'
			self:_stopTimer()			
			self:openAlarmWindow('server')

		elseif alarmState == 'snooze' then
			log:warn("*** Alarm: snooze state received")
			self.alarmInProgress = alarmState
			log:warn("*** Alarm: self.alarmInProgress: ", self.alarmInProgress)

		elseif alarmState == 'none' then
			if self.alarmInProgress ~= 'rtc' then
				self.alarmNext = false
				log:info("*** Alarm: No alarm set, clearing settings")
				self:getSettings()['alarmNext'] = false
				self:storeSettings()
				self:_setWakeupTime('none')
				self.alarmInProgress = nil
		                -- might want to qualify whether or not to stop this timer dependent upon whether it's already running.
				-- for now just log the information
				if self.RTCAlarmTimer:isRunning() then
					log:warn("*** Alarm: Clear alarm received while RTC timer is running! Stopping. Careful now...")
				end
				self:_stopDecodeStatePoller()
				self:_stopTimer()
			else
				log:warn("*** Alarm: Clear alarm received while fallback alarm in progress! Ignoring")
				return
			end

		elseif alarmState == 'set' then
			self:_stopDecodeStatePoller()
			if self.alarmInProgress ~= 'rtc' then
				self.alarmInProgress = nil
			end
		end
		
		-- store alarmNext data as epoch seconds
		if alarmNext and alarmNext > 0 then

			log:debug("*** Alarm: notify_playerAlarmState: alarmNext: ", alarmNext, " : NOW is ", os.time())
		
			-- want to know if this happens
			if alarmState == 'active' then
			    log:error("*** Alarm: notify_playerAlarmState: alarmNext: ", alarmNext, " while alarmState is ACTIVE! Ignoring...")
				return
			end

			self.alarmNext = alarmNext

			log:info("*** Alarm: Storing epochseconds of next alarm: ", alarmNext)
		        self:getSettings()['alarmNext'] = alarmNext

			self:storeSettings()
			self:_setWakeupTime()
			if self.alarmInProgress ~= 'rtc' then
				self:_stopTimer()
				self:_startTimer()
			end
		end
	end
end


-- if reconnection to server occurs (which it does automatically) then local alarm file stops playing
-- or gain gets cut to almost nothing due to a lower level squeezeplay bug
-- explicitly stop local alarm audio (since no audio is being emitted anyway) and restart asynchronously
-- instantiation is asynchronous to prevent gain (or other aspect of local audio) from being modified elsewhere after we've run...
-- last requestor wins
function _alarm_sledgehammerRearm(self, caller)
	local hammer = false
	
	local status = decode:status()
	--debug.dump(status)

	log:warn("*** Alarm: alarm_sledgehammerRearm: caller: ", caller, " alarmInProgress: ", self.alarmInProgress, " audioState: ", status.audioState)
	if self.alarmInProgress and self.alarmInProgress ~= 'snooze' and status.audioState ~= 1 then
		self.failedAudioTicker = self.failedAudioTicker + 1
		log:warn("*** Alarm: Audio failed! failedAudioTicker: ", self.failedAudioTicker)
	else
		self.failedAudioTicker = 0
		log:warn("*** Alarm: Audio ok -> reset failedAudioTicker: ", self.failedAudioTicker)
	end

	if self.failedAudioTicker > 5 then
		log:warn("*** Alarm: Decode state bad! failedAudioTicker: ", self.failedAudioTicker, " Trigger fallback alarm!")
		hammer = true
	end

	if hammer then 
		self:_stopTimer()
		-- kickstart audio output again, asynchronously, so whatever else is messing with the audio settings is hopefully finished
		log:warn("*** Alarm: alarm_sledgehammerRearm: Audio in bad shape while alarm is firing. Restart timer asynchronously at 1.5secs")
		self:_startTimer(1500)
	end
end


-- notification triggered invocation of the sledgehammer just speeds up transition to fallback alarm when said transition is required
-- (it also allows post-mortem analysis of the state transitions that have actually occurred for better evaluation of what SqueezeOS
--  is really doing behind the scenes)
-- polling would eventually manifest the transition anyway...

function notify_playerLoaded(self, player)
	if not player then
		return
	end
	if player == self.localPlayer then
		log:debug("*** Alarm: notify_playerLoaded: player: ", player)
--		self:_alarm_sledgehammerRearm('notify_playerLoaded')
		-- check for pending server alarm in case that one is pending instead, since we may have changed players to force 
		--       local control during a previous call to openAlarmWindow()
		if self.alarmInProgress == 'server' then
			log:warn("*** Alarm: notify_playerLoaded: called while `server` alarm in progress")
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


function notify_playerModeChange(self, player, mode)
	log:debug("*** Alarm: notify_playerModeChange: player: ", player, " mode: ", mode)
	if not player then
		return
	end
	if player == self.localPlayer then
		local status = decode:status()
		log:warn("*** Alarm: notify_playerModeChange: audioState: ", status.audioState)
	end
end


function notify_playerConnected(self, player)
	if not player then
		return
	end
	if player == self.localPlayer then
		log:warn("*** Alarm: notify_playerConnected: player: ", player, " alarmInProgress: ", self.alarmInProgress)
--		self:_alarm_sledgehammerRearm('notify_playerConnected')
		self.server = player:getSlimServer()
		log:warn("*** Alarm: notify_playerConnected: self.server: ", self.server)
	else
		log:debug("*** Alarm: notify_playerConnected: player: ", player, " localPlayer: ", self.localPlayer)
	end
end


function notify_playerDisconnected(self, player)
	if not player then
		return
	end
	if player == self.localPlayer then
		log:warn("*** Alarm: notify_playerDisconnected: player: ", player, " alarmInProgress: ", self.alarmInProgress)
	end
end


-- continue playing local alarm audio if this event occurs while a local alarm is already going off.
-- just allow manual user intervention to stop playout
-- in this case, alarmInProgress will be reset when next timer is set
function notify_serverConnected(self, server)
	-- go ahead and set self.localPlayer here
	self.localPlayer = Player:getLocalPlayer()

	log:info("*** Alarm: notify_serverConnected: server: ", server)

	if self.localPlayer then
		log:info("*** Alarm: Local player connection status is: ", self.localPlayer:isConnected())
	else
		log:info("*** Alarm: There is currently no self.localPlayer set")
	end

	-- don't want to cause error if no connection
	if self.localPlayer and self.localPlayer:isConnected() then
		log:info("*** Alarm: Local player->server is ", self.localPlayer:getSlimServer())
		if self.localPlayer:getSlimServer() == server then
			self:_alarm_sledgehammerRearm('notify_serverConnected')
		end
	end
end


function notify_serverDisconnected(self, server)
	log:info("*** Alarm: notify_serverDisconnected: server: ", server, " alarmInProgress: ", self.alarmInProgress)

	-- blindly check state here irrespective of which server caused this notification
	if self.alarmInProgress == 'snooze' or self.alarmInProgress == 'rtc' then
		log:warn("*** Alarm: Server disconnected, but no server alarm in progress -> we are good")
	elseif self.alarmInProgress == 'server' then
		if not self.localPlayer:isConnected() then
			log:warn("*** Alarm: Local player disconnected and server alarm -> Triggering RTC fallback alarm!")
			self:openAlarmWindow('rtc')
		else
			log:warn("*** Alarm: Server alarm in progress, but player still connected to ", self.localPlayer:getSlimServer())
		end
	else
		log:warn("*** Alarm: Server disconnceted, but no server alarm in progress")
	end
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


function _setWakeupTime(self, setting)
	if not setting then
		-- wakeup 3 minutes before alarm
		setting = self.alarmNext - 180
	end
	appletManager:callService("setWakeupAlarm", setting)
end


function _hideAlarmWindow(self)
	if self.alarmWindow then
		self.alarmWindow:hide()
		self.alarmWindow = nil
		self:_revertAudioEndpointOverride()
	end
end


function _pollDecodeState(self)
	local status = decode:status()
	if self.localPlayer:isConnected() then
		log:warn("*** Alarm: _pollDecodeState alarmInProgress: ", self.alarmInProgress, " audioState: ", status.audioState)
		log:warn("*** Alarm: localPlayer connected")
	else
		log:warn("*** Alarm: _pollDecodeState alarmInProgress: ", self.alarmInProgress, " audioState: ", status.audioState)
		log:warn("*** Alarm: localPlayer not connected")
	end

	self:_alarm_sledgehammerRearm('_pollDecodeState')	
end


function soundFallbackAlarm(self)
	log:warn("*** Alarm: soundFallbackAlarm()")
	self.alarmVolume = 0 -- start at 0 and fade in
	-- cache previous volume setting
	self.previousVolume = self.localPlayer:getVolume()
	self.localPlayer:volumeLocal(self.alarmVolume)
	self.localPlayer:stop(true)
	self.alarmInProgress = 'rtc'
	-- Bug 16100 - Sound comes from headphones although Radio is set to use speaker
	-- We need to set a valid alarm state for the fallback case
	self.localPlayer:setAlarmState("active_fallback")
	self.localPlayer:playFileInLoop(self.alarmTone)
	self.fadeInTimer = Timer(200, 
			function ()
				if self.alarmVolume < 43 then
					log:info("*** Alarm: fading in fallback alarmVolume: ", self.alarmVolume)
					self.alarmVolume = self.alarmVolume + 1
					self.localPlayer:volumeLocal(self.alarmVolume)
				else
					log:info("*** Alarm: stop self.alarmVolume at reasonable volume (43):", self.alarmVolume)
					self.fadeInTimer:stop()
				end
			end
	)
	self.fadeInTimer:start()

	local alarmTimeoutSeconds = self.localPlayer:getAlarmTimeoutSeconds() or ( 60 * 60 ) -- defaults to 1 hour
	if alarmTimeoutSeconds ~= 0 then
		local alarmTimeoutMsecs = alarmTimeoutSeconds * 1000
		log:info("*** Alarm: Fallback alarm will timeout in ", alarmTimeoutSeconds, " seconds")
		self.fallbackAlarmTimeout = Timer(alarmTimeoutMsecs,
				function ()
					if self.alarmInProgress == 'rtc' then
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
end


function openAlarmWindow(self, caller)

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

	log:warn("*** Alarm: openAlarmWindow: caller: ", caller, " local player connected: " , self.localPlayer:isConnected())

	-- Bug 16100 - Sound comes from headphones although Radio is set to use speaker
	-- Calling _alarmThroughSpeakers() here is too early for the fallback alarm
	--self:_alarmThroughSpeakers()

	-- if UI is controlling a different player, switch to the local player
	-- if notify_playerLoaded needs invocation prior to player change taking effect then refire openAlarmWindow() at that time
	local currentPlayer = Player:getCurrentPlayer()

	if currentPlayer ~= self.localPlayer then
		log:warn("*** Alarm: openAlarmWindow: switching squeezeplay control to local player: ", self.localPlayer, " from current player: ", currentPlayer)
		appletManager:callService("setCurrentPlayer", self.localPlayer)
		-- let notify_playerLoaded do its thing if we're not dealing with a fallback alarm
		-- originally was using notify_playerLoaded as Ben was in revision 8255, but unfortunately it also gets 
		-- called when not expected (as in when NOT switching players), so I removed to prevent multiple window problems
		-- probably need to make subsequent logic asynchronous to allow player to actually be switched/loaded, but no
		-- good options available for now since it appears notify_playerLoaded is called when least expected...
		--[[
		if not caller == 'rtc' then
			return
		end
		--]]
	end

	appletManager:callService("deactivateScreensaver")
	
	-- this method is called when the alarm time is hit
	-- when the alarm time is hit, unset the wakeup mcu time
	self:_setWakeupTime('none')

	self:_startDecodeStatePoller()

	if caller == 'server' then
		-- if we're connected, first drop the now playing window underneath the alarm window
		if self.localPlayer:isConnected() then
			appletManager:callService('goNowPlaying', Window.transitionPushLeft)
		end

		-- just informational stuff for now
		local status = decode:status()
		-- just informational
		log:warn("*** Alarm: openAlarmWindow: called with `server` - audioState: ", status.audioState)

		if self.alarmInProgress == 'rtc' then
			log:warn("*** Alarm: openAlarmWindow: called with `server` while RTC alarm in progress!")
			-- where did we come from?
			log:error("*** Alarm: CALL STACK TRAP: ")
		end

	elseif caller == 'rtc' then
		if self.alarmInProgress ~= 'rtc' then
			log:warn("*** Alarm: openAlarmWindow: fallback alarm activation")
		else
			log:warn("*** Alarm: openAlarmWindow: fallback alarm snooze or explicit audio cycle")			
		end

		self:soundFallbackAlarm()
		
	else
		log:error("*** Alarm: openAlarmWindow: unknown caller")
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

function _silenceFallbackAlarm(self)
	if not self.localPlayer then
		log:error("*** Alarm: No self.localPlayer found!")
		return
	end
	self.localPlayer:stop(true)
	if self.fadeInTimer and self.fadeInTimer:isRunning() then
		self.fadeInTimer:stop()
	end
	if self.previousVolume then
		log:warn("*** Alarm: setting player back to self.previousVolume: ", self.previousVolume)
		self.localPlayer:volumeLocal(self.previousVolume)
	end
	if self.fallbackAlarmTimeout and self.fallbackAlarmTimeout:isRunning() then
		log:warn("*** Alarm: stopping fallback alarm timeout timer")
		self.fallbackAlarmTimeout:stop()
	end
end


function _alarmOff(self, stopStream)
	if self.alarmInProgress == 'rtc' then
		self:_silenceFallbackAlarm()
		log:warn("*** Alarm: _alarmOff: RTC alarm canceled")
	else
		if self.localPlayer:isConnected() then
			log:warn("*** Alarm: _alarmOff: server alarm canceled - alarmInProgress: ", self.alarmInProgress)
		else
			log:warn("*** Alarm: _alarmOff: player not connected! - alarmInProgress: ", self.alarmInProgress)
		end
	end
	
	self.alarmInProgress = nil
	self:_stopTimer()
	self.alarmWindow:playSound("WINDOWHIDE")
	self:_hideAlarmWindow()
	
	self:_stopDecodeStatePoller()

	if self.localPlayer:isConnected() then
		log:warn("*** Alarm: _alarmOff: tell server alarm is off, and only pause if stopStream is true")
		self.localPlayer:stopAlarm(not stopStream)
	end

	if self.fallbackAlarmTimeout and self.fallbackAlarmTimeout:isRunning() then
		self.fallbackAlarmTimeout:stop()
	end

end


function _stopTimer(self)
	if self.RTCAlarmTimer:isRunning() then
		log:warn("*** Alarm: _stopTimer: stopping RTC fallback alarm timer")
		self.RTCAlarmTimer:stop()
		self.debugRTCTime = 0
	end
	if self.wakeOnLanTimer:isRunning() then
		log:warn("*** Alarm: _stopTimer: stopping WOL timer")
		self.wakeOnLanTimer:stop()
	end

	-- no RTC timer means no alarm, so let's go ahead and remove our alarm icon
	iconbar:setAlarm('OFF')
end


function _stopDecodeStatePoller(self)
	if self.decodeStatePoller and self.decodeStatePoller:isRunning() then
		log:warn("*** Alarm: stopping decodeStatePoller")
		self.decodeStatePoller:stop()
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


function _startTimer(self, interval)
	
	if not self.alarmNext and not interval then
		log:error("*** Alarm: both alarmNext and interval have no value!")
		return
	end

	if self.RTCAlarmTimer:isRunning() then
		self.RTCAlarmTimer:stop()
		self.debugRTCTime = 0
		log:warn("*** Alarm: _startTimer: stopping RTC fallback alarm timer")
	end
	
	if interval then
		log:warn("*** Alarm: _startTimer: starting RTC fallback alarm timer - interval: ", interval)
		self.RTCAlarmTimer:setInterval(interval)
		self.debugRTCTime = interval
	else
		-- get msecs between now and requested alarm
		interval = self:_deltaMsecs(self.alarmNext)

		-- add 20 secs for fallback timer to bias alarm toward server wakeup
		local rtcSleepMsecs = interval + 20000

		log:warn("*** Alarm: _startTimer: starting RTC fallback alarm timer - rtcSleepMsecs: ", rtcSleepMsecs)
		self.RTCAlarmTimer:setInterval(rtcSleepMsecs)
		self.debugRTCTime = rtcSleepMsecs

		-- restart the WOL timer for 5 minutes, or immediately send WOL if alarm is within 5 mins
		self:_wolTimerRestart(interval)

	end

	self.RTCAlarmTimer:start()
	iconbar:setAlarm('ON')
end


function _wolTimerRestart(self, msecsToAlarm)
	local wolLeadTime = 1000 * 60 * 5 -- 5 minutes
	if msecsToAlarm > wolLeadTime then
		self.wakeOnLanTimer:setInterval(msecsToAlarm - wolLeadTime)
		self.debugWOLTime = msecsToAlarm - wolLeadTime
		if self.wakeOnLanTimer:isRunning() then
			self.wakeOnLanTimer:restart()
		else
			self.wakeOnLanTimer:start()
		end
	-- if it's within 5 minutes, send a WOL packet as a best effort
	elseif self.server then
		log:warn("*** Alarm: _wolTimerRestart - Send WOL now!")
		self.debugWOLTime = 0
		self.server:wakeOnLan()
	end	
end


function _alarmSnooze(self)
	
	log:warn("*** Alarm: _alarmSnooze: alarmInProgress: ", self.alarmInProgress, " local player connected: ", self.localPlayer:isConnected())

	self:_stopTimer()

	log:warn("*** Alarm: _alarmSnooze: fallback alarm snoozing for ", alarmSnoozeSeconds, " + 20 seconds")
	local alarmSnoozeSeconds = self.localPlayer:getAlarmSnoozeSeconds()
	local fallbackAlarmMsecs = alarmSnoozeSeconds * 1000 + 20000 
	self.debugRTCTime = fallbackAlarmMsecs

	self:_startTimer(fallbackAlarmMsecs)
	self:_wolTimerRestart(alarmSnoozeSeconds * 1000)
	
	if self.alarmInProgress == 'rtc' then
		log:warn("*** Alarm: _alarmSnooze: stopping fallback alarm audio")
		-- stop playback
		self:_silenceFallbackAlarm()
	else
		self.alarmInProgress = 'snooze'
	end

	if self.localPlayer:isConnected() then
		log:warn("*** Alarm: _alarmSnooze: sending snooze command to connected server for connected local player ", self.localPlayer)
		self.localPlayer:snooze()
	end
	self:_stopDecodeStatePoller()

	self.alarmWindow:playSound("WINDOWHIDE")
	self:_hideAlarmWindow()
end


function free(self)
	self.alarmWindow = nil
	return false
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
