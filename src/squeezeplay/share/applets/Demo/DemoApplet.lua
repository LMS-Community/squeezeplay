
-- stuff we use
local ipairs, pairs, setmetatable, tostring, tonumber  = ipairs, pairs, setmetatable, tostring, tonumber

local oo            = require("loop.simple")
local lfs           = require("lfs")
local math          = require("math")
local string        = require("jive.utils.string")
local table         = require("jive.utils.table")
local os            = require("os")
local Applet        = require("jive.Applet")
local System        = require("jive.System")
local SlimServer    = require("jive.slim.SlimServer")
local LocalPlayer   = require("jive.slim.LocalPlayer")
local Font			= require("jive.ui.Font")
local decode        = require("squeezeplay.decode")


local Surface       = require("jive.ui.Surface")
local Framework     = require("jive.ui.Framework")
local Checkbox      = require("jive.ui.Checkbox")
local Label         = require("jive.ui.Label")
local SimpleMenu    = require("jive.ui.SimpleMenu")
local Window        = require("jive.ui.Window")
local Textarea      = require("jive.ui.Textarea")
local Textinput     = require("jive.ui.Textinput")
local Slider        = require("jive.ui.Slider")
local Keyboard      = require("jive.ui.Keyboard")
local Group         = require("jive.ui.Group")
local Popup         = require("jive.ui.Popup")
local Icon          = require("jive.ui.Icon")
local Timer         = require("jive.ui.Timer")

local SlimProto     = require("jive.net.SlimProto")
local Playback      = require("jive.audio.Playback")

local debug         = require("jive.utils.debug")

local jnt           = jnt
local jiveMain      = jiveMain
local appletManager = appletManager


module(..., Framework.constants)
oo.class(_M, Applet)

local VOLUME_STEP = 1
local FONT_SIZE = 18
-- volumeMap has the correct gain settings for volume settings 1-100. Based on Boom volume curve
local volumeMap = {
16, 18, 22, 26, 31, 36, 43, 51, 61, 72, 85, 101, 120, 142, 168, 200, 237, 281, 333, 395, 468, 555, 658, 781, 926, 980, 1037, 1098, 1162, 1230, 1302, 1378, 1458, 1543, 1634, 1729, 1830, 1937, 2050, 2048, 2304, 2304, 2560, 2816, 2816, 3072, 3328, 3328, 3584, 3840, 4096, 4352, 4608, 4864, 5120, 5376, 5632, 6144, 6400, 6656, 7168, 7680, 7936, 8448, 8960, 9472, 9984, 10752, 11264, 12032, 12544, 13312, 14080, 14848, 15872, 16640, 17664, 18688, 19968, 20992, 22272, 23552, 24832, 26368, 27904, 29696, 31232, 33024, 35072, 37120, 39424, 41728, 44032, 46592, 49408, 52224, 55296, 58624, 61952, 65536,
}

function init(self)

	self.delta = 0
	self.volume = 51

	self.volumePrefSaver = Timer(
		60000,
		function()
			_saveVolPref(self)
		end
	)
	self.autoMuteTimer = Timer(
		90000,
		function()
			_autoMuteAdjust(self)
		end
	)

	return self
end

function _autoMuteAdjust(self)
	if self.volume > 0 then
		log:warn('idle timeout, setting the volume to 0')
		log:debug('self.volume is: ', self.volume)
		if self.localPlayer then
			self.volume = self.localPlayer:getVolume()
		end
		log:debug('self.volume is: ', self.volume)
		self.audioMute = true
		self.localPlayer:volumeLocal(0)
	end
	self.autoMuteTimer:stop()
end

function _saveVolPref(self)
	local currentSetting = self:getSettings()['volumeSetting']
	if currentSetting != self.volume then
		log:info('saving volume pref for demo to: ', self.volume)
		self:getSettings()['volumeSetting'] = self.volume
		self:storeSettings()
	end	
end



function _windowListeners(self, window)
	local retEventStatus = EVENT_CONSUME
	window:addListener(EVENT_KEY_ALL | EVENT_SCROLL, function(event)
	if event:getType() == EVENT_KEY_LONGHOLD then
	--since there is only one long hold key for exit demo
		log:debug("recieved event longhold")
		retEventStatus = EVENT_UNUSED
	end
	if event:getType() == EVENT_KEY_PRESS  then
		local keycode = event:getKeycode()
		if (keycode & (KEY_VOLUME_UP|KEY_VOLUME_DOWN) ~= 0) and System:hasVolumeKnob() then
			log:debug("event volume received and sending to volume applet")
			retEventStatus =  EVENT_UNUSED
		end
		--Handle Volume knob
	end
	if self.audioMute ~= nil then
		log:debug('self.volume is: ', self.volume)
		if self.localPlayer then
			self.localPlayer:volumeLocal(self.volume)
		end
		self.audioMute = nil
	end
	--start the automute timer
	if self.autoMuteTimer:isRunning() then
		self.autoMuteTimer:restart()
	else
		self.autoMuteTimer:start()
	end
	return retEventStatus
	end)
	window:addActionListener('soft_reset', self, function() return EVENT_CONSUME end)
	window:addActionListener('exit_demo', self, demoEvent)
end


function demoEvent(self, demoEvent)
	-- add setting not to start demo on boot
	log:debug("event recieved as ", demoEvent:getType())
	self:getSettings()['volumeSetting'] = 51
	self:getSettings()['startDemo'] = false
	self:storeSettings()
	self.localPlayer:stop(true)
	self.nextSlideTimer:stop()
	_rebootBox()
	return EVENT_CONSUME 
end


function _rebootBox(self)
	-- we're shutting down, so prohibit any key presses or holds
	Framework:addListener(EVENT_ALL_INPUT,
				function ()
				return EVENT_CONSUME
				end,
				true)
	log:info("Rebooting...")
	--reboot
	appletManager:callService("reboot")
end
					
-- main setting menu
function enableDemo(self)
	-- keyboard window to enter code
	self.window = Window('text_list', self:string("DEMO_ENTER_CODE"))
	local input = Textinput("textinput", "",
		function(_, value)
			self.code = value
			self.window:playSound("WINDOWSHOW")
			confirmDemo(self)
			return true
		end, 
		'0123456789')
	local keyboard = Keyboard("keyboard", 'ip', input)
	local backspace = Keyboard.backspace()
	local group = Group('keyboard_textinput', { textinput = input, backspace = backspace } )

	self.window:addWidget(group)
	self.window:addWidget(keyboard)
	self.window:focusWidget(group)
	self.window:show()
end

function jumpToInStoreDemo(self)
	confirmDemo(self, true)
end

function confirmDemo(self, force)

	-- the code is '1234'
	if tonumber(self.code) == 1234 or force == true then
		local window = Window("text_list", self:string("DEMO_START_DEMO"))
		local menu = SimpleMenu("menu", items)
		menu:setComparator(SimpleMenu.itemComparatorWeightAlpha)
		local textArea = Textarea('help_text', self:string('DEMO_START_DEMO_WARNING'))
		menu:setHeaderWidget(textArea)
		window:addWidget(menu)
	
		menu:addItem({
			text = self:string("DEMO_START_DEMO"),
			sound = "WINDOWSHOW",
			weight = 2,
			callback = function(event, menuItem)
				-- add setting to immediately start demo on boot
				self:getSettings()['startDemo'] = true
				self:storeSettings()

				self:startDemo()
			end,
		})


		self:tieAndShowWindow(window)
	else
		local window = Window("information", self:string("DEMO_ERROR"))
		local textarea = Textarea('text', self:string('DEMO_WRONG_CODE'))
		window:addWidget(textarea)
		window:show()
		return
	end
end

function startDemo(self)

	self.currentImage = 1

	self.mp3file = "applets/Demo/content/demo.mp3"

	self.slides  = {}
	self.strings = {}
	--each entry in slides directory is a slide to display
	for entry in self:readdir("slides") do
		table.insert(self.slides, entry)
		local substrings = string.split('/', entry)
		local filename   = substrings[#substrings]
		substrings       = string.split('%.', filename)
		filename         = substrings[1]
		local token      = string.upper(filename)
		table.insert(self.strings, token)
	end
	table.sort(self.strings)
	table.sort(self.slides)
	if #self.slides > 0 then
		self:_playSlides()
		if System:findFile(self.mp3file) then
			log:info('Starting MP3 Demo track')
			self:_playTone()
		else
			log:warn('No MP3 file found')
		end
	end
end

function _playSlides(self)
	self:_showNextSlide()
	log:debug('in playslide self.volume is: ', self.volume)
	self.nextSlideTimer = Timer(5000, 
		function()
			self:_nextImage()
			self:_showNextSlide()
		end
	)
	self.nextSlideTimer:start()
end

function _nextImage(self)
	self.currentImage = self.currentImage + 1
	if self.currentImage > #self.slides then
		self.currentImage = 1
	end
	-- restart idle timeout timer to keep the player active and 
	-- the brightness to max level
	Framework.wakeup()
end

function _showNextSlide(self)
	local slide = self.slides[self.currentImage]

	self.screenWidth, self.screenHeight = Framework:getScreenSize()
	local totImg = Surface:newRGBA(self.screenWidth, self.screenHeight)
	totImg:filledRectangle(0, 0, self.screenWidth, self.screenHeight, 0x000000FF)

	local image = Surface:loadImage(slide)
	local w, h = image:getSize()
	local x, y = (self.screenWidth - w) / 2, (self.screenHeight - h) / 2
	-- draw image
	image:blit(totImg, 0, 0)

	local window = Window('window')
	window:setShowFrameworkWidgets(false)
	local fontBold = Font:load("fonts/FreeSansBold.ttf", FONT_SIZE)

	self.txtLines = {}
	local stringTxt = tostring(self:string(self.strings[self.currentImage]))
	local titleWidth = fontBold:width(stringTxt)
	if (titleWidth > (self.screenWidth - 8)) then
		self:formatText(stringTxt, fontBold)
	end
	local i
	if string.match(slide,'center%.png$') then
		--text to be added to center
		log:debug("come in center")
		if #self.txtLines==0 then
			log:debug("come here in normal cases single line")
			local txt1 = Surface:drawText(fontBold, 0xFFFFFFFF, stringTxt)
			txt1:blit(totImg, (w-titleWidth)/2, (h-FONT_SIZE-fontBold:offset())/2)
		else
			log:debug("number of lines : ", #self.txtLines)
			for i = 1, #self.txtLines do
				local titleWidthNew = fontBold:width(self.txtLines[i])
				local txt1 = Surface:drawText(fontBold, 0xFFFFFFFF, self.txtLines[i])
				txt1:blit(totImg, (w-titleWidthNew)/2, (h-FONT_SIZE-fontBold:offset()-(fontBold:height() * #self.txtLines))/2 + FONT_SIZE*i)
			end
			self.txtLines = {}
		end
	else 
		log:debug('come in bottom')
		--default considered at the bottom for now. Could be changed if needed in future
		if (stringTxt ~= '\n') then
			log:debug("come in single line botton stringTxt: ", stringTxt)
			local txt2 = Surface:drawText(fontBold, 0xFFFFFFFF, stringTxt)
			txt2:blit(totImg, (self.screenWidth-titleWidth)/2, self.screenHeight-34-fontBold:offset())
		end
		self.txtLines = {}
	end
	
	window:addWidget(Icon("icon", totImg))
	-- replace the window if it's already there
	if self.window then
		window:showInstead(Window.transitionFadeIn)
		self.window = window
	-- otherwise it's new
	else
		self.window = window
		self.window:show(Window.transitionFadeIn)
	end

	self:_windowListeners(self.window)
	
	-- FIXME: add handlers for volume_up and volume_down to adjust 
	-- volume up (to 100?) and down (to something a bit higher than fully off?)

	-- no screensavers por favor
	self.window:setAllowScreensaver(false)
end

function formatText(self, strTxt, fontStyle)
	log:debug('come in _formatText')
	local tmpStrTxt = strTxt
	log:debug("strTxt is: ", strTxt)
	local pos = 1
	local i = 1
	local numLines = 1
	local titleWidth = fontStyle:width(strTxt)
	while(titleWidth > (self.screenWidth - 8)) do
		local tmpTxt = string.sub(tmpStrTxt,1, (#tmpStrTxt/2))
		titleWidth = fontStyle:width(tmpTxt)
		numLines = numLines * 2
		tmpStrTxt = tmpTxt
	end
	for i=1,numLines do
		self.txtLines[i] = string.sub(strTxt, pos, pos + (#strTxt/numLines))
		pos = pos + #strTxt/numLines + 1
		log:debug("txtline is: ", self.txtLines[i])

	end
	local tempPos = 0
	local j = 0
	for i=1, numLines-1 do
		tempPos = string.find(self.txtLines[i+1], " ", 1)
		if tempPos ~= 1 then
			local strPart = string.sub(self.txtLines[i+1], 1, tempPos)
			local tempStr = self.txtLines[i] .. strPart
			if fontStyle:width(tempStr) > (self.screenWidth - 8) then
				log:debug("come in first string long case")
				local newStr = string.split(" ", self.txtLines[i])
				log:debug("newStr[#newStr] is: ", newStr[#newStr])
				self.txtLines[i+1] = newStr[#newStr] .. self.txtLines[i+1]
				self.txtLines[i] = newStr[1]
				log:debug("self.txtLines[i]  is: ", self.txtLines[i])
				for j=2, #newStr -1 do
					self.txtLines[i] = self.txtLines[i] .." " .. newStr[j]
				end
				log:debug("self.txtLines[i]  is: ", self.txtLines[i])
				log:debug("self.txtLines[i+1]  is: ", self.txtLines[i+1])
			else
				self.txtLines[i] = tempStr
				log:debug("strPart is: ", strPart)
				self.txtLines[i+1] = string.sub(self.txtLines[i+1], tempPos+1, #self.txtLines[i+1])
			end
		end
	end						
end

function _playTone(self)
	for mac, player in appletManager:callService("iteratePlayers") do
		if player:isLocal() then
			self.localPlayer = player
			break
		end
	end
	if self.localPlayer then
		if self:getSettings()['volumeSetting'] then
			self.volume = self:getSettings()['volumeSetting']
		end
	
		-- hack to give 2 second delay for startup sound before kicking in demo audio
		local timer = Timer(2000, 
			function()
				self.localPlayer:playFileInLoop(self.mp3file)
				self.localPlayer:volumeLocal(self.volume)
			end,
			true)
		timer:start()
		-- also save the volume preference save timer
		self.volumePrefSaver:start()
		if self.autoMuteTimer:isRunning() then
			self.autoMuteTimer:restart()
		else
			self.autoMuteTimer:start()
		end
	end
end

function getDemoStatus(self)
	return self:getSettings()['startDemo']
end

--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
