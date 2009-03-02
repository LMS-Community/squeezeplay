
local pairs, ipairs, tonumber, tostring = pairs, ipairs, tonumber, tostring

local math             = require("math")
local table            = require("table")
local os	       = require("os")	
local string	       = require("string")

local oo               = require("loop.simple")

local Applet           = require("jive.Applet")
local Font             = require("jive.ui.Font")
local Framework        = require("jive.ui.Framework")
local Icon             = require("jive.ui.Icon")
local Choice           = require("jive.ui.Choice")
local Label            = require("jive.ui.Label")
local RadioButton      = require("jive.ui.RadioButton")
local RadioGroup       = require("jive.ui.RadioGroup")
local SimpleMenu       = require("jive.ui.SimpleMenu")
local Surface          = require("jive.ui.Surface")
local Window           = require("jive.ui.Window")
                       
local log              = require("jive.utils.log").logger("applets.screensavers")
local datetime         = require("jive.utils.datetime")

local appletManager	= appletManager

module(..., Framework.constants)
oo.class(_M, Applet)


function displayName(self)
	return "Clock"
end

-----------------------------------------------------------------------------------------
-- Settings
--

local Analog_Presets = {
	Teal = {
		HighlightColor = 0x004444FF,
		HighlightImage = "clock_analog_bkgrd.png",
		BackgroundColor = 0x000000FF,
	},
	Default = nil,
}

Analog_Presets.Default = Analog_Presets.Teal

local DigitalStyled_Presets = {
	Green = {
		FontSize = 148,
		Color = 0x0083874B,
		Background = 0x000000FF
	}, 
	White = {
		FontSize = 148,
		Color = 0xFFFFFF14,
		Background = 0x000000FF
	}
}

local DigitalStyledPos = {
	{
		x = 58,
		y = 58,
	},
	{
		x = 124,
		y = 58,
	},
	{
		x = 58,
		y = 168,
	},
	{
		x = 124,
		y = 168,
	},
}

local DigitalDetailed_Presets = {
	Default = {
		Fonts = {
			Main = {
				Size = 60,
				Color = 0xFFFFFFFF
			},
			Days = {
				Size = 16,
				SelectedColor = 0x909090FF,
				Color = 0x909090FF
			},
			AMPM = {
				Size = 14,
				Color = 0xFFFFFFFF
			},
			Date = {
				Size = 17,
				Color = 0x555555FF
			}
		},
		Background = 0x000000FF,
		FirstDayInWeek = "Sunday",
	}
}


----------------------------------------------------------------------------------------
-- Screen Saver Display 
--

Clock  = oo.class()

function Clock:__init()
	log:info("Init Clock")

	obj = oo.rawnew(self)

	obj.screen_width, obj.screen_height = Framework:getScreenSize()

	-- create window and icon
	obj.window = Window("absolute")
	obj:_createSurface()

	obj.window:addListener(EVENT_MOTION,
		function()
			obj.window:hide()
			return EVENT_CONSUME
		end)

	-- register window as a screensaver
	local manager = appletManager:getAppletInstance("ScreenSavers")
	manager:screensaverWindow(obj.window)

	return obj
end

function Clock:_createSurface()
	self.bg  = Surface:newRGBA(self.screen_width, self.screen_height)
	self.bgicon = Icon("icon", self.bg)
	self.window:addWidget(self.bgicon)
end

function Clock:Resize(w, h)
	self.screen_width = w
	self.screen_height = h

	self.window:removeWidget(self.bgicon)
	self:_createSurface()

	self:Draw()
end


Analog = oo.class({}, Clock)

function Analog:__init(preset)
	log:info("Init Analog Clock")

	obj = oo.rawnew(self, Clock())

	obj.clockface = Surface:loadImage("applets/Clock/ClockFace.png")
	obj.pointer_hour = Surface:loadImage("applets/Clock/HourHand.png")
	obj.pointer_minute = Surface:loadImage("applets/Clock/MinuteHand.png")

	obj.clockhighlight = Surface:loadImage("applets/Clock/" .. preset.HighlightImage)
	obj.bgcolor = preset.BackgroundColor

	obj.clock_format = "%H:%M"

	return obj
end


function Analog:Draw()
	-- Draw Background
	self.bg:filledRectangle(0, 0, self.screen_width, self.screen_height, self.bgcolor)

	local x, y

	-- Clock Highlight
	local hlw, hlh = self.clockhighlight:getSize()
	x = math.floor((self.screen_width/2) - (hlw/2))
	y = math.floor((self.screen_height/2) - (hlh/2))
	self.clockhighlight:blit(self.bg, x, y)

	-- Clock Face
	local facew, faceh = self.clockface:getSize()
	x = math.floor((self.screen_width/2) - (facew/2))
	y = math.floor((self.screen_height/2) - (faceh/2))
	self.clockface:blit(self.bg, x, y)

	-- Setup Time Objects
	local m = os.date("%M")
	local h = os.date("%I")

	-- Hour Pointer
	local angle = (360 / 12) * (h + (m/60))

	local tmp = self.pointer_hour:rotozoom(-angle, 1, 5)
	local facew, faceh = tmp:getSize()
	x = math.floor((self.screen_width/2) - (facew/2))
	y = math.floor((self.screen_height/2) - (faceh/2))
	tmp:blit(self.bg, x, y)

	-- Minute Pointer
	local angle = (360 / 60) * m 

	local tmp = self.pointer_minute:rotozoom(-angle, 1, 5)
	local facew, faceh = tmp:getSize()
	x = math.floor((self.screen_width/2) - (facew/2))
	y = math.floor((self.screen_height/2) - (faceh/2))
	tmp:blit(self.bg, x, y)

	self.bgicon:reDraw()
end


DigitalStyled = oo.class({}, Clock)

function DigitalStyled:__init(preset, ampm)
	log:info("Init Digital Simple")

	obj = oo.rawnew(self, Clock())

	obj.color = preset.Color
	obj.bgcolor = preset.Background

	-- Load 0 - 9 Graphics
	obj.digits = {}
	obj.digits[1]   =  Surface:loadImage("applets/Clock/Digital_dotmatrix_ghosted_0.png")
	obj.digits[2]   =  Surface:loadImage("applets/Clock/Digital_dotmatrix_ghosted_1.png")
	obj.digits[3]   =  Surface:loadImage("applets/Clock/Digital_dotmatrix_ghosted_2.png")
	obj.digits[4]   =  Surface:loadImage("applets/Clock/Digital_dotmatrix_ghosted_3.png")
	obj.digits[5]   =  Surface:loadImage("applets/Clock/Digital_dotmatrix_ghosted_4.png")
	obj.digits[6]   =  Surface:loadImage("applets/Clock/Digital_dotmatrix_ghosted_5.png")
	obj.digits[7]   =  Surface:loadImage("applets/Clock/Digital_dotmatrix_ghosted_6.png")
	obj.digits[8]   =  Surface:loadImage("applets/Clock/Digital_dotmatrix_ghosted_7.png")
	obj.digits[9]   =  Surface:loadImage("applets/Clock/Digital_dotmatrix_ghosted_8.png")
	obj.digits[10]  =  Surface:loadImage("applets/Clock/Digital_dotmatrix_ghosted_9.png")

	obj.show_ampm = ampm

	if ampm then
		obj.clock_format_hour = "%I"
	else
		obj.clock_format_hour = "%H"
	end
	obj.clock_format_minute = "%M"

	obj.clock_format = obj.clock_format_hour .. ":" .. obj.clock_format_minute

	return obj;
end

function DigitalStyled:Draw()
	-- draw background
	self.bg:filledRectangle(0, 0, self.screen_width, self.screen_height, self.bgcolor)

	theTime = os.date(self.clock_format_hour)
	self:DrawDigit(string.sub(theTime, 1, 1), DigitalStyledPos[1].x, DigitalStyledPos[1].y)
	self:DrawDigit(string.sub(theTime, 2, 2), DigitalStyledPos[2].x, DigitalStyledPos[2].y)

	theTime = os.date(self.clock_format_minute)
	self:DrawDigit(string.sub(theTime, 1, 1), DigitalStyledPos[3].x, DigitalStyledPos[3].y)
	self:DrawDigit(string.sub(theTime, 2, 2), DigitalStyledPos[4].x, DigitalStyledPos[4].y)

	self.bgicon:reDraw()
end

function DigitalStyled:DrawDigit(digit, x, y)
	local theSrf = nil

	theSrf = self.digits[tonumber(digit)+1]
	theSrf:blit(self.bg, x, y)
end


DigitalDetailed = oo.class({}, Clock)

function DigitalDetailed:__init(preset, ampm, firstday)
	log:info("Init Digital Detailed")
	
	local fontname = "fonts/FreeSans.ttf"

	obj = oo.rawnew(self, Clock())

	obj.bgcolor = preset.Background
	obj.mainfont = Font:load(fontname, preset.Fonts.Main.Size)
	obj.mainfont_color = preset.Fonts.Main.Color

	obj.daysfont = Font:load(fontname, preset.Fonts.Days.Size)
	obj.daysfont_color = preset.Fonts.Days.Color
	obj.daysfont_scolor = preset.Fonts.Days.SelectedColor

	obj.datefont = Font:load(fontname, preset.Fonts.Date.Size)
	obj.datefont_color = preset.Fonts.Date.Color

	obj.ampmfont = Font:load(fontname, preset.Fonts.AMPM.Size)
	obj.ampmfont_color = preset.Fonts.AMPM.Color

	obj.mainborder = Surface:loadImage("applets/Clock/clock_classic_bkgrd.png")
	obj.dots       = Surface:loadImage("applets/Clock/clock_classic_time_dots.png")
	obj.daysborder = Surface:loadImage("applets/Clock/weekday_frame.png")

	obj.weekstart = preset.FirstDayInWeek
	if firstday != nil then
		obj.weekstart = firstday
	end

	obj.show_ampm = ampm

	if ampm then 
		obj.clock_format = "%I:%M"
	else
		obj.clock_format = "%H:%M"
	end

	return obj;
end

local CLOCKY = 52
	
function DigitalDetailed:DrawTime(x, y, bw, bh, useAmPm)

	local screenMidpointX = (self.screen_width/2)
	local digitStartY = y + CLOCKY - self.mainfont:offset()

	-- ampm variables, needed before drawing dots
	local ampm = os.date("%p")
	local ampmSrf = Surface:drawText(self.ampmfont, self.ampmfont_color, ampm)
	local ampmw, ampmh = ampmSrf:getSize()

	-- Draw dots

	local dotsWidth, dotsHeight = obj.dots:getSize()
	local dw, dh = self.dots:getSize()
	-- x position of dots is center of the screen
	-- minus half the width of the dots themselves
	local dotsx = screenMidpointX - (dotsWidth/2)
	if useAmPm then
		dotsx = dotsx - (ampmw/2)
	end

	-- "midpoint" is now the midpoint of the dots, not the screen
	local adjMidpointX = dotsx + (dotsWidth/2)

	-- Draw Hour

	-- Snip of leading 0
	local theHour
	if useAmPm then
		theHour = string.gsub(os.date("%I"), "^0", "", 1)
	else
		theHour = string.gsub(os.date("%H"), "^0", "", 1)
	end

	local hourSrf = Surface:drawText(self.mainfont, self.mainfont_color, theHour)
	local hw, hh = hourSrf:getSize()

	-- x position for hour is half the screen width - 10 pixels - width of hour digits
	local hourStartX = adjMidpointX - 10 - hw
	hourSrf:blit(self.bg, hourStartX, digitStartY)

	-- Draw Minute

	local theMinute = os.date("%M")
	local minSrf = Surface:drawText(self.mainfont, self.mainfont_color, theMinute)
	-- x position for minutes is half the screen width + 10 pixels
	local minStartX = adjMidpointX + 10
	minSrf:blit(self.bg, minStartX, digitStartY)
	local mw,  mh  = minSrf:getSize()

	-- y position of dots is midpoint of where minute digit starts and ends,
	-- minus half the height of the dots themselves
	local dotsy = ((digitStartY + (digitStartY + mh)) / 2) - (dotsHeight/2)
	self.dots:blit(self.bg, dotsx, dotsy)

	-- Draw AM PM

	if useAmPm then
			
		local ampmStartY = y + CLOCKY - self.ampmfont:offset() + 3

		-- x position of ampm is minute start X + minute width + 5 
		local ampmStartX = minStartX + mw + 5
	
		ampmSrf:blit(self.bg, ampmStartX, ampmStartY)
	end

end

local DATEY = 12

function DigitalDetailed:Draw()

	-- Draw Background
	self.bg:filledRectangle(0, 0, self.screen_width, self.screen_height, self.bgcolor)

	local x,y
		
	-- Draw Main Border
	local bw, bh = self.mainborder:getSize()
	x = (self.screen_width/2) - (bw/2)
	y = (self.screen_height/2) - (bh/2)
	self.mainborder:blit(self.bg, x, y)


	if self.weekstart == "Sunday" then
		self:DrawWeekdays(x, y, bw, bh, os.date("%w"))
	else 
		self:DrawWeekdays(x, y, bw, bh, tonumber(os.date("%u"))-1)
	end

	self:DrawTime(x, y, bw, bh, self.show_ampm)

	-- Draw Date
	local theDate = os.date(datetime:getDateFormat())
	local dateSrf = Surface:drawText(self.datefont, self.datefont_color, theDate)
	local dw, dh = dateSrf:getSize()

	-- if date width exceeds border width, then fall back to a format that will fit
	if dw > bw then
		theDate = os.date("%a %d %b %Y")
		dateSrf = Surface:drawText(self.datefont, self.datefont_color, theDate)
		dw, dh = dateSrf:getSize()
	end

	local dateStartY = y + DATEY
	local dateStartX = x + ((bw/2) - (dw/2))
	
	dateSrf:blit(self.bg, dateStartX, dateStartY - self.datefont:offset())

	self.bgicon:reDraw()
end
	
local PADDINGX = 6
local PADDINGY = 10 

local DAYFIXY = 0

local DAYS_SUN = { "S", "M", "T", "W", "T", "F", "S" }
local DAYS_MON = { "M", "T", "W", "T", "F", "S", "S" }

function DigitalDetailed:DrawWeekdays(x, y, bw, bh, day)

	day = tonumber(day)

	local dw, dh = self.daysborder:getSize()	

	local days = DAYS_SUN
	if self.weekstart == "Monday" then
		days = DAYS_MON
	end

	local i = 0
	while i < 7 do

		local newx = x + (i*dh) + PADDINGX

		-- Only draw border on today!
		if(i == day) then	
			self.daysborder:blit(self.bg, newx, y + bh - (dh + PADDINGY))
		end

		local c = self.daysfont_color
		local daySrf = Surface:drawText(self.daysfont, c, days[i+1])

		local dayw = daySrf:getSize()
		local dayh = self.daysfont:capheight()

		daySrf:blit(self.bg, newx + ((dw/2)-(dayw/2)), y + bh - (dh + PADDINGY) + ((dh/2)-(dayh/2)) + DAYFIXY - self.daysfont:offset())

		i = i + 1
	end
end

function getPreset(self, type)
	local pname = ""
	
	if type == "analog" then
		return Analog_Presets.Default
	elseif type == "styled" then

		pname = self:getSettings()["digitalstyled_preset"]
		if pname == "Green" then 
			return DigitalStyled_Presets.Green;
		elseif pname == "White" then
			return DigitalStyled_Presets.White;
		else 
			return nil
		end

	elseif type == "detailed" then
		return DigitalDetailed_Presets.Default
	else
		return nil
	end

end

function openAnalogClock(self)
	return self:_openScreensaver("analog")
end

function openStyledClock(self)
	return self:_openScreensaver("styled")
end

function openDetailedClock(self)
	return self:_openScreensaver("detailed")
end


function _tick(self)
	local theTime = os.date(self.clock[1].clock_format)
	if theTime == self.oldTime then
		-- nothing to do yet
		return
	end

	self.oldTime = theTime

	self.clock[self.buffer]:Draw()
	self.clock[self.buffer].window:showInstead(Window.transitionFadeIn)

	self.buffer = (self.buffer == 1) and 2 or 1
end


function _openScreensaver(self, type)
	log:info("Type: " .. type)

	-- Global Date/Time Settings
	local hours      = datetime:getHours() 
	local weekstart  = datetime:getWeekstart()

	local preset = self:getPreset(type)
	hours = (hours == "12")

	-- Create two clock instances, so that we can do use a fade in transition
	self.clock = {}
	self.buffer = 2 -- buffer to display

	if type == "styled" then
		-- This clock always uses 24 hours mode for now
		self.clock[1] = DigitalStyled(preset, hours)
		self.clock[2] = DigitalStyled(preset, hours)
	elseif type == "detailed" then
		self.clock[1] = DigitalDetailed(preset, hours, weekstart)
		self.clock[2] = DigitalDetailed(preset, hours, weekstart)
	elseif type == "analog" then
		self.clock[1] = Analog(preset)
		self.clock[2] = Analog(preset)
	else
		log:error("Unknown clock type")
		return
	end

	self.clock[1].window:addTimer(1000, function() self:_tick() end)
	self.clock[2].window:addTimer(1000, function() self:_tick() end)

	self.clock[1]:Draw()
	self.clock[1].window:show(Window.transitionFadeIn)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

