
--[[
=head1 NAME

applets.Snake.SnakeApplet - Snake Game

=head1 DESCRIPTION

Snake is a simple game for the Jive platform

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. SnakeApplet overrides the
following methods:

=cut
--]]


-- stuff we use
local ipairs, tostring = ipairs, tostring
local math, table = math, table

local oo               = require("loop.simple")

local Applet           = require("jive.Applet")
local Window           = require("jive.ui.Window")
local Surface          = require("jive.ui.Surface")
local Popup            = require("jive.ui.Popup")
local Icon             = require("jive.ui.Icon")
local Framework        = require("jive.ui.Framework")
local Audio	       = require("jive.ui.Audio")

local FRAMERATE        = 5
local BLOCKSIZE        = 8
local srf = nil
local window = nil
local w, h = Framework:getScreenSize()

local playField	       = {}
local snake            = {}
local border           = {}
local red_dots         = {}
local posX = 0
local posY = 0
local direction = jive.ui.KEY_UP
local score = 0
local length = 0
local lives = 3
local gameover = false

local minX = 1
local minY = 1
local maxX = math.floor(w / BLOCKSIZE) - 2
local maxY = math.floor((h-30) / BLOCKSIZE) - 2

local startX = math.floor(maxX / 2)
local startY = math.floor(maxY / 2)

local BORDER = 8
local POINT  = 1
local SNAKE  = 2

local MINLENGTH = 10
local pointSound = Framework:loadSound("applets/Snake/point.wav", 1)
local crashSound = Framework:loadSound("applets/Snake/crash.wav", 1)
local labelStatus = nil

module(..., Framework.constants)
oo.class(_M, Applet)

function displayName(self)
	return "Snake"
end

function addRandompoint(self)
	local cont = true
	red_dots = {}
	while(cont) do
  		local randx = math.random(minX,maxX)
		local randy = math.random(minY,maxY)
  	
  		if self:checkPlayfield(randx,randy) == 0 then
  			playField["x"..randx]["y"..randy] = POINT
  			table.insert(red_dots,{randx, randy})
  			cont = false
  		end
  	end
end

function initPlayfield(self)
	for x = minX,maxX do
		local innerList = {}
		for y = minY,maxY do
			innerList["y" .. y] = 0
		end		
		playField["x" .. x] = innerList
	end
	
	for x = minX,maxX do
		table.insert(border, {x,minY})
		table.insert(border, {x,maxY})
		playField["x" .. x]["y" .. minY] = BORDER
		playField["x" .. x]["y" .. maxY] = BORDER
	end
	
	for y = 1,maxY do
		table.insert(border, {minX,y})
		table.insert(border, {maxX,y})
		playField["x" .. minX]["y" .. y] = BORDER	
		playField["x" .. maxX]["y" .. y] = BORDER
	end
	self:addRandompoint()
	posX = startX
	posY = startY
	direction = KEY_UP
	snake = {}
end

function openWindow(self)
	self.window = self:_window("Snake")
	self:tieAndShowWindow(self.window)
	return self.window
end

function drawList(self, list, color)
	for i = 1,#list do
		local dot = list[i]
		srf:filledRectangle(BLOCKSIZE*dot[1],BLOCKSIZE*dot[2], BLOCKSIZE*(dot[1]+1)-1, BLOCKSIZE*(dot[2]+1)-1, color)
  end
end

function drawField(self)
	if gameover == true then
		self:gameOver()
		return
	end
	srf:filledRectangle(0, 0, w, h, 0x000000FF)
	local lStatus = Surface:drawText(window:styleFont("squeezebox"), 0xFFFFFF80, "    Lives: " .. lives .. "    Score: " .. score)

	if labelStatus != nil then
		labelStatus:setValue(lStatus)
	else 
		labelStatus = Icon("icon", lStatus)
		window:addWidget(labelStatus)
	end

	-- draw borders
	self:drawList(border, 0xFFFFFFFF)
	-- draw snake
	self:drawList(snake, 0x0000FFFF)
	-- draw red dots
	self:drawList(red_dots, 0xFF0000FF)
	self.bg:reDraw()
end

function gameOver()
	gameover = true
	local popup = Popup("waiting_popup", "\n \nGame over!\n \n \nYour score: " .. score)
	popup:addListener(ACTION,
		function(evt)
			window:hideToTop(Window.transitionPushLeft)
		end
	)

	window:addWidget(popup)
	popup:show()
end

function moveSnake(self, x, y)
	table.insert(snake, {x,y})
 	if #snake > MINLENGTH + length then
  		local old = table.remove(snake,1)
  		playField["x"..old[1]]["y"..old[2]] = 0
	end
end

function playCrash(self)
  crashSound:play()
end

function playPoint(self)
  pointSound:play()
end

function autoMove(self) 
	if direction == KEY_LEFT then
		posX = posX - 1
	elseif direction == KEY_RIGHT then
		posX = posX + 1
	elseif direction == KEY_DOWN then
		posY = posY + 1
	elseif direction == KEY_UP then
		posY = posY - 1
	end

 	if direction != 0 then
		if self:checkPlayfield(posX,posY) == 0 then
			playField["x" .. posX]["y" .. posY] = SNAKE
			self:moveSnake(posX,posY)
		elseif self:checkPlayfield(posX,posY) == POINT then
			score = score + 5
			length = length + 5
			self:addRandompoint()
			playField["x" .. posX]["y" .. posY] = SNAKE
			self:moveSnake(posX,posY)
			self:playPoint()
		else
			self:playCrash()
			lives = lives - 1
			if lives == 0 then	
				self.window:hide()
				gameover = true
			else
				length = 0
				self:initPlayfield()
			end
		end
	end
end


function checkPlayfield(self, x, y)
	return playField["x" .. x]["y" .. y]
end

function keyEvent(self, evt)
  local key = evt:getKeycode()
  if key == KEY_LEFT then
		direction = KEY_LEFT
	elseif key == KEY_RIGHT then
		direction = KEY_RIGHT
	elseif key == KEY_DOWN then
		direction = KEY_DOWN
	elseif key == KEY_UP then
		direction = KEY_UP
	end
end

function scrollEvent(self, evt)
	local scroll = evt:getScroll()
	
	if scroll == 1 then
		 -- turn right
	 	if direction == KEY_LEFT then
			direction = KEY_UP
		elseif direction == KEY_RIGHT then
			direction = KEY_DOWN
		elseif direction == KEY_DOWN then
			direction = KEY_LEFT
		elseif direction == KEY_UP then
			direction = KEY_RIGHT
		end	
	elseif scroll == -1 then
		-- turn left
	 	if direction == KEY_LEFT then
			direction = KEY_DOWN
		elseif direction == KEY_RIGHT then
			direction = KEY_UP
		elseif direction == KEY_DOWN then
			direction = KEY_RIGHT
		elseif direction == KEY_UP then
			direction = KEY_LEFT
		end	
	end
end


function _window(self, ...)	
  window = Window(self:displayName())

	srf = Surface:newRGBA(w, h)
	srf:filledRectangle(0, 0, w, h, 0x000000FF)
	self.bg = Icon("icon", srf)

	window:addListener(EVENT_KEY_DOWN, 
		function(evt)
			keyEvent(self, evt)
		end
	)

	window:addListener(EVENT_SCROLL,
		function(evt)
			scrollEvent(self, evt)
		end
	)

	window:addWidget(self.bg)

	self:initPlayfield()

	self.bg:addAnimation(
		function()
		  self:autoMove()
		  self:drawField()
		end,
		FRAMERATE	
	)


	return window
end


--[[

=head1 LICENSE

Copyright 2007 Lukas Frey

Feel free to reuse!

=cut
--]]
