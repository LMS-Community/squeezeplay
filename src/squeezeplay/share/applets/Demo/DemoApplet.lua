

-- stuff we use
local pairs, setmetatable, tostring, tonumber  = pairs, setmetatable, tostring, tonumber

local oo            = require("loop.simple")
local lfs           = require("lfs")
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

function confirmDemo(self)

	-- the code is '1234'
	if tonumber(self.code) == 1234 then
		local window = Window("text_list", self:string("DEMO_START_DEMO"))
		window:setAllowScreensaver(false)

		local menu = SimpleMenu("menu", items)
		menu:setComparator(SimpleMenu.itemComparatorWeightAlpha)
		local textArea = Textarea('text', self:string('DEMO_START_DEMO_WARNING'))
		menu:setHeaderWidget(textArea)
		window:addWidget(menu)
	
		menu:addItem({
			text = self:string("DEMO_START_DEMO"),
			sound = "WINDOWSHOW",
			weight = 2,
			callback = function(event, menuItem)
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

	-- add setting to immediately start demo on boot
	self:getSettings()['startDemo'] = true
	self:storeSettings()

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
	self.nextSlideTimer = Timer(6000, 
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

	self.window:ignoreAllInputExcept({ "volume_up", "volume_down" },
                        function(actionEvent)
                            return EVENT_CONSUME
                        end
	)
	
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
		-- fixed volume (50%)
		decode:audioGain(0x01000, 0x01000)

		localPlayer:playFileInLoop(self.mp3file)
	end
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

