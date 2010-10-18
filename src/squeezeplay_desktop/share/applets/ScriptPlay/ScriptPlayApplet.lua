local assert, loadfile, ipairs, package, pairs, require, tostring, type, tonumber = assert, loadfile, ipairs, package, pairs, require,tostring, type, tonumber

local oo               = require("loop.simple")
local io               = require("io")
local os               = require("os")
local lfs              = require("lfs")
local string           = require("string")
local math             = require("math")

local Applet           = require("jive.Applet")
local Framework        = require("jive.ui.Framework")
local System           = require("jive.System")
local Player           = require("jive.slim.Player")
local macro            = require("applets.MacroPlay.MacroPlayApplet")

local jive = jive
local jnt  = jnt

module(..., Framework.constants)
oo.class(_M, Applet)


function init(self)
	math.randomseed(Framework:getTicks())
	self.timerAction = nil
	self.player = Player:getCurrentPlayer()
	if self.player then
		self.isPlaying = self.player:getPlayerMode() == 'play'
	end
	jnt:subscribe(self)
	self.running = false
	
	self.macAddress = System:getMacAddress()
	
	local offset = os.getenv("LOADTEST_TIME_OFFSET")
	if offset ~= nil and tonumber(offset) > 0 then
		self.timeOffset = tonumber(offset)
	end
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

function loadConfig(self, file)
	-- Load macro configuration
	local f, dirorerr = loadconfigfile(file)
	if f then
		self.config = f()
		log:info(self.macAddress, ': ',"Loaded config from ", dirorerr, file)
	elseif dirorerr then
		log:warn(self.macAddress, ': ',"Error loading config from ", file, ": ", dirorerr)
	else
		log:warn(self.macAddress, ': ',"No config file found: ", file)
	end
	return f ~= nil
end


function isRunning(self)
	return self.running
end

function notify_playerModeChange(self, player, mode)
	if player ~= self.player then return end

	log:info(self.macAddress, ': ','mode=', mode)
		
	self.isPlaying = mode == 'play'
	if not self.isPlaying and self.timerAction then
		self.interupt = true
		macro.macroDelay(1)
	end
end

function notify_playerCurrent(self, player)
	self.player = player
	self.isPlaying = player:getPlayerMode() == 'play'
	log:info(self.macAddress, ': ','player=', player)
end

function _play(self, track)
	log:info(self.macAddress, ': ','_play: track=', track or 'undef')
	
	-- go home
	macro.macroHome(500, 10000)	-- long delay to allow for startup
	
	if not macro.macroSelectMenuId(100, "favorites") then
		macro.macro_fail("favorites")
		self.running = false
		return
	end
	macro.macroAction(10000, 'go') -- long delay as may need to connect
	
	-- select station
	if not macro.macroSelectMenuIndex(100, track) then
		macro.macro_fail("Track " .. track)
		self.running = false
		return
	end
	macro.macroAction(1000, 'go')
end

function _getTrackId(self)
	local r = math.random()
	local i, v, s = nil, nil, 0
	for i, v in ipairs(self.config.trackWeights) do
		s = s + v
		if r < s then return i end
	end
	return i
end

function _nextRecord(self)
	self.config.currentTrackRecord = self.config.currentTrackRecord + 1
	if self.config.currentTrackRecord > #self.config.record then return nil, nil end
	return self.config.record[self.config.currentTrackRecord][1], self.config.record[self.config.currentTrackRecord][2]
end

function _new_getNextTrack(self)
	local t = os.date("!*t")
	local secondsSinceMidnight = t.sec + t.min * 60 + t.hour * 3600
	
	if self.timeOffset then
		secondsSinceMidnight = (secondsSinceMidnight + self.timeOffset) % (3600 * 24)
	end
	
	local ticsOffset = Framework:getTicks() / 1000 - secondsSinceMidnight
	
	local start, duration, pstart, pduration
	if self.config.currentTrackRecord == nil then
		-- find first track
		self.config.currentTrackRecord = 0
		repeat
			pstart, pduration =  start, duration
			start, duration = self:_nextRecord()
		until start == nil or start > secondsSinceMidnight
		
		-- if the next track is some time on the future and the
		-- previous stations would still have been playing
		-- then use the previous track (adjusted)
		if ((start == nil or start - secondsSinceMidnight > 600) and pstart ~= nil
			and (pstart + pduration > secondsSinceMidnight)) then
			duration = pduration - (pstart - secondsSinceMidnight)
			start = secondsSinceMidnight
		end
		
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

function _getNextTrack(self)
	trackNum = (trackNum + 1) % 3
	local now = Framework:getTicks()
	return now + 10000, now + 120000, trackNum + 1
end

function _waitToFinish(self, endTime)
	local duration = endTime - Framework:getTicks()

	log:info(self.macAddress, ': ','_waitToFinish: duration=', duration)

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

function _checkPlaying(self, endTime)
	local duration = endTime - Framework:getTicks()

	log:info(self.macAddress, ': ','_checkPlaying: duration=', duration)

	if duration > 60000 then
		macro.macroDelay(60000)
		self.timerAction = function(self, interrupt)
								self.timerAction = nil
								if self.isPlaying then
									self:_waitToFinish(endTime)
								elseif interrupt then
									self:_checkPlaying(endTime)
								else
									log:warn(self.macAddress, ': ','Track not playing');
									self.running = false
								end
							end
	else
		self:_waitToFinish(endTime)
	end
end

function runScript(self, configFile)
	if not self:loadConfig(configFile) then return end
	
	-- Pick a random record to use
	if self.config.records and #self.config.records > 0 then
		local index = math.random(#self.config.records)
		self.config.record = self.config.records[index]
		self.config.records = nil
		log:info(self.macAddress, ': ','Using test record #', index, ' entries=', #self.config.record)
	end
	
	self.running = true
	
	self:playTrack(nil)
	
	while self.running do
		local interrupt = self.interrupt
		self.interrupt = false
		self.timerAction(self, interrupt)
	end
end

function playTrack(self, start, endTime, track)
	
	if start == nil then
		start, endTime, track = self:_new_getNextTrack()
	end
	
	local startIn = start - Framework:getTicks()
	
	if not self.player and startIn <= 0 then
		startIn = 10000
	end
	
	log:info(self.macAddress, ': ','playTrack: startIn=', startIn, ', track=', track)

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
									if self.running then
										self:_checkPlaying(endTime)
									end
								end
							end
	else
		self:_play(track)
		if self.running then
			self:_checkPlaying(endTime)
		end
		self:_checkPlaying(endTime)
	end
end

