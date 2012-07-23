-- local appletManager    = macroRequire("jive.AppletManager")
local require    = macroRequire

-- appletManager:callService("runScript", "PlayRadioMacro.config")

local assert, loadfile, ipairs, package, pairs, require, tostring, type = assert, loadfile, ipairs, package, pairs, require,tostring, type

local oo               = require("loop.simple")
local io               = require("io")
local os               = require("os")
local lfs              = require("lfs")
local string           = require("string")
local math             = require("math")

local Applet           = require("jive.Applet")
local Framework        = require("jive.ui.Framework")
local Player           = require("jive.slim.Player")
local macro            = require("applets.MacroPlay.MacroPlayApplet")

local jive = jive

-- module(..., Framework.constants)
-- oo.class(_M, Applet)

local script = {}

function scriptInit(self)
	self.timerAction = nil
	self.player = Player:getCurrentPlayer()
	if self.player then
		self.isPlaying = self.player:getPlayerMode() == 'play'
	end
	-- jnt:subscribe(self)
	self.running = false
end

local function loadconfigfile(file)
	for dir in package.path:gmatch("([^;]*)%?[^;]*;") do
		local filepath = dir .. file

		if lfs.attributes(filepath, "mode") == "file" then
			local f, err = loadfile(filepath)
			if err == nil then
				-- Set chunk environment to be contained in the
				return f, string.match(filepath, "(.*[/\]).+")
			else
				return nil, err
			end
		end
	end

	return nil
end

function script.loadScriptConfig(self, file)
	-- Load macro configuration
	local f, dirorerr = loadconfigfile(file)
	if f then
		self.config = f()
		log:info("Loaded config from ", dirorerr, file)
	elseif dirorerr then
		log:warn("Error loading config from ", file, ": ", dirorerr)
	else
		log:warn("No config file found: ", file)
	end
	return f ~= nil
end


function script.isRunning(self)
	return self.running
end

function script.notify_playerModeChange(self, player, mode)
	if player ~= self.player then return end

	log:info('mode=', mode)
		
	self.isPlaying = mode == 'play'
	if not self.isPlaying and self.timerAction then
		self.interupt = true
		macro.macroDelay(1)
	end
end

function script.notify_playerCurrent(self, player)
	self.player = player
	self.isPlaying = player:getPlayerMode() == 'play'
	log:info('player=', player)
end

function script._play(self, track)
	log:info('_play: track=', track or 'undef')
	
	-- go home
	macro.macroHome(500)
	
	-- select Internet Radio
	if not macro.macroSelectMenuItem(100, "Internet Radio") then
		macro.macro_fail("Internet Radio")
		self.running = false
		return
	end
	macro.macroAction(1000, 'go')
	
	-- select Staff Picks
	if not macro.macroSelectMenuItem(100, "Staff Picks") then
		macro.macro_fail("Staff Picks")
		self.running = false
		return
	end
	macro.macroAction(1000, 'go')
	
	-- select Andy's Picks
	if not macro.macroSelectMenuItem(100, "Andy's Picks") then
		macro.macro_fail("Andy's Picks")
		self.running = false
		return
	end
	macro.macroAction(1000, 'go')
	
	track = (track - 1) % 3 + 1
	
	-- select Radio Paradise
	if not macro.macroSelectMenuIndex(100, track) then
		macro.macro_fail("Track " .. track)
		self.running = false
		return
	end
	macro.macroAction(1000, 'go')
end

function script._getTrackId(self)
	local r = math.random()
	local i, v, s = nil, nil, 0
	for i, v in ipairs(self.config.trackWeights) do
		s = s + v
		if r < s then return i end
	end
	return i
end

function script._nextRecord(self)
	self.config.currentTrackRecord = self.config.currentTrackRecord + 1
	if self.config.currentTrackRecord > #self.config.record then return nil, nil end
	return self.config.record[self.config.currentTrackRecord][1], self.config.record[self.config.currentTrackRecord][2]
end

function script._new_getNextTrack(self)
	local t = os.date("!*t")
	local secondsSinceMidnight = t.sec + t.min * 60 + t.hour * 3600
	local ticsOffset = Framework:getTicks() / 1000 - secondsSinceMidnight
	
	local start, duration
	if self.config.currentTrackRecord == nil then
		-- find first track
		self.config.currentTrackRecord = 0
		repeat 
			start, duration = self:_nextRecord()
		until start == nil or start > secondsSinceMidnight
	else
		start, duration = self:_nextRecord()
	end

	if start == nil then
		-- use first track for tomorrow
		self.config.currentTrackRecord = 0
		start, duration = self:_nextRecord()
		start = start + 24 * 60 * 60
	end
	
	return (start + ticsOffset) * 1000, (start + ticsOffset + duration) * 1000, self:_getTrackId()
end

local trackNum = 0

function script._getNextTrack(self)
	trackNum = (trackNum + 1) % 3
	local now = Framework:getTicks()
	return now + 10000, now + 120000, trackNum + 1
end

function script._waitToFinish(self, endTime)
	local duration = endTime - Framework:getTicks()

	log:info('_waitToFinish: duration=', duration)

	if duration > 0 then
		macro.macroDelay(duration)
		self.timerAction = function(self, interrupt)
								self.timerAction = nil
								if (interrupt) then
									self:_checkPlaying(endTime)
								else
									self:playTrack(nil)
								end
							end
	else
		self:playTrack(nil)
	end
end

function script._checkPlaying(self, endTime)
	local duration = endTime - Framework:getTicks()

	log:info('_checkPlaying: duration=', duration)

	if duration > 60000 then
		macro.macroDelay(60000)
		self.timerAction = function(self, interrupt)
								self.timerAction = nil
								if self.isPlaying then
									self:_waitToFinish(endTime)
								elseif interrupt then
									self:_checkPlaying(endTime)
								else
									log:warn('Track not playing');
									self.running = false
								end
							end
	else
		self:_waitToFinish(endTime)
	end
end

function script.runScript(self, configFile)
	if not self:loadScriptConfig(configFile) then return end
	
	self.running = true
	
	self:playTrack(nil)
	
	while self.running do
		local interrupt = self.interrupt
		self.interrupt = false
		self.timerAction(self, interrupt)
	end
end

function script.playTrack(self, start, endTime, track)
	
	if start == nil then
		start, endTime, track = self:_new_getNextTrack()
	end
	
	local startIn = start - Framework:getTicks()
	
	if not self.player and startIn <= 0 then
		startIn = 10000
	end
	
	log:info('playTrack: startIn=', startIn, ', track=', track)

	if (startIn > 0) then
		if (self.isPlaying and startIn > 5000) then
			self.player:pause()
		end
		macro.macroDelay(startIn)
		self.timerAction = function(self, interrupt)
								self.timerAction = nil
								if interrupt or not self.player then
									self:playTrack(start, endTime, track)
								else
									self:_play(track)
									self:_checkPlaying(endTime)
								end
							end
	else
		self:_play(track)
		self:_checkPlaying(endTime)
	end
end

scriptInit(script)
script:runScript("PlayRadioMacro.config")

