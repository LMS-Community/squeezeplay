
local pairs, ipairs, tonumber, tostring = pairs, ipairs, tonumber, tostring

local math             = require("math")
local table            = require("table")
local os	       = require("os")	
local string	       = require("jive.utils.string")

local oo               = require("loop.simple")

local Applet           = require("jive.Applet")
local Font             = require("jive.ui.Font")
local Framework        = require("jive.ui.Framework")
local Group            = require("jive.ui.Group")
local Icon             = require("jive.ui.Icon")
local Canvas           = require("jive.ui.Canvas")
local Choice           = require("jive.ui.Choice")
local Label            = require("jive.ui.Label")
local RadioButton      = require("jive.ui.RadioButton")
local RadioGroup       = require("jive.ui.RadioGroup")
local SimpleMenu       = require("jive.ui.SimpleMenu")
local Surface          = require("jive.ui.Surface")
local Window           = require("jive.ui.Window")
                       
local datetime         = require("jive.utils.datetime")

local appletManager	= appletManager
local jiveMain          = jiveMain

module(..., Framework.constants)
oo.class(_M, Applet)


function displayName(self)
	return "Clock (NEW)"
end

Clock  = oo.class()

function Clock:__init(style)
	log:debug("Init Clock")

	if not style then
		style = 'clockDigital'
	end

	local obj = oo.rawnew(self)

	obj.screen_width, obj.screen_height = Framework:getScreenSize()

	-- create window and icon
	obj.window = Window(style)

	obj.window:addListener(EVENT_MOTION,
		function()
			obj.window:hide(Window.transitionNone)
			return EVENT_CONSUME
		end)

	-- register window as a screensaver
	local manager = appletManager:getAppletInstance("ScreenSavers")
	manager:screensaverWindow(obj.window)

	return obj
end

DotMatrix = oo.class({}, Clock)

function DotMatrix:__init(ampm)
	log:debug("Init Dot Matrix Clock")

	obj = oo.rawnew(self, Clock('clockDotMatrix'))

	obj.clockGroup = Group('clock', {
		h1   = Icon("icon_dotMatrixDigit0"),
		h2   = Icon("icon_dotMatrixDigit0"),
		dots = Icon("icon_dotMatrixDots"),
		m1   = Icon("icon_dotMatrixDigit0"),
		m2   = Icon("icon_dotMatrixDigit0"),
	})

	obj.dateGroup = Group('date', {
		alarm = Icon('icon_dotMatrixAlarmOff'),
		M1    = Icon('icon_dotMatrixDate0'),
		M2    = Icon('icon_dotMatrixDate0'),
		dot1  = Icon('icon_dotMatrixDateDot'),
		D1    = Icon('icon_dotMatrixDate0'),
		D2    = Icon('icon_dotMatrixDate0'),
		dot2  = Icon('icon_dotMatrixDateDot'),
		Y1    = Icon('icon_dotMatrixDate0'),
		Y2    = Icon('icon_dotMatrixDate0'),
		Y3    = Icon('icon_dotMatrixDate0'),
		Y4    = Icon('icon_dotMatrixDate0'),
--FIXME
--		power = Icon('icon_dotMatrixPowerOn'),
	})

	obj.window:addWidget(obj.clockGroup)
	obj.window:addWidget(obj.dateGroup)

	obj.show_ampm = ampm

	if ampm then
		obj.clock_format_hour = "%I"
	else
		obj.clock_format_hour = "%H"
	end

	obj.clock_format_minute = "%M"
	obj.clock_format_month  = "%m"
	obj.clock_format_day    = "%d"
	obj.clock_format_year   = "%Y"

	obj.clock_format = obj.clock_format_hour .. ":" .. obj.clock_format_minute

	return obj
end


function DotMatrix:Draw()

	-- draw hour digits
	theTime = os.date(self.clock_format_hour)
	self:DrawClock(string.sub(theTime, 1, 1), 'h1')
	self:DrawClock(string.sub(theTime, 2, 2), 'h2')

	-- draw minute digits
	theTime = os.date(self.clock_format_minute)
	self:DrawClock(string.sub(theTime, 1, 1), 'm1')
	self:DrawClock(string.sub(theTime, 2, 2), 'm2')

	-- draw month digits
	theTime = os.date(self.clock_format_month)
	self:DrawDate(string.sub(theTime, 1, 1), 'M1')
	self:DrawDate(string.sub(theTime, 2, 2), 'M2')

	-- draw day digits
	theTime = os.date(self.clock_format_day)
	self:DrawDate(string.sub(theTime, 1, 1), 'D1')
	self:DrawDate(string.sub(theTime, 2, 2), 'D2')

	-- draw year digits
	theTime = os.date(self.clock_format_year)
	self:DrawDate(string.sub(theTime, 1, 1), 'Y1')
	self:DrawDate(string.sub(theTime, 2, 2), 'Y2')
	self:DrawDate(string.sub(theTime, 3, 3), 'Y3')
	self:DrawDate(string.sub(theTime, 4, 4), 'Y4')

end


function DotMatrix:DrawClock(digit, groupKey)
	local style = 'icon_dotMatrixDigit' .. digit
	local widget = self.clockGroup:getWidget(groupKey)
	widget:setStyle(style)
end


function DotMatrix:DrawDate(digit, groupKey)
	local style = 'icon_dotMatrixDate' .. digit
	local widget = self.dateGroup:getWidget(groupKey)
	widget:setStyle(style)
end


Digital = oo.class({}, Clock)

function Digital:__init(applet, ampm)
	log:debug("Init Digital Clock")
	
	local windowStyle = applet.windowStyle or 'clockDigital'

	obj = oo.rawnew(self, Clock(windowStyle))

	-- store the applet's self so we can call self.applet:string() for localizations
	obj.applet = applet

	obj.clockGroup = Group('clock', {
		h1   = Label('h1', '1'),
		h2   = Label('h2', '2'),
		dots = Icon("icon_digitalDots"),
		m1   = Label('m1', '0'),
		m2   = Label('m2', '0'),
		ampm = Label('ampm', ''),
	})

	obj.alarm = Group('alarm', {
		Icon('icon_digitalAlarmOn')
	})

	obj.dateGroup = Group('date', {
		dayofweek  = Label('dayofweek'),
		vdivider1  = Icon('icon_digitalClockVDivider'),
		dayofmonth = Label('dayofmonth'),
		vdivider2  = Icon('icon_digitalClockVDivider'),
		month      = Label('month'),
	})

	obj.ampm = Label('ampm')

	obj.divider = Group('horizDivider', {
		horizDivider = Icon('icon_digitalClockHDivider'),
	})

	obj.dropShadows = Group('dropShadow', {
		s1   = Icon('icon_digitalClockDropShadow'),
		s2   = Icon('icon_digitalClockDropShadow'),
		dots = Icon('icon_digitalClockBlank'),
		s3   = Icon('icon_digitalClockDropShadow'),
		s4   = Icon('icon_digitalClockDropShadow'),
	})
	obj.window:addWidget(obj.dropShadows)

	obj.window:addWidget(obj.clockGroup)
	--obj.window:addWidget(obj.alarm)
	obj.window:addWidget(obj.ampm)
	obj.window:addWidget(obj.divider)
	obj.window:addWidget(obj.dateGroup)

	obj.show_ampm = ampm

	if ampm then
		obj.clock_format_hour = "%I"
		obj.useAmPm = true
	else
		obj.clock_format_hour = "%H"
		obj.useAmPm = false
	end
	obj.clock_format_minute = "%M"

	obj.clock_format = obj.clock_format_hour .. ":" .. obj.clock_format_minute

	return obj
end

	
function Digital:Draw()

	-- string day of week
	local dayOfWeek   = os.date("%w")
	local token = "SCREENSAVER_CLOCK_DAY_" .. tostring(dayOfWeek)
	local dayOfWeekString = self.applet:string(token)
	local widget = self.dateGroup:getWidget('dayofweek')
	widget:setValue(dayOfWeekString)

	-- numerical day of month
	local dayOfMonth = os.date("%d")
	widget = self.dateGroup:getWidget('dayofmonth')
	widget:setValue(dayOfMonth)

	-- string month of year
	local monthOfYear = os.date("%m")
	token = "SCREENSAVER_CLOCK_MONTH_" .. tostring(monthOfYear)
	local monthString = self.applet:string(token)
	widget = self.dateGroup:getWidget('month')
	widget:setValue(monthString)

	-- what time is it? it's time to get ill!
	self:DrawTime()
	
	--FOR DEBUG
	--[[
	self:DrawMaxTest()
	self:DrawMinTest()
	--]]
end
	
-- this method is around for testing the rendering of different elements
-- it is not called in practice
function Digital:DrawMinTest()

	local widget = self.clockGroup:getWidget('h1')
	widget:setValue('')
	widget = self.dropShadows:getWidget('s1')
	widget:setStyle('icon_digitalClockNoShadow')
	widget = self.clockGroup:getWidget('h2')
	widget:setValue('7')
	widget = self.clockGroup:getWidget('m1')
	widget:setValue('0')
	widget = self.clockGroup:getWidget('m2')
	widget:setValue('1')

	self.ampm:setValue('AM')

	widget = self.dateGroup:getWidget('dayofweek')
	widget:setValue('Monday')
	widget = self.dateGroup:getWidget('dayofmonth')
	widget:setValue('01')
	widget = self.dateGroup:getWidget('month')
	widget:setValue('May')
	widget = self.dateGroup:getWidget('year')
	widget:setValue('09')
end

-- this method is around for testing the rendering of different elements
-- it is not called in practice
function Digital:DrawMaxTest()

	local widget = self.clockGroup:getWidget('h1')
	widget:setValue('1')
	widget = self.clockGroup:getWidget('h2')
	widget:setValue('2')
	widget = self.clockGroup:getWidget('m1')
	widget:setValue('5')
	widget = self.clockGroup:getWidget('m2')
	widget:setValue('9')
	
	self.ampm:setValue('PM')

	widget = self.dateGroup:getWidget('dayofweek')
	widget:setValue('Wednesday')
	widget = self.dateGroup:getWidget('dayofmonth')
	widget:setValue('31')
	widget = self.dateGroup:getWidget('month')
	widget:setValue('September')
	widget = self.dateGroup:getWidget('year')
	widget:setValue('09')
end


function Digital:DrawTime()
	local theHour   = os.date(self.clock_format_hour)
	local theMinute = os.date(self.clock_format_minute)

	local widget = self.clockGroup:getWidget('h1')
	if string.sub(theHour, 1, 1) == '0' then
		widget:setValue('')
		widget = self.dropShadows:getWidget('s1')
		widget:setStyle('icon_digitalClockNoShadow')
	else
		widget:setValue(string.sub(theHour, 1, 1))
		widget = self.dropShadows:getWidget('s1')
		widget:setStyle('icon_digitalClockDropShadow')
	end
	widget = self.clockGroup:getWidget('h2')
	widget:setValue(string.sub(theHour, 2, 2))

	widget = self.clockGroup:getWidget('m1')
	widget:setValue(string.sub(theMinute, 1, 1))
	widget = self.clockGroup:getWidget('m2')
	widget:setValue(string.sub(theMinute, 2, 2))
	
	-- Draw AM PM
	if self.useAmPm then
		-- localized ampm rendering
		local ampm = os.date("%p")
		self.ampm:setValue(ampm)
	end

end


function Digital:DrawDigit(digit, groupKey, hideZero)
	local widget = self.clockGroup:getWidget(groupKey)
	if digit == '0' and hideZero then
		widget:setValue('')
	else
		widget:setValue(digit)
	end
end


function Digital:DrawWeekdays(day)

	local token = "SCREENSAVER_CLOCK_DAY_" .. tostring(day)
	local dayOfWeekString = self.applet:string(token)

	local widget = self.dateGroup:getWidget('dayofweek')
	widget:setValue(dayOfWeekString)
end


function Digital:DrawMonth(month)

	local token = "SCREENSAVER_CLOCK_MONTH_" .. tostring(month)
	local monthString = self.applet:string(token)

	local widget = self.dateGroup:getWidget('month')
	widget:setValue(monthString)
end


-- TODO: Radial Clock
Radial = oo.class({}, Clock)

function Radial:__init(applet, weekstart)
	log:info("Init Radial Clock")

	obj = oo.rawnew(self, Clock('clockRadial'))

	obj.screen_width, obj.screen_height = Framework:getScreenSize()
	obj.skinParams = jiveMain:getSkinParam('radialClock')

	-- bring in applet's self so strings are available
	obj.applet    = applet
	-- weekstart is "Sunday" or "Monday"
	obj.weekstart = weekstart

	obj.canvas   = Canvas('debug_canvas', function(screen)
		obj:_reDraw(screen)
	end)
	obj.window:addWidget(obj.canvas)

	obj.ticksOff = Icon('icon_radialClockTicksOff')
	obj.tickGroup = Group('ticks', {
		ticksOff = obj.ticksOff
	})

	local _dayGroup = function() 
		return {
			dot = Icon('icon_radialClockBlankDot'),
			day  = Label('day', '')
		} 
	end

	-- days of week
	obj.day1 = Group('day1', _dayGroup())
	obj.day2 = Group('day2', _dayGroup())
	obj.day3 = Group('day3', _dayGroup())
	obj.day4 = Group('day4', _dayGroup())
	obj.day5 = Group('day5', _dayGroup())
	obj.day6 = Group('day6', _dayGroup())
	obj.day7 = Group('day7', _dayGroup())

	obj.dayOfMonth = Group('dayOfMonth', {
		text = Label('text', ''),
	})

	obj.window:addWidget(obj.tickGroup)
	obj.window:addWidget(obj.day1)
	obj.window:addWidget(obj.day2)
	obj.window:addWidget(obj.day3)
	obj.window:addWidget(obj.day4)
	obj.window:addWidget(obj.day5)
	obj.window:addWidget(obj.day6)
	obj.window:addWidget(obj.day7)
	obj.window:addWidget(obj.dayOfMonth)

	obj.clock_format = "%H:%M"
	return obj
end


function Radial:Draw()
	self:drawDay()
	self.canvas:reDraw()
end


function Radial:drawDay()

	local dayOfMonth = os.date("%d")
	if self.today == dayOfMonth then
		return
	end

	local dayOfMonthWidget = self.dayOfMonth:getWidget('text')
	dayOfMonthWidget:setValue(dayOfMonth)
	self.today = today

	local DAYS_SUN = { "SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY" }
	local DAYS_MON = { "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY" }
	local days

	-- if week starts with monday, monday = 1 and days start from monday
        if self.weekstart == "Monday" then
                dayOfWeek = tonumber(os.date("%u"))
                days = DAYS_MON
	-- if week starts with sunday, sunday = 1 and days start from sunday
	else
                dayOfWeek = tonumber(os.date("%w"))+1
                days = DAYS_SUN
        end
	local tokenStub = "SCREENSAVER_CLOCK_DAYSHORT_" 

	local monthString = self.applet:string(token)
	for i = 1, 7 do
		local token = tokenStub .. tostring(days[i])
		local key = "day" .. tostring(i)
		local textWidget = self[key]:getWidget('day')
		textWidget:setValue(self.applet:string(token))

		-- when i is today, style accordingly
		local iconWidget = self[key]:getWidget('dot')
		if i == dayOfWeek then
			-- style icon to be glowing dot
			iconWidget:setStyle('icon_radialClockDot')
			-- style text to be correct color
			textWidget:setStyle('radialClockToday')
			
		else
			-- not today, so style accordingly
			textWidget:setStyle('radialClockNotToday')
			iconWidget:setStyle('icon_radialClockBlankDot')
		end
	end

end


function Radial:_reDraw(screen)

	-- Draw Background
	local x, y, facew, faceh
	
	-- Setup Time Objects
	local m = os.date("%M")
	local h = os.date("%I")

	-- Hour Pointer
	for i = 0, tonumber(h) do
		local angle = (360 / 12) * i
		local hourTick = Surface:loadImage(self.skinParams.hourTickPath)
		local tmp = hourTick:rotozoom(-angle, 1, 5)
		facew, faceh = tmp:getSize()
		x = math.floor((self.screen_width/2) - (facew/2))
		y = math.floor((self.screen_height/2) - (faceh/2))
		tmp:blit(screen, x, y)
	end

	-- Minute Pointer
	for i = 0, tonumber(m) do
		local angle = (360 / 60) * i
		local minuteTick = Surface:loadImage(self.skinParams.minuteTickPath)
		local tmp = minuteTick:rotozoom(-angle, 1, 5)
		facew, faceh = tmp:getSize()
		x = math.floor((self.screen_width/2) - (facew/2))
		y = math.floor((self.screen_height/2) - (faceh/2))
		tmp:blit(screen, x, y)
	end

end


-- keep these methods with their legacy names
-- to ensure backwards compatibility with old settings.lua files
function openDetailedClock(self)
	return self:_openScreensaver("Digital", 'clockDigital')
end

function openDetailedClockBlack(self)
	return self:_openScreensaver("Digital", 'clockDigitalBlack')
end

function openDetailedClockTransparent(self)
	return self:_openScreensaver("Digital", 'clockDigitalTransparent')
end

function openAnalogClock(self)
	return self:_openScreensaver("Radial")
end


function openStyledClock(self)
	return self:_openScreensaver("DotMatrix")
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


function _openScreensaver(self, type, windowStyle)
	log:debug("Type: " .. type)

	-- Global Date/Time Settings
	local weekstart  = datetime:getWeekstart() 
	local hours      = datetime:getHours() 
	local dateFormat = datetime:getDateFormat() 

	hours = (hours == "12")

	-- Create two clock instances, so that we can do use a fade in transition
	self.clock = {}
	self.buffer = 2 -- buffer to display

	if type == "DotMatrix" then
		-- This clock always uses 24 hours mode for now
		self.clock[1] = DotMatrix(hours)
		self.clock[2] = DotMatrix(hours)
	elseif type == "Digital" then
		self.windowStyle = windowStyle
		self.clock[1] = Digital(self, hours)
		self.clock[2] = Digital(self, hours)
	elseif type == "Radial" then
		self.clock[1] = Radial(self, weekstart)
		self.clock[2] = Radial(self, weekstart)
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

