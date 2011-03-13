
-- stuff we use
local ipairs, pairs, setmetatable, tostring, tonumber  = ipairs, pairs, setmetatable, tostring, tonumber

local oo            = require("loop.simple")
local lfs           = require("lfs")
local math          = require("math")
local string        = require("jive.utils.string")
local table         = require("jive.utils.table")

local Applet        = require("jive.Applet")
local System        = require("jive.System")
local SlimServer    = require("jive.slim.SlimServer")
local LocalPlayer   = require("jive.slim.LocalPlayer")

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

-- volumeMap has the correct gain settings for volume settings 1-100. Based on Boom volume curve
local volumeMap = {
16, 18, 22, 26, 31, 36, 43, 51, 61, 72, 85, 101, 120, 142, 168, 200, 237, 281, 333, 395, 468, 555, 658, 781, 926, 980, 1037, 1098, 1162, 1230, 1302, 1378, 1458, 1543, 1634, 1729, 1830, 1937, 2050, 2048, 2304, 2304, 2560, 2816, 2816, 3072, 3328, 3328, 3584, 3840, 4096, 4352, 4608, 4864, 5120, 5376, 5632, 6144, 6400, 6656, 7168, 7680, 7936, 8448, 8960, 9472, 9984, 10752, 11264, 12032, 12544, 13312, 14080, 14848, 15872, 16640, 17664, 18688, 19968, 20992, 22272, 23552, 24832, 26368, 27904, 29696, 31232, 33024, 35072, 37120, 39424, 41728, 44032, 46592, 49408, 52224, 55296, 58624, 61952, 65536,
}

function init(self)

	self.delta = 0
	self.volume = 51

	self.idleTimer = Timer(
		30000, 
		function()
			_volumeAutoAdjust(self)
		end
	)
	self.volumePrefSaver = Timer(
		60000,
		function()
			_saveVolPref(self)
		end
	)

        return self
end


function _saveVolPref(self)
	local currentSetting = self:getSettings()['volumeSetting']
	if currentSetting != self.volume then
		log:info('saving volume pref for demo to: ', self.volume)
		self:getSettings()['volumeSetting'] = self.volume
		self:storeSettings()
	end	
end


function _volumeAutoAdjust(self)
	if self.volume > 60 then
		log:warn('idle timeout, setting the volume to 20')
		self.delta = 20 - self.volume 
		_updateVolume(self, 20, true)
		_openPopup(self)
	end
	self.idleTimer:stop()
end

function _updateDisplay(self)
	if self.volume <= 0 then
		self.title:setValue(self:string("DEMO_VOLUME_MUTED"))
		self.slider:setValue(0)

	else
		self.title:setValue(self:string("DEMO_VOLUME", tostring(self.volume) ) )
		self.slider:setValue(self.volume)
	end
end

function _openPopup(self)
	if self.popup then
		return
	end

	local popup = Popup("slider_popup")
	popup:setAutoHide(false)
	popup:setAlwaysOnTop(true)

	local title = Label("heading", "")
	popup:addWidget(title)

        popup:addWidget(Icon('icon_popup_volume'))

	--slider is focused widget so it will receive events before popup gets a chance
	local slider = Slider("volume_slider", -1, 100, self.volume,
                              function(slider, value, done)
					self.delta = value - self.volume
					self:_updateVolume(value)
                              end)

	popup:addWidget(Group("slider_group", {
		slider = slider,
	}))

	popup:focusWidget(nil)

	-- we handle events
	popup.brieflyHandler = false

	self:_windowListeners(popup)

	-- open the popup
	self.popup = popup
	self.title = title
	self.slider = slider

	_updateDisplay(self)

	popup:showBriefly(3000,
		function()

			--This happens on ANY window pop, not necessarily the popup window's pop
			local isPopupOnStack = false
			local stack = Framework.windowStack
			for i in ipairs(stack) do
				if stack[i] == popup then
					isPopupOnStack = true
					break
				end
			end

			--don't clear it out if the pop was from another window
			if not isPopupOnStack then
				self.popup = nil
			end
		end,
		Window.transitionPushPopupUp,
		Window.transitionPushPopupDown
	)
end

function _windowListeners(self, window)
       -- don't allow anything but vol up and vol down
        window:ignoreAllInputExcept({ "volume_up", "volume_down" },
                        function(actionEvent)
                            return EVENT_CONSUME
                        end
        )
        -- there is no escape, resistance is futile!
        window:addActionListener('soft_reset', self, function() return EVENT_CONSUME end)

        window:addActionListener('volume_up', self, volEvent)
        window:addActionListener('volume_down', self, volEvent)
end


function _updateVolume(self, force)

	if not self.popup and not force then
		return
	end
	-- keep the popup window open
	if self.popup then
		self.popup:showBriefly()
	-- or open it (in the case of force for auto vol adjust)
	else
		_openPopup(self)
	end

        local new

	new = math.abs(self.volume) + self.delta

        if new > 100 then
                new = 100
        elseif new <= VOLUME_STEP and new > 0 then
                new = 1 -- lowest volume
        elseif new < 0 then
                new = 0
        end

	if self.volume == new then
		return
	end

	local setVolume = volumeMap[new]
	log:info('set volume to : ', new, '(', setVolume, ')')
	decode:audioGain(setVolume, setVolume)

	self.delta  = 0
	self.volume = new
	self.idleTimer:restart()

	_updateDisplay(self)

end

function volEvent(self, volumeEvent)
	if not self.popup then
		_openPopup(self)
	end

	if volumeEvent:getAction() == 'volume_up' then
		self.delta = VOLUME_STEP
	else
		self.delta = -1 * VOLUME_STEP
	end

	_updateVolume(self)
	return EVENT_CONSUME
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
		window:setAllowScreensaver(false)

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
	window:addWidget(Icon("background", totImg))

	-- draw text
	local label = Textarea('demo_text', self:string(self.strings[self.currentImage]))
	window:addWidget(label)

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

function _playTone(self)
	local localPlayer = nil
	for mac, player in appletManager:callService("iteratePlayers") do
		if player:isLocal() then
			localPlayer = player
			break
		end
       	end
			
	if localPlayer then
		if self:getSettings()['volumeSetting'] then
			self.volume = self:getSettings()['volumeSetting']
		end
	
		-- hack to give 2 second delay for startup sound before kicking in demo audio
		local timer = Timer(2000, 
			function()
				localPlayer:playFileInLoop(self.mp3file)
				decode:audioGain(volumeMap[self.volume], volumeMap[self.volume])
			end,
			true)
		timer:start()
		-- also save the volume preference save timer
		self.volumePrefSaver:start()
	end
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

