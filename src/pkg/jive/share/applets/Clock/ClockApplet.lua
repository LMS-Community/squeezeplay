
local collectgarbage = collectgarbage
local pairs, ipairs, tostring = pairs, ipairs, tostring
local tonumber = tonumber

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

local EVENT_KEY_PRESS  = jive.ui.EVENT_KEY_PRESS
local EVENT_WINDOW_RESIZE = jive.ui.EVENT_WINDOW_RESIZE
local EVENT_CONSUME    = jive.ui.EVENT_CONSUME
local EVENT_WINDOW_POP = jive.ui.EVENT_WINDOW_POP
local FRAME_RATE       = jive.ui.FRAME_RATE
local LAYER_FRAME      = jive.ui.LAYER_FRAME
local LAYER_CONTENT    = jive.ui.LAYER_CONTENT
local LAYER_ALL	       = jive.ui.JIVE_LAYER_ALL
local LAYER_CONTENT_ON_STAGE = jive.ui.LAYER_CONTENT_ON_STAGE
local KEY_BACK         = jive.ui.KEY_BACK

local appletManager	= appletManager

module(...)
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

local DigitalSimple_Presets = {
	White = {
		FontSizes = {
			Main = 72,
			AMPM = 36,
			Date = 18
		},
		Color = 0xFFFFFFFF,
		Background = 0x000000FF
	}
}

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

function Clock:__init(window)
	log:info("Init Clock")
	local w, h = Framework:getScreenSize()

	obj = oo.rawnew(self)
	obj.window = window
	obj.screen_width = w
	obj.screen_height = h

	obj:_createSurface()

	return obj
end

function Clock:_createSurface()
	self.bg  = Surface:newRGBA(self.screen_width, self.screen_height)
	self.bgicon = Icon("background", self.bg)
	self.window:addWidget(self.bgicon)
end

function Clock:Tick()
	self:Draw()
end 

function Clock:Resize(w, h)
	self.screen_width = w
	self.screen_height = h

	self.window:removeWidget(self.bgicon)

	self:_createSurface()

	self:Draw(true)
end

Analog = oo.class({}, Clock)

function Analog:__init(window, preset)
	log:info("Init Analog Clock")

	obj = oo.rawnew(self, Clock(window))

	obj.clockface = Surface:loadImage("applets/Clock/ClockFace.png")
	obj.pointer_hour = Surface:loadImage("applets/Clock/HourHand.png")
	obj.pointer_minute = Surface:loadImage("applets/Clock/MinuteHand.png")

	obj.clockhighlight = Surface:loadImage("applets/Clock/" .. preset.HighlightImage)
	obj.bgcolor = preset.BackgroundColor

	obj.clock_format = "%H:%M"
	obj.oldtime = ""

	return obj
end


function Analog:Draw(force)
	local theTime = os.date(self.clock_format)
	if theTime != self.oldtime or force then
		self.oldtime = theTime

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

end

DigitalSimple = oo.class({}, Clock)

function DigitalSimple:__init(window, preset, ampm)
	log:info("Init Digital Simple")
	
	local fontname = "fonts/FreeSans.ttf"

	obj = oo.rawnew(self, Clock(window))

	obj.color = preset.Color
	obj.bgcolor = preset.Background
	obj.font = Font:load(fontname, preset.FontSizes.Main)
	obj.ampmfont = Font:load(fontname, preset.FontSizes.AMPM)
	obj.datefont = Font:load(fontname, preset.FontSizes.Date)
	obj.oldtime = ""
	obj.show_ampm = ampm

	if ampm then 
		obj.clock_format = "%I:%M"
	else
		obj.clock_format = "%H:%M"
	end

	return obj;
end

function DigitalSimple:Draw(force)
	local theTime = os.date(self.clock_format)

	if theTime != self.oldtime or force then
		self.oldtime = theTime

		local timeSrf = Surface:drawText(self.font, self.color, theTime)	

		local ampmSrf = nil
		local ampmWidth, ampmHeight = 0
		if self.show_ampm then
			ampmSrf = Surface:drawText(self.ampmfont, self.color, os.date("%p"))
			ampmWidth, ampmHeight = ampmSrf:getSize()
		end

		local dateSrf = Surface:drawText(self.datefont, self.color, os.date(datetime:getDateFormat()))

		local tw, th = timeSrf:getSize()

		local x
		if self.show_ampm then
			x = math.floor((self.screen_width/2) - ((tw+ampmWidth)/2))
		else
			x = math.floor((self.screen_width/2) - (tw/2))
		end

		local y = math.floor((self.screen_height/2) - (th/2))

		-- draw background
		self.bg:filledRectangle(0, 0, self.screen_width, self.screen_height, self.bgcolor)
		timeSrf:blit(self.bg, x, y)

		if ampmSrf then
			local offset = 0
			if os.date("%p") == "PM" then
				offset = offset + ampmHeight
			end
			ampmSrf:blit(self.bg, x+tw+3, y+offset)
		end
		

		local tw, th = dateSrf:getSize()
		x = math.floor((self.screen_width/2) - (tw/2))

		dateSrf:blit(self.bg, x, self.screen_height - th*3)

		self.bgicon:reDraw()
	end
end

DigitalStyled = oo.class({}, Clock)

function DigitalStyled:__init(window, preset, ampm)
	log:info("Init Digital Simple")

	obj = oo.rawnew(self, Clock(window))

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

	obj.oldtime = ""
	obj.show_ampm = ampm

	if ampm then
		obj.clock_format_hour = "%I"
	else
		obj.clock_format_hour = "%H"
	end
	obj.clock_format_minute = "%M"

	return obj;
end

function DigitalStyled:Draw(force)
	local theTime = os.date("%H:%M")

	if theTime != self.oldtime or force then
		self.oldtime = theTime

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
end

function DigitalStyled:DrawDigit(digit, x, y)
	local theSrf = nil

	log:error(tonumber(digit)+1)
	theSrf = self.digits[tonumber(digit)+1]
	theSrf:blit(self.bg, x, y)
end

DigitalDetailed = oo.class({}, Clock)

function DigitalDetailed:__init(window, preset, ampm, firstday)
	log:info("Init Digital Detailed")
	
	local fontname = "fonts/FreeSans.ttf"

	obj = oo.rawnew(self, Clock(window))

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

	obj.oldtime = ""
	obj.show_ampm = ampm

	if ampm then 
		obj.clock_format = "%I:%M"
	else
		obj.clock_format = "%H:%M"
	end

	obj:SetPositions()

	return obj;
end

local CLOCKY = 48
local DATEY = 10
	
function DigitalDetailed:SetPositions()
	local testSrf  = Surface:drawText(self.mainfont, self.mainfont_color, "88")
	local dw, dh = testSrf:getSize()

	self.measurements = {}
	self.measurements.hourEnd = 105
	self.measurements.hour = self.measurements.hourEnd - dw
	self.measurements.minute = 125
	self.measurements.minuteEnd = 125 + dw
	self.measurements.ampm = self.measurements.minuteEnd + 2
	self.measurements.digitwidth = dw / 2
end

function DigitalDetailed:DrawAMPMTime(x, y, bw, bh)

	-- Draw Hour

	-- Snip of leading 0
	local theHour = string.gsub(os.date("%I"), "^0", "", 1)

	local hourSrf = Surface:drawText(self.mainfont, self.mainfont_color, theHour)
	local hw, hh = hourSrf:getSize()

	-- Make sure the position is correct for hours below 10
	if(tonumber(theHour) < 10) then
		hourSrf:blit(self.bg, self.measurements.hour + self.measurements.digitwidth, y + CLOCKY)			
	else 
		hourSrf:blit(self.bg, self.measurements.hour, y + CLOCKY)			
	end

	-- Draw Minute
	local theMinute = os.date("%M")
	local minSrf = Surface:drawText(self.mainfont, self.mainfont_color, theMinute)
	local minStartY = y + CLOCKY
	minSrf:blit(self.bg, self.measurements.minute, minStartY)

	local hourWidth, hourHeigh  = hourSrf:getSize()
	local minWidth,  minHeight  = minSrf:getSize()
	local dotsWidth, dotsHeight = obj.dots:getSize()

	local startOfMinX = self.measurements.minute
	-- Draw Time Dots

	local dw, dh = self.dots:getSize()
	-- x position of dots is midpoint of end of hour digits and start of minute digits,
	-- minus half the width of the dots themselves
	local dotsx = ((self.measurements.minute + self.measurements.hourEnd) / 2) - (dotsWidth/2)

	-- y position of dots is midpoint of where minute digit starts and ends,
	-- minus half the height of the dots themselves
	local dotsy = ((minStartY + (minStartY + minHeight)) / 2) - (dotsHeight/2)
	self.dots:blit(self.bg, dotsx, dotsy)

	-- Draw AM PM
	local ampm = os.date("%p")
	local ampmSrf = Surface:drawText(self.ampmfont, self.ampmfont_color, ampm)
	local ampmw, ampmh = ampmSrf:getSize()
			
	local ampmy = y + CLOCKY + 5
	if ampm == "PM" then
		ampmy = ampmy + ampmh + 3
	end

	ampmSrf:blit(self.bg, self.measurements.ampm, ampmy)

end


function DigitalDetailed:Draw24HTime(x, y, bw, bh)

	-- Draw Hour

	-- Snip of leading 0
	local theHour = string.gsub(os.date("%H"), "^0", "", 1)

	local hourSrf = Surface:drawText(self.mainfont, self.mainfont_color, theHour)
	local hw, hh = hourSrf:getSize()

	-- Make sure the position is correct for hours below 10
	if(tonumber(theHour) < 10) then
		hourSrf:blit(self.bg, self.measurements.hour + self.measurements.digitwidth, y + CLOCKY)			
	else 
		hourSrf:blit(self.bg, self.measurements.hour, y + CLOCKY)			
	end

	-- Draw Minute
	local theMinute = os.date("%M")
	local minSrf = Surface:drawText(self.mainfont, self.mainfont_color, theMinute)
	minSrf:blit(self.bg, self.measurements.minute, y + CLOCKY)

end

function DigitalDetailed:Draw(force)
	local theTime = os.date("%H:%M:%S")

	if theTime != self.oldtime or force then
		self.oldtime = theTime

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


		if self.show_ampm then
			self:DrawAMPMTime(x, y, bw, bh)
		else
			self:Draw24HTime(x, y, bw, bh)
		end

		-- Draw Date
		local theDate = os.date(datetime:getDateFormat())
		local dateSrf = Surface:drawText(self.datefont, self.datefont_color, theDate)

		local dw, dh = dateSrf:getSize()
	
		dateSrf:blit(self.bg, x + ((bw/2) - (dw/2)), y + DATEY)

		self.bgicon:reDraw()
	end
end
	
local PADDINGX = 6
local PADDINGY = 10 

local DAYFIXY = 2

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

		local dayw, dayh = daySrf:getSize()

		daySrf:blit(self.bg, newx + ((dw/2)-(dayw/2)), y + bh - (dh + PADDINGY) + ((dh/2)-(dayh/2)) + DAYFIXY)

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

	elseif type == "simple" then

		pname = self:getSettings()["digitalsimple_preset"]
		if pname == "White" then
			return DigitalSimple_Presets.White
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

function openDigitalClock(self)
	return self:_openScreensaver("simple")
end

function openStyledClock(self)
	return self:_openScreensaver("styled")
end

function openDetailedClock(self)
	return self:_openScreensaver("detailed")
end


function _openScreensaver(self, type)
	local window = Window("Clock")

	-- Global Date/Time Settings
	local dt = datetime

	local hours      = dt:getHours() 
	local weekstart  = dt:getWeekstart()

	local preset = self:getPreset(type)

	if hours == "12" then
		hours = true
	else
		hours = false
	end

	local clock = nil;	
	log:info("Type: " .. type)
	if type == "simple" then
		clock = DigitalSimple(window, preset, hours)
	elseif type == "styled" then
		-- This clock always uses 24 hours mode for now
		clock = DigitalStyled(window, preset, hours)
	elseif type == "detailed" then
		clock = DigitalDetailed(window, preset, hours, weekstart)
	elseif type == "analog" then
		clock = Analog(window, preset)
	end

	clock:Draw()
	
	-- close the window on left
	window:addListener(EVENT_KEY_PRESS,
			   function(evt)
				   if evt:getKeycode() == KEY_BACK then
					   window:hide()
					   return EVENT_CONSUME
				   end
			   end)

	window:addListener(EVENT_WINDOW_RESIZE,
			   function(evt)
				if clock != nil then
					local w, h = Framework:getScreenSize()
					clock:Resize(w, h)
				end
			   end)

	window:addTimer(1000,
		function(evt)
			if clock != nil then
				clock:Tick()
			end
		end
	)

	self:tieAndShowWindow(window)
	return window
end

function skin(self, s)
	s.clock.layout = Window.noLayout
end

