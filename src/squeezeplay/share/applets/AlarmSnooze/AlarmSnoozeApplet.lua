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
	self.localPlayer = Player:getLocalPlayer()
	self.server = self.localPlayer and self.localPlayer:getSlimServer()

	jnt:subscribe(self)
	self.alarmTone = "applets/AlarmSnooze/alarm.mp3"
	
	self.alarmInProgress = 'none';

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
				self:openAlarmWindow('rtc')
			end,
			true
	)
	self.wakeOnLanTimer = Timer(timeToAlarm,
			function()
				if self.server then
					log:warn('WOL packet being sent to ', self.server)
					self.server:wakeOnLan()
				end
			end,
			true
	)
	self.streamSuccessChecker = Timer(20000,
			function ()
				if self.alarmInProgress == 'server' and not self.localPlayer:isStreaming() then
					self:soundFallbackAlarm()
				end
			end,
			true
	)
	
	if startTimer then
		self:_startTimer()
	end

	self.debugDecodeState = true
	self.decodeStatePoller = Timer(10000, 
		function ()
			self:_pollDecodeState()
		end,
	false)
	
	return self
end


function notify_playerAlarmState(self, player, alarmState, alarmNext)

	if player:isLocal() then
		log:warn('**************************** notify_playerAlarmState received: ', alarmState, ' ', alarmNext)
		if alarmState == 'active' then
			if player ~= Player:getCurrentPlayer() then
				log:warn('alarm has fired locally, switching to local player')
                        	appletManager:callService("setCurrentPlayer", player)
			end

			-- ignore server alarm if an alarm is already in progress
			if self.alarmInProgress == 'rtc' then
				log:warn('ignoring alarm notification because fallback fired prior')
				return
			elseif self.alarmInProgress == 'server' then
				log:info('[likely post-snooze] alarm notification received while alarm already in progress')
			    -- keep going 
			end
            
			-- stop fallback timer and proceed
			self.alarmInProgress = 'server'

			self:_stopTimer()			
			self:_hideAlarmWindow()
			
			self:openAlarmWindow('server')

		elseif alarmState == 'snooze' then
		    
			log:warn('snooze state received')
			-- just leave state as in progress for now
			-- self.alarmInProgress = alarmState
			
		elseif alarmState == 'none' then
		
			if self.alarmInProgress ~= 'rtc' then
				self.alarmNext = false
				log:info('no alarm set, clearing settings')
				self:getSettings()['alarmNext'] = false
				self:storeSettings()
				self:_setWakeupTime('none')
				self.alarmInProgress = 'none'
		                -- might want to qualify whether or not to stop this timer dependent upon whether it's already running.
				-- for now just log the information
				if self.RTCAlarmTimer:isRunning() then
					log:warn('clear alarm directive received while RTC timer is running!  Stopping.  Careful now...')
				end
				if self.decodeStatePoller:isRunning() then
					self.decodeStatePoller:stop()
				end
				self:_stopTimer()
			else
				log:warn('clear alarm directive received while fallback alarm in progress!  ignoring')
				return
			end
		elseif alarmState == 'set' then
			
			log:warn('an upcoming alarm is set, but none is currently active')
			if self.decodeStatePoller:isRunning() then
				self.decodeStatePoller:stop()
			end
		end
		
		-- store alarmNext data as epoch seconds
		if alarmNext and alarmNext > 0 then

			log:debug('notify_playerAlarmState: ALARMNEXT is ', alarmNext,' : NOW is ', os.time())
		
			-- want to know if this happens
			if alarmState == 'active' then
			    log:error('notify_playerAlarmState: alarmNext is ', alarmNext, '  while alarmState is ACTIVE!  ignoring...')
				return
			end
			
			self.alarmNext = alarmNext
			
			log:info('storing epochseconds of next alarm:  ', alarmNext)
		        self:getSettings()['alarmNext'] = alarmNext
			
			self:storeSettings()
			self:_setWakeupTime()
			self:_stopTimer()
			self:_startTimer()
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
	
	if self.alarmInProgress == 'server' then
		local status = decode:status()
		-- just informational
		log:warn('alarm_sledgehammerRearm(', caller,'): SERVER alarm in progress - decodeState is ', status.decodeState, ' and streaming is ', self.localPlayer:isStreaming())
		
		if not self.localPlayer:isStreaming() then
			log:warn('alarm_sledgehammerRearm(', caller,'): SERVER alarm in progress, but stream is nil - firing fallback alarm')
			hammer = true
		end
	-- restart audio on any state transition from SqueezeOS, but not on local polls	
	elseif self.alarmInProgress == 'rtc' and caller ~= '_pollDecodeState' then
		log:warn('alarm_sledgehammerRearm(', caller,'): RTC alarm already in progress - restarting alarm audio asynchronously')
		hammer = true
	end
       
	if hammer then 
		-- immediately set volume back where it was
		log:warn('alarm_sledgehammerRearm: local volume is ', self.localPlayer:getVolume())
		--localPlayer:volumeLocal(43);
		
		-- let some time pass so whatever is messing with the player settings underneath finishes (last request to play wins!)
		-- self:openAlarmWindow('rtc')

		self:_stopTimer()
		-- kickstart audio output again, asynchronously, so whatever else is messing with the audio settings is hopefully finished
		self:_startTimer(1500)
	end
end


-- notification triggered invocation of the sledgehammer just speeds up transition to fallback alarm when said transition is required
-- (it also allows post-mortem analysis of the state transitions that have actually occurred for better evaluation of what SqueezeOS
--  is really doing behind the scenes)
-- polling would eventually manifest the transition anyway...

function notify_playerLoaded(self, player)
	if player == self.localPlayer then
		log:info("notify_playerLoaded(", player, ")")
--		self:_alarm_sledgehammerRearm('notify_playerLoaded')
		-- check for pending server alarm in case that one is pending instead, since we may have changed players to force 
		--       local control during a previous call to openAlarmWindow()
		if self.alarmInProgress == 'server' then
			log:warn("notify_playerLoaded: called while `server` alarm in progress")
		end
	end
end


function notify_playerCurrent(self, player)
	if player == self.localPlayer then
		log:info("notify_playerCurrent(", player, ")")
--		self:_alarm_sledgehammerRearm('notify_playerCurrent')
	end
end


function notify_playerModeChange(self, player, mode)
	if player == self.localPlayer then
		log:warn('notify_playerModeChange: player (', player,') mode has been changed to ', mode)
		local status = decode:status()
		log:warn('notify_playerModeChange: - decodeState is ', status.decodeState,' and streaming is ', self.localPlayer:isStreaming())
	end
end


function notify_playerConnected(self, player)
	if player == self.localPlayer then
		log:warn('notify_playerConnected: ', player, ' ', self.alarmInProgress)
--		self:_alarm_sledgehammerRearm('notify_playerConnected')
	end
end


function notify_playerDisconnected(self, player)
	if player == self.localPlayer then
		log:warn('notify_playerDisconnected ', player, self.alarmInProgress)
	end
end


-- continue playing local alarm audio if this event occurs while a local alarm is already going off.
-- just allow manual user intervention to stop playout
-- in this case, alarmInProgress will be reset when next timer is set
function notify_serverConnected(self, server)
	-- go ahead and set self.localPlayer here
	self.localPlayer = Player:getLocalPlayer()

	log:info('notify_serverConnected: ', server, ' is now connected')

	-- self.server is used for WOL purposes
	self.server = server

	if self.localPlayer then
		log:info('local player connection status is ', self.localPlayer:isConnected())
	else
		log:info('there is currently no self.localPlayer set')
	end

	-- don't want to cause error if no connection
	if self.localPlayer and self.localPlayer:isConnected() then
		log:info('                      local player->server is ', self.localPlayer:getSlimServer())
	end
    
--	self:_alarm_sledgehammerRearm('notify_serverConnected')
end


function notify_serverDisconnected(self, server)
	log:info('notify_serverDisconnected: ', server, ' is now disconnected')

	-- blindly check state here irrespective of which server caused this notification
	if self.alarmInProgress ~= 'none' and self.alarmInProgress ~= 'rtc' then
		if not self.localPlayer:isConnected() then
			log:warn('notify_serverDisconnected: ', server, ' - while server alarm in progress! state ', self.alarmInProgress, ' triggering fallback alarm!')
			self:openAlarmWindow('rtc')
		else
			log:warn('notify_serverDisconnected: ', server, ' - server alarm in progress, but player still connected to ', self.localPlayer:getSlimServer())
		end
	else
		log:warn('notify_serverDisconnected: ', server, ' - disconnected, but no server alarm in progress : ', self.alarmInProgress)
	end
end


-- returns the millisecond delta between now (current time) and the epochsecs parameter
-- returns default of 1000ms if epochsecs is in the past...
function _deltaMsecs(self, epochsecs)

	local deltaSecs = epochsecs - os.time() 
	if deltaSecs <= 0 then
		log:warn('_deltaMsecs: epochsecs is in the past, deltaSecs is ', delta)
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
	end
end


function _pollDecodeState(self)
	local status = decode:status()
	if self.localPlayer:isConnected() then
		log:warn('_pollDecodeState(',self.alarmInProgress,'): decodeState is ', status.decodeState, ' and streaming is ', self.localPlayer:isStreaming())
	else
		log:warn('_pollDecodeState(',self.alarmInProgress,'): decodeState is ', status.decodeState, ' and no current player')
	end

	self:_alarm_sledgehammerRearm('_pollDecodeState')	
end


function soundFallbackAlarm(self)
	log:warn("soundFallbackAlarm()")
	self.localPlayer:volumeLocal(43)
	self.localPlayer:stop(true)
	self.alarmInProgress = 'rtc'
	self.localPlayer:playFileInLoop(self.alarmTone)
end

function openAlarmWindow(self, caller)

	log:warn('openAlarmWindow()', caller, ' ', self.localPlayer:isConnected())

	-- if radio is controlling a different player, switch to the local player
	-- if notify_playerLoaded needs invocation prior to player change taking effect then refire openAlarmWindow() at that time
	local currentPlayer = Player:getCurrentPlayer()

	if currentPlayer ~= self.localPlayer then
		log:warn('openAlarmWindow: switching squeezeplay control to local player (', self.localPlayer,') from (', currentPlayer,')')
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

	if caller == 'server' then
		-- if we're connected, first drop the now playing window underneath the alarm window
		if self.localPlayer:isConnected() then
			appletManager:callService('goNowPlaying', Window.transitionPushLeft)
		end

		-- just informational stuff for now
		local status = decode:status()
		-- just informational
		log:warn('openAlarmWindow: called with `server` - decodeState is ', status.decodeState, ' and streaming is ', self.localPlayer:isStreaming())

		if self.alarmInProgress == 'rtc' then
			log:warn('openAlarmWindow: called with `server` while `rtc` alarm in progress!')
			-- where did we come from?
			log:error('CALL STACK TRAP: ')
		end
		
		if self.debugDecodeState then
			if self.decodeStatePoller:isRunning() then
				self.decodeStatePoller:restart()
			else
				self.decodeStatePoller:start()
			end
		end

		if not self.localPlayer:isStreaming() then
			-- check in 20 secs if we are streaming anything, and if not, fire fallback alarm
			-- this used to be done server-side, but that has been removed
			log:info('openAlarmWindow: starting stream success check timer. in 20 seconds if alarm is still active and stream has failed, client-side fallback alarm will be fired')
			self.streamSuccessChecker:start()
		end


	elseif caller == 'rtc' then
		if self.alarmInProgress ~= 'rtc' then
			log:warn('openAlarmWindow: fallback alarm activation')
		else
			log:warn('openAlarmWindow: fallback alarm snooze or explicit audio cycle')			
		end
		if not self.localPlayer then
			log:warn('openAlarmWindow: cannot play an alarm without a player')
			return
		end

		self:soundFallbackAlarm()
		
	else
		log:error('openAlarmWindow: unknown caller')
	end
	
	if self.alarmWindow then
		return
	end

	local window = Window('alarm_popup', self:string('ALARM_SNOOZE_ALARM'))

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
		self:_hideAlarmWindow()
		return EVENT_CONSUME
	end

	local hideWindowAction = function()
		window:playSound("WINDOWHIDE")
		self:_alarmOff()
		return EVENT_UNUSED
	end

	local offAction = function()
		self:_alarmOff()
		return EVENT_UNUSED
	end
	
	local snoozeAction = function()
		self:_alarmSnooze()
		return EVENT_CONSUME
	end

	menu:addActionListener("back", self, cancelAction)
	menu:addActionListener("power", self, offAction)
	menu:addActionListener("mute", self, snoozeAction)

	window:ignoreAllInputExcept({ 'go', 'back', 'power', 'mute' }, hideWindowAction)

	menu:setHeaderWidget(headerGroup)

        -- the alarm notification window should not endure forever; hide after 59 seconds
        window:addTimer(59000, function() self:_hideAlarmWindow() end)

	window:addWidget(menu)
	window:setShowFrameworkWidgets(false)
	window:setAllowScreensaver(false)
	window:show(Window.transitionFadeIn)

	-- If the window leaves the screen through any means, self.alarmInProgress gets set to none, fallback alarm audio gets stopped, decodeStatePoller gets stopped
        window:addListener(EVENT_WINDOW_POP,
                function()
			if self.alarmInProgress == 'rtc' then
				self.localPlayer:stop(true)
				iconbar:setAlarm('OFF')
				log:warn('_alarmOff: RTC alarm canceled')
			end
			if self.decodeStatePoller:isRunning() then
				self.decodeStatePoller:stop()
			end
                        self.alarmInProgress = 'none'
			self.alarmWindow = nil
                end
        )

	self.alarmWindow = window
end


function _alarmOff(self)
	if self.alarmInProgress == 'rtc' then
		self.localPlayer:stop(true)
		iconbar:setAlarm('OFF')
		log:warn('_alarmOff: RTC alarm canceled')
	else
		if self.localPlayer:isConnected() then
			log:warn('_alarmOff: server alarm canceled - alarmInProgress state (', self.alarmInProgress, ')')
		else
			log:warn('_alarmOff: player not connected! - alarmInProgress state (', self.alarmInProgress, ')')
		end
	end
	
	self.alarmInProgress = 'none'
	self:_stopTimer()
	self.alarmWindow:playSound("WINDOWHIDE")
	self:_hideAlarmWindow()
	
	if self.decodeStatePoller:isRunning() then
		self.decodeStatePoller:stop()
	end

	if self.localPlayer:isConnected() then
		self.localPlayer:stopAlarm()
	end
end


function _stopTimer(self)
	if self.RTCAlarmTimer:isRunning() then
		log:warn('_stopTimer: stopping RTC fallback alarm timer')
		self.RTCAlarmTimer:stop()
	end
	if self.wakeOnLanTimer:isRunning() then
		log:warn('_stopTimer: stopping WOL timer')
		self.wakeOnLanTimer:stop()
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
	
	if not self.alarmNext and not interval then
		log:error('both alarmNext and interval have no value!')	
		return
	end

	if self.RTCAlarmTimer:isRunning() then
		self.RTCAlarmTimer:stop()
		log:warn('_startTimer: stopping RTC fallback alarm timer')
	end
	
	if interval then
		log:warn('starting RTC fallback alarm timer for interval ', interval)
		self.RTCAlarmTimer:setInterval(interval)
	else
		-- get msecs between now and requested alarm
		-- add 10 secs for fallback timer to bias alarm toward server wakeup
		local sleepMsecs = self:_deltaMsecs(self.alarmNext + 10);
		log:warn('_startTimer: starting RTC fallback alarm timer (', sleepMsecs, ')')
		self.RTCAlarmTimer:setInterval(sleepMsecs)

		-- WOL timer is set when sleepMsecs is more than 11 minutes away (660,000 msecs)
		if sleepMsecs > 660000 then
			self.wakeOnLanTimer:setInterval(sleepMsecs - 600000)
			if self.wakeOnLanTimer:isRunning() then
				self.wakeOnLanTimer:restart()
			else
				self.wakeOnLanTimer:start()
			end
		end
	end
	self.RTCAlarmTimer:start()
end


function _alarmSnooze(self)
	
	log:warn('_alarmSnooze: alarmInProgress is ', self.alarmInProgress, ' : connection status is ', self.localPlayer:isConnected())
	
	if self.alarmInProgress == 'rtc' then
		-- stop playback
		self.localPlayer:stop(true)
		log:warn('_alarmSnooze: fallback alarm snoozing for hardwired 9 minutes')
		self:_stopTimer()
		-- start another hardwired timer for 9 minutes
		--self:_startTimer(60000)	
		self:_startTimer(540000)
	else
		if self.localPlayer:isConnected() then
			self.localPlayer:snooze()
		else
			-- playerDisconnect event should be hit first, but for completeness... 
			log:warn('_alarmSnooze: lost connection after server alarm notification!  triggering fallback alarm')
			self:openAlarmWindow('rtc')
		end
	end

	self.alarmWindow:playSound("WINDOWHIDE")
	self:_hideAlarmWindow()
end


function free(self)
	self.alarmWindow = nil
	return false
end
