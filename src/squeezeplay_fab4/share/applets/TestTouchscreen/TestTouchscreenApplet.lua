
local assert, getmetatable, ipairs, pcall, setmetatable, tonumber, tostring = assert, getmetatable, ipairs, pcall, setmetatable, tonumber, tostring

local string              = require("string")
local table               = require("jive.utils.table")
local io                  = require("io")
local math                = require("math")
local oo                  = require("loop.simple")
local debug               = require("jive.utils.debug")
local os                  = require("os")

local Label               = require("jive.ui.Label")
local Applet              = require("jive.Applet")
local Window              = require("jive.ui.Window")
local Surface             = require("jive.ui.Surface")
local Icon                = require("jive.ui.Icon")
local Framework           = require("jive.ui.Framework")
local Popup               = require("jive.ui.Popup")
local Textarea            = require("jive.ui.Textarea")

local FRAME_RATE          = jive.ui.FRAME_RATE

module(..., Framework.constants)
oo.class(_M, Applet)


function init(self)
	self.spot = {}
	self.update = false
	
	self.pathHistory = {}
	self.pathFail = 0x00
end


local test = 1
--local test = 4
local stage = 1
local counter = 0
local pathHistory = {}
local pathFail = 0x00


function popupWindow(self, text)
	local popup = Window("text_list")
	local text = Textarea("text", text)
	popup:addWidget(text)
	self:tieWindow(popup)

	popup:showBriefly(2000, function() self.window:hideToTop() end)

	return popup
end

function point(x, y)
	return { x = x, y = y }
end

function circle(x, y, r)
	return { x = x, y = y, r = r }
end

local pointType = { inbounds = 0, outbounds = 1, up = 2, gap = 4 } 

function pointc(x, y, t, ptype)
	return { x = x, y = y, t = t, ptype = ptype }
end


function round(num, idp)
	local mult = 10^(idp or 0)
	return math.floor(num * mult + 0.5) / mult
end


function _drawWayPoint(self, c, color)
	self.canvas:aacircle( c.x, c.y, c.r, color)
	self.canvas:circle( c.x, c.y, c.r+1, color)	    
	self.canvas:circle( c.x, c.y, c.r+2, color)
end    

function _fillWayPoint(self, c, color)
	self.canvas:filledCircle( c.x, c.y, c.r, color)
end

function _drawArrow(self, p1, p2, color) 

	local width = 20
	local theta = math.pi/4
	local vector = point(x,y)
	local normal = point(x,y)
	local base = point(x,y)
	local length
	local th
	local ta
	local poly = {point(0,0), point(0,0), point(0,0), point(0,0) }

	poly[1].x = p2.x
	poly[1].y = p2.y

	vector.x = p2.x-p1.x
	vector.y = p2.y-p1.y
	normal.x = -vector.y
	normal.y = vector.x

	length = math.sqrt((vector.x * vector.x) + (vector.y * vector.y))

	th = width / (2 * length)
	ta = width / (2 * ( math.atan(theta)/ 2) * length)
	
	base.x = poly[1].x - ta * vector.x
	base.y = poly[1].y - ta * vector.y
	poly[2].x = base.x + th * normal.x
	poly[2].y = base.y + th * normal.y
	poly[3].x = base.x - th * normal.x
	poly[3].y = base.y - th * normal.y

	self.canvas:line( p1.x, p1.y, base.x, base.y, color )
	self.canvas:line( base.x, base.y, poly[2].x, poly[2].y, color )
	self.canvas:line( poly[2].x, poly[2].y, poly[1].x, poly[1].y, color )
	self.canvas:line( poly[1].x, poly[1].y, poly[3].x, poly[3].y, color )
	self.canvas:line( poly[3].x, poly[3].y, base.x, base.y, color )
end

function _cArrow(self, c1, c2, color)
	local p1 = point(x,y)
	local p2 = point(x,y)
	local vector = point(x,y)
	local sign = 1
	local m = 1

	vector.x = c2.x-c1.x
	vector.y = c2.y-c1.y

	if vector.x == 0 then
		m = math.pi / 2
	else
		m = vector.y / vector.x
	end	

	if vector.y < 0 then
		sign = -sign
	end

	if vector.x < 0 then
		sign = -sign
	end
	
	p1.x = c1.x + sign * ((c1.r + 10) * math.cos(m))
	p1.y = c1.y + sign * ((c1.r + 10) * math.sin(m))
	p2.x = c2.x - sign * ((c2.r + 10) * math.cos(m))
	p2.y = c2.y - sign * ((c2.r + 10) * math.sin(m))

	self:_drawArrow(p1, p2, color)
end

function _definePath(self, c1, c2)
	local p1 = point(x,y)
	local p2 = point(x,y)
	local p3 = point(x,y)
	local p4 = point(x,y)
	local p5 = point(x,y)
	local p6 = point(x,y)
	local vector = point(x,y)
	local normal = point(x,y)
	local sign = 1
	local m = 1
	local n = 1

	vector.x = c2.x-c1.x
	vector.y = c2.y-c1.y
	normal.x = -vector.y
	normal.y = vector.x

	if vector.x == 0 then
		m = math.pi / 2
		n = math.pi / 2
	else
		m = vector.y / vector.x
		n = normal.x / normal.y
	end	

	if vector.y < 0 then
		sign = -sign
	end

	if vector.x < 0 then
		sign = -sign
	end

	p1.x = round(c1.x - sign * (c1.r * math.sin(n)))
	p1.y = round(c1.y - sign * (c1.r * math.cos(n)))
	p2.x = round(c2.x - sign * (c2.r * math.sin(n)))
	p2.y = round(c2.y - sign * (c2.r * math.cos(n)))
	p3.x = round(c2.x + sign * (c2.r * math.cos(m)))
	p3.y = round(c2.y + sign * (c2.r * math.sin(m)))

	p4.x = round(c2.x + sign * (c2.r * math.sin(n)))
	p4.y = round(c2.y + sign * (c2.r * math.cos(n)))
	p5.x = round(c1.x + sign * (c1.r * math.sin(n)))
	p5.y = round(c1.y + sign * (c1.r * math.cos(n)))
	p6.x = round(c1.x - sign * (c1.r * math.cos(m)))
	p6.y = round(c1.y - sign * (c1.r * math.sin(m)))

	return p1, p2, p3, p4, p5, p6
end


-- Should replace _inCircle and _inPolygon with _inMask defined by a region mask

function _inCircle(self, s, c) 

	if not s.x then
		return false
	end
	
	local vx = s.x - c.x
	local vy = s.y - c.y
	
	if ((math.sqrt((vx * vx) + (vy * vy))) < c.r ) then
		return true
	end
	
	return false
end

function _inPolygon(self, s, p)

	local xnew, ynew, xold, yold
	local x1, y1, x2, y2, i
	local inside = false
	local j = #p
	local x = s.x
	local y = s.y

	if (j < 3) then
		return false
	end

	xold = p[j].x
	yold = p[j].y

	for i=1,j,1 do
		xnew = p[i].x
		ynew = p[i].y
		
		if (xnew > xold) then
			x1 = xold
			x2 = xnew
			y1 = yold
			y2 = ynew
		else
			x1 = xnew
			x2 = xold
			y1 = ynew
			y2 = yold
		end

		if (((xnew <= x) == (x < xold)) and (((y-y1) * (x2-x1)) < ((y2-y1) * (x-x1)))) then
			inside = not inside	
		end
		
		xold = xnew
		yold = ynew
	end

	return inside
end

function _drawTarget(self, spot, offset, r, col)

	local x = spot.x + (offset * r)
	local y = spot.y

	-- target
	self.canvas:circle(x, y, r, col)
	self.canvas:hline(x - r, x + r, y, col)
	self.canvas:vline(x, y - r, y + r, col)
end

function _drawSpot(self, spot)

	if not spot.x then
		return
	end

	local r = 32
	local col = 0xffffffff

	if spot.width == nil then
		col = 0x6f6f6fff
	else
		-- width, pressure
		self.canvas:filledCircle(spot.x, spot.y, (r / 2) + (spot.width / 32) * r, ((spot.pressure << 8) | 0xFF))
	end

	if self.spot.fingers == 2 then
		self:_drawTarget(spot, -1, r, col)
		self:_drawTarget(spot, 1, r, col)
	else
		self:_drawTarget(spot, 0, r, col)
	end
end

function _drawPathHistory(self)

	local color

	for i=1,#pathHistory,1 do

		if pathHistory[i].ptype == pointType.inbounds then
			color = 0x00FF00FF
--			self.canvas:pixel(pathHistory[i].x, pathHistory[i].y, color)
			self.canvas:filledCircle(pathHistory[i].x, pathHistory[i].y, 1, color)

		elseif pathHistory[i].ptype == pointType.outbounds then
			color = 0xFF0000FF
			self.canvas:filledCircle(pathHistory[i].x, pathHistory[i].y, 3, color)

		elseif pathHistory[i].ptype == pointType.up then
			color = 0xFFFF00FF
			self.canvas:filledCircle(pathHistory[i].x, pathHistory[i].y, 5, color)

		elseif pathHistory[i].ptype == pointType.gap then

			local color = 0xFF8888FF
			local pt1 = pathHistory[i]
			local pt2 = pathHistory[i-1]

			self.canvas:line( pt1.x-1, pt1.y-1, pt2.x-1, pt2.y-1, color )
			self.canvas:line( pt1.x,   pt1.y,   pt2.x,   pt2.y,   color )
			self.canvas:line( pt1.x+1, pt1.y+1, pt2.x+1, pt2.y+1, color )
		end
	end
end

function _checkPathProgress(self)

	local k = #pathHistory

	if k >= 2 then
	
		local pt1 = pathHistory[k]
		local pt2 = pathHistory[k-1]

		local x = pt1.x - pt2.x
		local y = pt1.y - pt2.y
	
		if (math.sqrt((x * x) + (y * y))) > 40 then
			pathHistory[k].ptype = pointType.gap
			pathFail = pathFail | (0x01 << test)
		end			

		if (pt1.t-pt2.t) > 200 then
			log:info("Jump t: ", pt1.t-pt2.t)
			--pathFail = pathFail | (0x01 << test)
		end
	end

end


function _drawTestPattern(self, spot)
	
	local col1 = 0x999999FF
	local col2 = 0xEEEE22FF
	local colG = 0x44FF44FF

	local h = self.h
	local w = self.w

	-- top left to bottom right 
	if test == 1 then

		local c1 = circle(20,20,20)
		local c2 = circle(w-20,h-20,20)

		-- highlight first target
		if stage == 1 then
		        self:_drawWayPoint(c1,col2)
			self:_cArrow(c1,c2,col1)
			self:_drawWayPoint(c2, col1)

			if self:_inCircle(spot,c1) then
				stage = stage + 1
				pathHistory = {}
			end

		-- first target pressed, flag first circle
		-- hightlight arrow and second circle
		-- draw finger path
		elseif stage == 2 then

		        self:_fillWayPoint(c1,colG)
			self:_cArrow(c1,c2,col2)
			self:_drawWayPoint(c2, col2)
			self:_drawPathHistory()
			self:_checkPathProgress()

			local p1, p2, p3, p4, p5, p6 = self:_definePath(c1,c2)

			self.canvas:line( p1.x, p1.y, p2.x, p2.y, col2)
			self.canvas:line( p4.x, p4.y, p5.x, p5.y, col2)

			-- check for out-of-bounds event of flight path
  			if self:_inPolygon(spot, {p1, p2, p3, p4, p5, p6, p1} ) then
				pathHistory[#pathHistory+1] = pointc(spot.x, spot.y, spot.t, pointType.inbounds)
			else
				pathHistory[#pathHistory+1] = pointc(spot.x, spot.y, spot.t, pointType.outbounds)
				--log:info("TouchPad: Out of flight path : (",spot.x,",",spot.y,",",spot.t,")")
				pathFail = pathFail | (0x01 << test)
			end

			if( spot.m == pointType.up ) then
				local i = #pathHistory
				pathHistory[i+1] = pointc(pathHistory[i].x, pathHistory[i].y, pathHistory[i].t, pointType.up)
				pathFail = pathFail | (0x01 << test)
			end

			-- wanted target
			if( self:_inCircle(spot,c2) ) then
				stage = stage + 1
			end

			-- first target, start over
			if( self:_inCircle(spot,c1) ) then
				-- reset
				if #pathHistory > 4 then
					stage = 1
					pathHistory = {}
					pathFail = pathFail & ~(0x01 << test)
				end
			end


    		-- second target reached
		-- display test pass
		elseif stage == 3 then
		        self:_fillWayPoint(c1,colG)
			self:_cArrow(c1,c2,colG)
			self:_fillWayPoint(c2, colG)
			self:_drawPathHistory()
			self:_checkPathProgress()
			    
			test = test + 1
			stage = 1
			counter = 0
			pathHistory = {}

		-- error occured and test failed
		-- give option to retest	
		elseif stage == 4 then
			-- error occured	
    		end
		
	-- top right to bottom left    
	elseif test == 2 then

		local c1 = circle(w-20,20,20)
		local c2 = circle(20,h-20,20)

		-- highlight first target
		if stage == 1 then
		        self:_drawWayPoint(c1,col2)
			self:_cArrow(c1,c2,col1)
			self:_drawWayPoint(c2, col1)

			if( self:_inCircle(spot,c1) ) then
				stage = stage + 1
				pathHistory = {}

			end

		-- first target pressed, flag first circle
		-- hightlight arrow and second circle
		-- draw finger path
		elseif stage == 2 then

		        self:_fillWayPoint(c1,colG)
			self:_cArrow(c1,c2,col2)
			self:_drawWayPoint(c2, col2)
			self:_drawPathHistory()
			self:_checkPathProgress()

			local p1, p2, p3, p4, p5, p6 = self:_definePath(c1,c2)

			self.canvas:line( p1.x, p1.y, p2.x, p2.y, col2)
			self.canvas:line( p4.x, p4.y, p5.x, p5.y, col2)

			-- check for out-of-bounds event of flight path
  			if self:_inPolygon(spot, {p1, p2, p3, p4, p5, p6, p1} ) then
				pathHistory[#pathHistory+1] = pointc(spot.x, spot.y, spot.t, pointType.inbounds)
			else
				pathHistory[#pathHistory+1] = pointc(spot.x, spot.y, spot.t, pointType.outbounds)
				--log:info("TouchPad: Out of flight path : (",spot.x,",",spot.y,",",spot.t,")");
				pathFail = pathFail | (0x01 << test)
			end

			if( spot.m == pointType.up ) then
				local i = #pathHistory
				pathHistory[i+1] = pointc(pathHistory[i].x, pathHistory[i].y, pathHistory[i].t, pointType.up)
				pathFail = pathFail | (0x01 << test)
			end

			-- wanted target
			if( self:_inCircle(spot,c2) ) then
				stage = stage + 1
			end

			-- first target, start over
			if( self:_inCircle(spot,c1) ) then
				-- reset
				if #pathHistory > 4 then
					stage = 1
					pathHistory = {}
					pathFail = pathFail & ~(0x01 << test)
				end
			end

    		-- second target reached
		-- display test pass
		elseif stage == 3 then
		        self:_fillWayPoint(c1,colG)
			self:_cArrow(c1,c2,colG)
			self:_drawWayPoint(c2, colG)
			self:_drawPathHistory()
			self:_checkPathProgress()
			    
			test = test + 1
			stage = 1
			counter = 0
			pathHistory = {}

		-- error occured and test failed
		-- give option to retest	
		elseif stage == 4 then
			-- error occured	
    		end


	-- four corners     
	elseif test == 3 then

		local c1 = circle(20,20,20)
		local c2 = circle(w-20,20,20)
		local c3 = circle(w-20,h-20,20)
		local c4 = circle(20,h-20,20)

		-- highlight first target
		if stage == 1 then
		        self:_drawWayPoint(c1, col2)
			self:_cArrow(c1,c2,col1)
			self:_drawWayPoint(c2, col1)
			self:_cArrow(c2,c3,col1)
			self:_drawWayPoint(c3, col1)
			self:_cArrow(c3,c4,col1)
			self:_drawWayPoint(c4, col1)
			self:_cArrow(c4,c1,col1)
			--self:_drawPathHistory()
			--self:_checkPathProgress()

			if( self:_inCircle(spot,c1) ) then
				stage = stage + 1
			end

		-- first target pressed, flag first circle
		-- hightlight arrow and second circle
		-- draw finger path
		elseif stage == 2 then

		        self:_drawWayPoint(c1, col1)
			self:_cArrow(c1,c2,col2)
			self:_drawWayPoint(c2, col2)
			self:_cArrow(c2,c3,col1)
			self:_drawWayPoint(c3, col1)
			self:_cArrow(c3,c4,col1)
			self:_drawWayPoint(c4, col1)
			self:_cArrow(c4,c1,col1)
			self:_drawPathHistory()
			self:_checkPathProgress()

			local p1, p2, p3, p4, p5, p6 = self:_definePath(c1,c2)

			self.canvas:line( p1.x, p1.y, p2.x, p2.y, col2)
			self.canvas:line( p4.x, p4.y, p5.x, p5.y, col2)

			-- check for out-of-bounds event of flight path
  			if self:_inPolygon(spot, {p1, p2, p3, p4, p5, p6, p1} ) then
				pathHistory[#pathHistory+1] = pointc(spot.x, spot.y, spot.t, pointType.inbounds)
			else
				pathHistory[#pathHistory+1] = pointc(spot.x, spot.y, spot.t, pointType.outbounds)
				--log:info("TouchPad: Out of flight path : (",spot.x,",",spot.y,",",spot.t,")");
				pathFail = pathFail | (0x01 << test)
			end

			if( spot.m == pointType.up ) then
				local i = #pathHistory
				pathHistory[i+1] = pointc(pathHistory[i].x, pathHistory[i].y, pathHistory[i].t, pointType.up)
				pathFail = pathFail | (0x01 << test)
			end

			-- wanted target
			if( self:_inCircle(spot,c2) ) then
				stage = stage + 1
			end

			-- first target, start over
			if( self:_inCircle(spot,c1) ) then
				-- reset
				if #pathHistory > 4 then
					stage = stage - 1
					pathHistory = {}
					pathFail = pathFail & ~(0x01 << test)
				end
			end


		-- second target pressed, flag first circle
		-- hightlight arrow and third circle
		-- draw finger path
		elseif stage == 3 then

		        self:_drawWayPoint(c1, col1)
			self:_cArrow(c1,c2,colG)
			self:_fillWayPoint(c2, colG)
			self:_cArrow(c2,c3,col1)
			self:_drawWayPoint(c3, col2)
			self:_cArrow(c3,c4,col1)
			self:_drawWayPoint(c4, col1)
			self:_cArrow(c4,c1,col1)
			self:_drawPathHistory()
			self:_checkPathProgress()

			local p1, p2, p3, p4, p5, p6 = self:_definePath(c2,c3)

			self.canvas:line( p1.x, p1.y, p2.x, p2.y, col2)
			self.canvas:line( p4.x, p4.y, p5.x, p5.y, col2)

			-- check for out-of-bounds event of flight path
  			if self:_inPolygon(spot, {p1, p2, p3, p4, p5, p6, p1} ) then
				pathHistory[#pathHistory+1] = pointc(spot.x, spot.y, spot.t, pointType.inbounds)
			else
				pathHistory[#pathHistory+1] = pointc(spot.x, spot.y, spot.t, pointType.outbounds)
				--log:info("TouchPad: Out of flight path : (",spot.x,",",spot.y,",",spot.t,")");
				pathFail = pathFail | (0x01 << test)
			end

			if( spot.m == pointType.up ) then
				local i = #pathHistory
				pathHistory[i+1] = pointc(pathHistory[i].x, pathHistory[i].y, pathHistory[i].t, pointType.up)
				pathFail = pathFail | (0x01 << test)
			end

			-- wanted target
			if( self:_inCircle(spot,c3) ) then
				stage = stage + 1
			end

			-- first target, start over
			if( self:_inCircle(spot,c1) ) then
				-- reset
				stage = 1;
				pathHistory = {}
				pathFail = pathFail & ~(0x01 << test)
			end

		-- third target pressed, flag second circle
		-- hightlight arrow and fourth circle
		-- draw finger path
		elseif stage == 4 then

		        self:_drawWayPoint(c1, col1)
			self:_cArrow(c1,c2,colG)
			self:_fillWayPoint(c2, colG)
			self:_cArrow(c2,c3,colG)
			self:_fillWayPoint(c3, colG)
			self:_cArrow(c3,c4,col2)
			self:_drawWayPoint(c4, col2)
			self:_cArrow(c4,c1,col1)
			self:_drawPathHistory()
			self:_checkPathProgress()

			local p1, p2, p3, p4, p5, p6 = self:_definePath(c3,c4)

			self.canvas:line( p1.x, p1.y, p2.x, p2.y, col2)
			self.canvas:line( p4.x, p4.y, p5.x, p5.y, col2)

			-- check for out-of-bounds event of flight path
  			if self:_inPolygon(spot, {p1, p2, p3, p4, p5, p6, p1} ) then
				pathHistory[#pathHistory+1] = pointc(spot.x, spot.y, spot.t, pointType.inbounds)
			else
				pathHistory[#pathHistory+1] = pointc(spot.x, spot.y, spot.t, pointType.outbounds)
				--log:info("TouchPad: Out of flight path : (",spot.x,",",spot.y,",",spot.t,")");
				pathFail = pathFail | (0x01 << test)
			end

			if( spot.m == pointType.up ) then
				local i = #pathHistory
				pathHistory[i+1] = pointc(pathHistory[i].x, pathHistory[i].y, pathHistory[i].t, pointType.up)
				pathFail = pathFail | (0x01 << test)
			end

			-- wanted target
			if( self:_inCircle(spot,c4) ) then
				stage = stage + 1
			end

			-- first target, start over
			if( self:_inCircle(spot,c1) ) then
				-- reset
				stage = 1;
				pathHistory = {}
				pathFail = pathFail & ~(0x01 << test)
			end


		-- fourth target pressed, flag third circle
		-- hightlight arrow and final circle
		-- draw finger path
		elseif stage == 5 then

		        self:_drawWayPoint(c1, col2)
			self:_cArrow(c1,c2,colG)
			self:_fillWayPoint(c2, colG)
			self:_cArrow(c2,c3,colG)
			self:_fillWayPoint(c3, colG)
			self:_cArrow(c3,c4,colG)
			self:_fillWayPoint(c4, colG)
			self:_cArrow(c4,c1,col2)
			self:_drawPathHistory()
			self:_checkPathProgress()

			local p1, p2, p3, p4, p5, p6 = self:_definePath(c4,c1)

			self.canvas:line( p1.x, p1.y, p2.x, p2.y, col2)
			self.canvas:line( p4.x, p4.y, p5.x, p5.y, col2)

			-- check for out-of-bounds event of flight path
  			if self:_inPolygon(spot, {p1, p2, p3, p4, p5, p6, p1} ) then
				pathHistory[#pathHistory+1] = pointc(spot.x, spot.y, spot.t, pointType.inbounds)
			else
				pathHistory[#pathHistory+1] = pointc(spot.x, spot.y, spot.t, pointType.outbounds)
				--log:info("TouchPad: Out of flight path : (",spot.x,",",spot.y,",",spot.t,")");
				pathFail = pathFail | (0x01 << test)
			end

			if( spot.m == pointType.up ) then
				local i = #pathHistory
				pathHistory[i+1] = pointc(pathHistory[i].x, pathHistory[i].y, pathHistory[i].t, pointType.up)
				pathFail = pathFail | (0x01 << test)
			end

			-- final target
			if( self:_inCircle(spot,c1) ) then
				stage = stage + 1
			end


    		-- final target reached
		-- display test pass
		elseif stage == 6 then
		        self:_fillWayPoint(c1, colG)
			self:_cArrow(c1,c2,colG)
			self:_fillWayPoint(c2, colG)
			self:_cArrow(c2,c3,colG)
			self:_fillWayPoint(c3, colG)
			self:_cArrow(c3,c4,colG)
			self:_fillWayPoint(c4, colG)
			self:_cArrow(c4,c1,colG)
			self:_drawPathHistory()
			self:_checkPathProgress()
			    
			test = test + 1
			stage = 1
			counter = 0
			pathHistory = {}

		-- error occured and test failed
		-- give option to retest	
		elseif stage == 7 then
			-- error occured	
    		end


	-- two finger test 
	elseif test == 4 then

		local c1 = circle(60,60,20)
		local c2 = circle(160,60,20)
		local c3 = circle(w-60,h-60,20)
		local c4 = circle(w-160,h-60,20)

		-- highlight first target
		if stage == 1 then
		        self:_drawWayPoint(c1,col2)
		        self:_drawWayPoint(c2,col1)
			self:_cArrow(c1,c4,col1)
			self:_drawWayPoint(c3, col1)
			self:_drawWayPoint(c4, col1)

			if( self:_inCircle(spot,c1) ) then
				stage = stage + 1
				pathHistory = {}
			end

		-- highlight second target
		elseif stage == 2 then
		        self:_drawWayPoint(c1,colG)
		        self:_drawWayPoint(c2,col2)
			self:_cArrow(c1,c4,col2)
			self:_drawWayPoint(c3, col1)
			self:_drawWayPoint(c4, col1)

			if( spot.fingers == 2 ) then
				stage = stage + 1
				pathHistory = {}
			end


		-- first target pressed, flag first circle
		-- hightlight arrow and second circle
		-- draw finger path
		elseif stage == 3 then
		        self:_drawWayPoint(c1,colG)
		        self:_drawWayPoint(c2,colG)
			self:_cArrow(c1,c4,col2)
			self:_drawWayPoint(c3, col2)
			self:_drawWayPoint(c4, col2)
			self:_drawPathHistory()
			self:_checkPathProgress()

			local p1, p2, p3, p4, p5, p6 = self:_definePath(c1,c4)

			self.canvas:line( p1.x, p1.y, p2.x, p2.y, col2)
			self.canvas:line( p4.x, p4.y, p5.x, p5.y, col2)

			-- check for out-of-bounds event of flight path
  			if self:_inPolygon(spot, {p1, p2, p3, p4, p5, p6, p1} ) then
				pathHistory[#pathHistory+1] = pointc(spot.x, spot.y, spot.t, pointType.inbounds)
			else
				pathHistory[#pathHistory+1] = pointc(spot.x, spot.y, spot.t, pointType.outbounds)
				--log:info("TouchPad: Out of flight path : (",spot.x,",",spot.y,",",spot.t,")");
				pathFail = pathFail | (0x01 << test)
			end

			if( spot.m == pointType.up ) then
				local i = #pathHistory
				pathHistory[i+1] = pointc(pathHistory[i].x, pathHistory[i].y, pathHistory[i].t, pointType.up)
				pathFail = pathFail | (0x01 << test)
			end

			-- wanted target
			if( self:_inCircle(spot,c4) ) then
				stage = stage + 1
			end

			-- first target, start over
			if( self:_inCircle(spot,c1) ) then
				-- reset
				if #pathHistory > 4 then
					stage = stage - 1
					pathHistory = {}
					pathFail = pathFail & ~(0x01 << test)
				end
			end

    		-- second target reached
		-- display test pass
		elseif stage == 4 then
		        self:_drawWayPoint(c1,colG)
		        self:_drawWayPoint(c2,colG)
			self:_cArrow(c1,c4,colG)
			self:_drawWayPoint(c3, colG)
			self:_drawWayPoint(c4, colG)
			self:_drawPathHistory()
			self:_checkPathProgress()
			    
			test = test + 1
			stage = 1
			counter = 0
			pathHistory = {}

		-- error occured and test failed
		-- give option to retest	
		elseif stage == 5 then
			-- error occured	
    		end

	-- test completed  
	else
		log:info("DisplayTest: TEST_COMPLETE")
		self:popupWindow(self:string("TEST_COMPLETE"))
	end
end


function _drawSpots(self)
	-- clear
	self.background:blit(self.canvas, 0, 0)

	if pathFail == 0x00 then
		self.background:filledRectangle(0, 0, self.w, self.h, 0x777777)
	else
		self.background:filledRectangle(0, 0, self.w, self.h, 0x771111FF)
	end
	self:_drawSpot(self.spot)

	self:_drawTestPattern(self.spot)

	-- update screen
	self.icon:reDraw()
end

function touchscreenTest(self)
	self.window = Window("text_list")

	self.w, self.h = Framework:getScreenSize()

	self.background = Surface:newRGB(self.w, self.h)
	self.background:filledRectangle(0, 0, self.w, self.h, 0x777777)

	self.canvas = Surface:newRGBA(self.w, self.h)
	self.icon = Icon("icon", self.canvas)	

	self.window:addWidget(self.icon)

	self:_drawSpots()

	self.window:addListener(EVENT_KEY_PRESS | EVENT_MOUSE_DRAG | EVENT_MOUSE_DOWN | EVENT_MOUSE_UP,
		function(event)
			local type = event:getType()
			self.spot.m = nil

			if type == EVENT_KEY_PRESS then
				if event:getKeycode() == KEY_BACK then
					self.window:hide()
					return EVENT_CONSUME
				end
			elseif type == EVENT_MOUSE_UP then
				self.spot.m = pointType.up
				self.spot.width = nil

				self.update = true
				
				return EVENT_CONSUME

			else -- MOUSE_DRAG or MOUSE_DOWN
				self.spot.x, self.spot.y, self.spot.fingers, self.spot.width, self.spot.pressure = event:getMouse()
				self.spot.t = Framework:getTicks()

				self.update = true

				return EVENT_CONSUME
			end
		end
	)

	self.icon:addAnimation(
		function()
			if self.update then
				self:_drawSpots()
				self.update = false
			end
		end, FRAME_RATE)

	self:tieAndShowWindow(self.window)
	return window
end


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]
