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

module(...)
oo.class(_M, Applet)


function displayName(self)
	return "Clock"
end

-----------------------------------------------------------------------------------------
-- Settings
--

local Analog_Presets = {
	Ruby = {
		HighlightColor = 0x660000FF,
		HighlightImage = "clock_watch_bkgrd_ruby.png",
		BackgroundColor = 0x000000FF,
	},
	Teal = {
		HighlightColor = 0x004444FF,
		HighlightImage = "clock_watch_bkgrd_teal.png",
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

local DigitalDetailed_Presets = {
	Default = {
		Fonts = {
			Main = {
				Size = 45,
				Color = 0xFFFFFFFF
			},
			Days = {
				Size = 14,
				SelectedColor = 0xFFFFFFFF,
				Color = 0x373737FF
			},
			AMPM = {
				Size = 14,
				Color = 0xFFFFFFFF
			},
			Date = {
				Size = 14,
				Color = 0x373737FF
			}
		},
		Background = 0x000000FF,
		FirstDayInWeek = "Sunday",
		DateFormat = "%B %d, %Y"
	}
}

local DateFormats = {
	"%a, %B %d %Y",
	"%a, %d. %B %Y",
	"%D"
}

function openSettings(self, menuItem)
	local window = Window(self:displayName(), menuItem.text)

	local curFontStyle = 1 
	if self:getSettings()["digital_italic"] then
		curFontStyle = 2
	end

	local curHours = 1
	if self:getSettings()["hours"] == "24" then
		curHours = 2
	end

	window:addWidget(SimpleMenu("menu",
			{
				{
					text = self:string("SCREENSAVER_CLOCK_TYPE"), 
					callback = function(event, menuItem)
							self:clockTypeSetting(menuItem):show()
							return EVENT_CONSUME
						end
				},
				{
					text = self:string("SCREENSAVER_CLOCK_DATETIMEFORMAT"),
					callback = function(event, menuItem)
							self:timeFormatSetting(menuItem):show()
							return EVENT_CONSUME
						end
				},
				{
					text = self:string("SCREENSAVER_CLOCK_FONTSTYLE"),
					icon = Choice("choice", { "Plain", "Italic" },
						function(obj, selectedIndex) 
							self:setFontStyle(selectedIndex)	
						end,
						curFontStyle
					)
				},
			}))

	-- Store the applet settings when the window is closed
	window:addListener(EVENT_WINDOW_POP,
		function()
			self:storeSettings()
		end
	)
        
	return window
end

function timeFormatSetting(self, menuItem)
	local window = Window(self:displayName(), menuItem.text)

	local curHours = ""
	if self:getSettings()["hours"] == 12 then
		curHours = 1
	else
		curHours = 2
	end

	local curWeekStart
	if self:getSettings()["weekstart"] == "Monday" then
		curWeekStart = 2
	else
		curWeekStart = 1
	end

	window:addWidget(SimpleMenu("menu",
		{
			{	
				text = self:string("SCREENSAVER_CLOCK_AMPM24"),
				icon = Choice("choice", { "AM/PM", "24h" },
					function(obj, selectedIndex)
						self:setHours(selectedIndex)
					end,
					curHours
				)
			},
			{
				text = self:string("SCREENSAVER_CLOCK_DATEFORMAT"),
				callback = function(event, menuItem)
						self:dateFormatSetting(menuItem):show()
						return EVENT_CONSUME
					end
			},
			{
				text = self:string("SCREENSAVER_CLOCK_WEEKSTART"),
				icon = Choice("choice", { self:string("SCREENSAVER_CLOCK_SUNDAY"), self:string("SCREENSAVER_CLOCK_MONDAY") },
					function(event, menuItem)
						self:setWeekStart(selectedIndex)
					end,
					curWeekStart
				)
			},
		}
	))

	return window
end

function clockTypeSetting(self, menuItem)
	local window = Window(self:displayName(), menuItem.text)
	local group = RadioGroup()

	local type = self:getSettings()["clocktype"]

	window:addWidget(SimpleMenu("menu",
		{
			{
				text = self:string("SCREENSAVER_CLOCK_STYLE_ANALOG"),
				icon = RadioButton("radio", group, function(event, menuItem) 
						self:setClockType("analog:simple")
					end, 
				type == "analog:simple")
			},
			{
				text = self:string("SCREENSAVER_CLOCK_STYLE_DIGITALSIMPLE"),
				icon = RadioButton("radio", group, function(event, menuItem) 
						self:setClockType("digital:simple")
					end, 
				type == "digital:simple")
			},
			{
				text = self:string("SCREENSAVER_CLOCK_STYLE_DIGITALSTYLED"),
				icon = RadioButton("radio", group, function(event, menuItem) 
						self:setClockType("digital:styled")
					end, 
				type == "digital:styled")
			},
			{
				text = self:string("SCREENSAVER_CLOCK_STYLE_DIGITALDETAILED"),
				icon = RadioButton("radio", group, function(event, menuItem)
						self:setClockType("digital:detailed")
					end,
				type == "digital:detailed")
			}
		}
	))
	

	return window
end

function dateFormatSetting(self, menuItem)
	local window = Window(self:displayName(), menuItem.text)
	local group = RadioGroup()

	local current = self:getSettings()["dateformat"]
	log:info(current)

	window:addWidget(SimpleMenu("menu",
		{
			{
				text = os.date(DateFormats[1]),
				icon = RadioButton("radio", group, function(event, menuItem)
						self:setDateFormat(DateFormats[1])
					end,
				current == DateFormats[1])
			},
			{
				text = os.date(DateFormats[2]),
				icon = RadioButton("radio", group, function(event, menuItem)
						self:setDateFormat(DateFormats[2])
					end,
				current == DateFormats[2])
			},
			{
				text = os.date(DateFormats[3]),
				icon = RadioButton("radio", group, function(event, menuItem)
						self:setDateFormat(DateFormats[3])
					end,
				current == DateFormats[3])
			}
		}
	))

	return window
end

function setDateFormat(self, format)
	self:getSettings()["dateformat"] = format
end

function setClockType(self, type)
	self:getSettings()["clocktype"] = type
end

function setWeekStart(self, index)
	if index == 1 then
		self:getSettings()["weekstart"] = "Sunday"
	else 
		self:getSettings()["weekstart"] = "Monday"
	end
end

function setHours(self, index)
	if index == 1 then
		self:getSettings()["hours"] = "12"
	else 
		self:getSettings()["hours"] = "24"
	end
end

function setFontStyle(self, index)
	if index == 1 then
		self:getSettings()["digital_italic"] = false
	else
		self:getSettings()["digital_italic"] = true
	end
end

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

	-- Default Date Format
	obj.date_format = DateFormats[1]

	obj:_createSurface()

	return obj
end

function Clock:setDateFormat(f)
	obj.date_format = f
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
	obj.pointer_hour = Surface:loadImage("applets/Clock/HourPointer.png")
	obj.pointer_minute = Surface:loadImage("applets/Clock/MinutePointer.png")

	obj.clockhighlight = Surface:loadImage("applets/Clock/" .. preset.HighlightImage)
	obj.bgcolor = preset.BackgroundColor

	obj.oldtime = ""

	--obj:_setupHighlight()

	return obj
end

--[[
-- Dynamic Highlight is replaced by images
--
function Analog:_setupHighlight()

	local w = 240
	local h = 240
	local hlbg = Surface:newRGBA(w, h)

	-- Kill Alpha Channel
	local c = self.color >> 1
	c = c << 1
	c = c + 0x30


	local r = h/3
	
	local cycle  = (0xFF - 0x30) / (r - 5)

	local STEP = 2 
	while r > 5 do

		hlbg:filledCircle(w/2, h/2, r, c)

		log:info("R: " .. (c&0xFF000000) >> 24)
		log:info("G: " .. (c&0x00FF0000) >> 16)
		log:info("B: " .. (c&0x0000FF00) >> 8)
		log:info("Alpha: " .. c & 0xFF)

		r = r - STEP
		c = c + (cycle*STEP) 
		c = math.floor(c)
	end

	self.clockhighlight = hlbg	
end
]]--


function Analog:Draw(force)

	local theTime = os.date(self.clock_format)
	if theTime != self.oldtime or (force != nil and force == true) then

		self.oldtime = theTime

		-- Draw Background
		local bgImage = Framework:getBackground()
		bgImage:blit(self.bg, 0, 0)
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
		local h = os.date("%l")

		-- Minute Pointer
		local angle = (360 / 60) * m

		local tmp = self.pointer_minute:rotozoom(-angle, 1, 5)
		local facew, faceh = tmp:getSize()
		x = math.floor((self.screen_width/2) - (facew/2))
		y = math.floor((self.screen_height/2) - (faceh/2))
		tmp:blit(self.bg, x, y)
	
		-- Hour Pointer
		local angle = (360 / 12) * (h + (m/60))

		local tmp = self.pointer_hour:rotozoom(-angle, 1, 5)
		local facew, faceh = tmp:getSize()
		x = math.floor((self.screen_width/2) - (facew/2))
		y = math.floor((self.screen_height/2) - (faceh/2))
		tmp:blit(self.bg, x, y)

		Framework:reDraw(nil)
	end

end

DigitalSimple = oo.class({}, Clock)

function DigitalSimple:__init(window, preset, ampm, italic)
	log:info("Init Digital Simple")
	
	local fontname = "fonts/Digital.ttf"

	if italic != nil and italic == true then
		fontname = "fonts/DigitalItalic.ttf"
		--fontname = "/Users/bklaas/trunk/jive/build/osx/share/jive/fonts/DigitalItalic.ttf"
		log:warn(fontname)
	end

	obj = oo.rawnew(self, Clock(window))

	obj.color = preset.Color
	obj.bgcolor = preset.Background
	obj.font = Font:load(fontname, preset.FontSizes.Main)
	obj.ampmfont = Font:load(fontname, preset.FontSizes.AMPM)
	obj.datefont = Font:load(fontname, preset.FontSizes.Date)
	obj.oldtime = ""
	obj.show_ampm = ampm

	if ampm then 
		obj.clock_format = "%l:%M"
	else
		obj.clock_format = "%H:%M"
	end

	return obj;
end

function DigitalSimple:Draw(force)
	local theTime = os.date(self.clock_format)

	if theTime != self.oldtime or (force != nil and force == true) then

		self.oldtime = theTime

		local timeSrf = Surface:drawText(self.font, self.color, theTime)	

		local ampmSrf = nil
		local ampmWidth, ampmHeight = 0
		if self.show_ampm then
			ampmSrf = Surface:drawText(self.ampmfont, self.color, os.date("%p"))
			ampmWidth, ampmHeight = ampmSrf:getSize()
		end

		local dateSrf = Surface:drawText(self.datefont, self.color, os.date(self.date_format))

		local tw, th = timeSrf:getSize()

		local x
		if self.show_ampm then
			x = math.floor((self.screen_width/2) - ((tw+ampmWidth)/2))
		else
			x = math.floor((self.screen_width/2) - (tw/2))
		end

		local y = math.floor((self.screen_height/2) - (th/2))

		local bgImage = Framework:getBackground()
		bgImage:blit(self.bg, 0, 0)
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

		Framework:reDraw(nil)
	end
end

DigitalStyled = oo.class({}, Clock)

function DigitalStyled:__init(window, preset, ampm)
	log:info("Init Digital Simple")

	obj = oo.rawnew(self, Clock(window))

	obj.color = preset.Color
	obj.bgcolor = preset.Background
	obj.font = Font:load("fonts/04B_24__.TTF", preset.FontSize)

	-- obj.smallfont = Font:load("fonts/Digital.ttf", 40)

	obj.oldtime = ""
	obj.show_ampm = ampm

	if ampm then
		obj.clock_format_hour = "%l"
	else
		obj.clock_format_hour = "%H"
	end
	obj.clock_format_minute = "%M"

	return obj;
end

function DigitalStyled:Draw(force)
	local theTime = os.date("%H:%M")

	if theTime != self.oldtime or (force != nil and force == true) then

		self.oldtime = theTime

		theTime = os.date(self.clock_format_hour)
		local timeSrfHour = Surface:drawText(self.font, self.color, theTime)

		theTime = os.date(self.clock_format_minute)
		local timeSrfMin = Surface:drawText(self.font, self.color, theTime)	

		local timeSrfAmPm
		if self.show_ampm then
			theTime = os.date("%p")
			timeSrfAmPm = Surface:drawText(self.smallfont, self.color, theTime)
		end

		local tw, th = timeSrfHour:getSize()
	
		-- th correction
		th = th - 25

		local x = math.floor((self.screen_width/2) - (tw/2))
		local y = math.floor((self.screen_height/2) - (th))

		local bgImage = Framework:getBackground()
		bgImage:blit(self.bg, 0, 0)
		self.bg:filledRectangle(0, 0, self.screen_width, self.screen_height, self.bgcolor)
		timeSrfHour:blit(self.bg, x, y)
		timeSrfMin:blit(self.bg, x, y+th)

		if timeSrfAmPm then
			local offset = 15
			if os.date("%p") == "PM" then
				local dummy, h = timeSrfAmPm:getSize()
				offset = offset + h
			end
			timeSrfAmPm:blit(self.bg, x+tw+5, y+th+offset)
		end

		Framework:reDraw(nil)
	end
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

	obj.mainborder = Surface:loadImage("applets/Clock/clock_analog1_bkgrd.png")
	obj.daysborder = Surface:loadImage("applets/Clock/weekday_frame.png")

	obj.weekstart = preset.FirstDayInWeek
	if firstday != nil then
		obj.weekstart = firstday
	end

	obj.date_format = preset.DateFormat

	obj.oldtime = ""
	obj.show_ampm = ampm

	if ampm then 
		obj.clock_format = "%l:%M"
	else
		obj.clock_format = "%H:%M"
	end

	return obj;
end

local CLOCKY = 45
local DATEY = 90

function DigitalDetailed:Draw(force)
	local theTime = os.date("%H:%M:%S")

	if theTime != self.oldtime or (force != nil and force == true) then

		self.oldtime = theTime

		-- Draw Background
		local bgImage = Framework:getBackground()
		bgImage:blit(self.bg, 0, 0)
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

		-- Draw Hour
		local theHour = ""
		if self.show_ampm then
			theHour = os.date("%l")
		else
			theHour = os.date("%H")
		end

		local hourSrf = Surface:drawText(self.mainfont, self.mainfont_color, theHour)
		local hw, hh = hourSrf:getSize()

		hourSrf:blit(self.bg, x + 58 - hw, y + CLOCKY)			

		-- Draw Minute
		local theMinute = os.date("%M")
		local minSrf = Surface:drawText(self.mainfont, self.mainfont_color, theMinute)
		minSrf:blit(self.bg, x + 70, y + CLOCKY)


		-- Draw Second
		local theSecond = os.date("%S")
		local secSrf = Surface:drawText(self.mainfont, self.mainfont_color, theSecond)
		secSrf:blit(self.bg, x + 130, y + CLOCKY)

		-- Draw Date
		local theDate = os.date(self.date_format)
		local dateSrf = Surface:drawText(self.datefont, self.datefont_color, theDate)

		local dw, dh = dateSrf:getSize()
	
		dateSrf:blit(self.bg, x + ((bw/2) - (dw/2)), y + DATEY)
		

		-- Draw AM PM
		if self.show_ampm == true then

			local ampm = os.date("%p")
			local ampmSrf = Surface:drawText(self.ampmfont, self.ampmfont_color, ampm)
			local ampmw, ampmh = ampmSrf:getSize()
			
			local ampmy = y + CLOCKY + 5
			if ampm == "PM" then
				ampmy = ampmy + ampmh + 3
			end

			ampmSrf:blit(self.bg, x + bw - (10 + ampmw), ampmy)
		end

		Framework:reDraw(nil)
	end
end
	
local PADDINGX = 28 
local PADDINGY = 10 

local DAYFIXY = 2 

local DAYS_SUN = { "S", "M", "T", "W", "T", "F", "S" }
local DAYS_MON = { "M", "T", "W", "T", "F", "S", "S" }

function DigitalDetailed:DrawWeekdays(x, y, bw, bh, day)

	local dw, dh = self.daysborder:getSize()	

	local days = DAYS_SUN
	if self.weekstart == "Monday" then
		days = DAYS_MON
	end

	local i = 0
	while i < 7 do

		local newx = x + (i*dh) + PADDINGX
		self.daysborder:blit(self.bg, newx, y + PADDINGY)

		local c = self.daysfont_color
		if i == tonumber(day) then
			c = self.daysfont_scolor
		end

		local daySrf = Surface:drawText(self.daysfont, c, days[i+1])

		local dayw, dayh = daySrf:getSize()

		daySrf:blit(self.bg, newx + ((dw/2)-(dayw/2)), y + PADDINGY + ((dh/2)-(dayh/2)) + DAYFIXY)

		i = i + 1
	end
end

function getPreset(self, type)
	local pname = ""
	
	if type == "analog:simple" then
		return Analog_Presets.Default
	elseif type == "digital:styled" then

		pname = self:getSettings()["digitalstyled_preset"]
		if pname == "Green" then 
			return DigitalStyled_Presets.Green;
		elseif pname == "White" then
			return DigitalStyled_Presets.White;
		else 
			return nil
		end

	elseif type == "digital:simple" then

		pname = self:getSettings()["digitalsimple_preset"]
		if pname == "White" then
			return DigitalSimple_Presets.White
		else
			return nil
		end
	elseif type == "digital:detailed" then
		return DigitalDetailed_Presets.Default
	else
		return nil
	end

end

function openScreensaver(self, menuItem)
	local window = Window("Clock")

	local type       = self:getSettings()["clocktype"]
	local italic     = self:getSettings()["digital_italic"]
	local hours      = self:getSettings()["hours"]
	local dateformat = self:getSettings()["dateformat"] 
	local weekstart  = self:getSettings()["weekstart"]

	local preset = self:getPreset(type)

	if hours == "12" then
		hours = true
	else
		hours = false
	end

	local clock = nil;	
	log:info("Type: " .. type)
	if type == "digital:simple" then
		clock = DigitalSimple(window, preset, hours, italic)
		clock:setDateFormat(dateformat)
	elseif type == "digital:styled" then
		-- This clock always uses 24 hours mode for now
		clock = DigitalStyled(window, preset, false)
	elseif type == "digital:detailed" then
		clock = DigitalDetailed(window, preset, hours, weekstart)
	elseif type == "analog:simple" then
		clock = Analog(window, preset)
	end

	clock:Draw()
	
	-- close the window on left
	window:addListener(EVENT_KEY_PRESS,
			   function(evt)
				   if evt:getKeycode() == KEY_BACK then
					   window:hide()
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

	return window
end

function skin(self, s)
	s.clock.layout = Window.noLayout
end

