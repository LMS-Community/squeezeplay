local ipairs, tostring = ipairs, tostring

local io                     = require("io")
local oo                     = require("loop.simple")
local string                 = require("string")
local table                  = require("jive.utils.table")
local math		     = require("math")

local Applet                 = require("jive.Applet")
local Framework              = require("jive.ui.Framework")
local Audio		     = require("jive.ui.Audio")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local Popup                  = require("jive.ui.Popup")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Surface                = require("jive.ui.Surface")
local Window                 = require("jive.ui.Window")


-- One Shots Per Second
local RATE_OF_FIRE = jive.ui.FRAME_RATE

-- Bomb Rate
local BOMB_RATE = jive.ui.FRAME_RATE / 3
local BOMB_PROP = 0.3

local MAX_INVADERS = 50
local INVADER_SPAWNRATE = jive.ui.FRAME_RATE - (jive.ui.FRAME_RATE/2)
local INVADER_Y = 23

local UFO_SPAWNRATE = jive.ui.FRAME_RATE * 2
local UFO_Y = 0

local entity_id = 1

module(..., Framework.constants)
oo.class(_M, Applet)


Ufo = oo.class()

local UfoSprite = nil

function Ufo:__init(sw, sh, gameplay)
	local obj = oo.rawnew(self)
	if UfoSprite == nil then
		UfoSprite = Surface:loadImage("applets/Invaders/ufo.png")
	end

	obj.sprite = Icon("icon", UfoSprite)
	
	local spritew, spriteh = UfoSprite:getSize()
	obj.width = spritew
	obj.height = spriteh
	
	obj.gameplay = gameplay
	obj.screen_width = sw
	obj.screen_height = sh
	
	obj.direction = 1
	obj.x = 0
	obj.y = UFO_Y
	obj.last_bomb = 0

	return obj
end

local function Ufo_draw(self)
	local sprite = self.sprite
	sprite:setPosition(self.x, self.y)
end

local function Ufo_move(self)
	
	if self.direction == 1 then
		self.x = self.x + 1
	elseif self.direction == -1 then
		self.x = self.x -1
	end

	if self.x < 0 then 
		self.x = 0
		self.direction = 1
	elseif self.x + self.width > self.screen_width then
		self.x = self.screen_width - self.width
		self.direction = -1
	end

	if self.last_bomb > BOMB_RATE then
		if math.random() < BOMB_PROP then 

			-- They Set Us Up The Bomb!
			local b = Bomb(self.screen_width, self.screen_height, self.gameplay)
			b.x = self.x + (self.width/2) + (b.width/2)
			b.y = self.y + self.height

			self.gameplay:addBomb(b)
			self.gameplay.photon_snd:play()
		end

		self.last_bomb = 0
	end
	self.last_bomb = self.last_bomb + 1
end

Invader = oo.class()

local InvaderSprite = nil

function Invader:__init(sw, sh, gameplay)
	local obj = oo.rawnew(self)
	obj.id = entity_id
	entity_id = entity_id + 1

	if InvaderSprite == nil then
		InvaderSprite = Surface:loadImage("applets/Invaders/invader.png")
	end
	
	obj.sprite = Icon("icon" .. obj.id, InvaderSprite)
	obj.x = 0
	obj.y = INVADER_Y
	obj.direction = 1
	obj.gameplay = gameplay
	
	local spritew, spriteh = InvaderSprite:getSize()
	obj.width = spritew
	obj.height = spriteh

	obj.screen_width = sw
	obj.screen_height = sh

	return obj
end

local function Invader_draw(self)
	local sprite = self.sprite
	sprite:setPosition(self.x, self.y)
end

local function Invader_move(self)
	
	if self.direction == 1 then
		self.x = self.x + 3
	elseif self.direction == -1 then
		self.x = self.x -3
	end

	if self.x < 0 then 
		self.x = 0
		self.y = self.y + self.height + 3
		self.direction = 1
	elseif self.x + self.width > self.screen_width then
		self.x = self.screen_width - self.width
		self.y = self.y + self.height + 3
		self.direction = -1
	end

	if self.y > self.screen_height - (self.height*2) then
		self.gameplay:gameOver()
	end
end


Shot = oo.class()

local SHOT_WIDTH = 2
local SHOT_HEIGHT = 3

local ShotSprite = nil

function Shot:__init(sw, sh, gameplay)
	local obj = oo.rawnew(self)
	obj.id = entity_id
	entity_id = entity_id + 1

	if ShotSprite == nil then
		ShotSprite = Surface:newRGBA(SHOT_WIDTH, SHOT_HEIGHT)
		ShotSprite:filledRectangle(0, 0, SHOT_WIDTH, SHOT_HEIGHT, 0xFF0000FF)
	end

	obj.sprite = Icon("icon" .. obj.id, ShotSprite)

	obj.gameplay = gameplay
	obj.x = 0
	obj.y = 0
	obj.width = SHOT_WIDTH
	obj.height = SHOT_HEIGHT

	return obj
end

local function Shot_draw(self)
	local sprite = self.sprite
	sprite:setPosition(self.x, self.y)
end

local function Shot__step(self)
	self.y = self.y - 1	
end

local function Shot_move(self)
	local i = 0

	while i < 5 do
		Shot__step(self)

		if self.y + self.height < 0 then
			self.gameplay:removeShot(self)
		end

		i = i + 1
	end

end

local function Shot_overlap(self, b)
	if self.x + self.width < b.x then
                return false
        end

        if self.y + self.height < b.y then
                return false
        end

        if self.x > b.x + b.width then
                return false
        end

        if self.y > b.y + b.height then
                return false
        end

        return true
end

Bomb = oo.class()

local BombSprite = nil

function Bomb:__init(sw, sh, gameplay)
	local obj = oo.rawnew(self)
	obj.id = entity_id
	entity_id = entity_id + 1

	if BombSprite == nil then
		BombSprite = Surface:loadImage("applets/Invaders/bomb.png")
	end

	obj.sprite = Icon("icon" .. obj.id, BombSprite)

	obj.gameplay = gameplay
	obj.x = 0
	obj.y = 0
	obj.width = SHOT_WIDTH
	obj.height = SHOT_HEIGHT

	obj.screen_width = sw
	obj.screen_height = sh

	return obj
end

local function Bomb_draw(self)
	self.sprite:setPosition(self.x, self.y)
end

local function Bomb__step(self)
	self.y = self.y + 1	
end

local function Bomb_move(self)
	local i = 0

	while i < 5 do
		Bomb__step(self)

		if self.y + self.height > self.screen_height then
			self.gameplay:removeBomb(self)
		end

		i = i + 1
	end

end

local function Bomb_overlap(self, b)
	if self.x + self.width < b.x then
                return false
        end

        if self.y + self.height < b.y then
                return false
        end

        if self.x > b.x + b.width then
                return false
        end

        if self.y > b.y + b.height then
                return false
        end

        return true
end

Player = oo.class()

function Player:__init(sw, sh, gameplay)
	local obj = oo.rawnew(self)
	local img = Surface:loadImage("applets/Invaders/player.png")
	obj.sprite = Icon("icon", img)	

	local spritew, spriteh = img:getSize()

	obj.x = (sw-spritew) / 2
	obj.y = (sh-spriteh)
	obj.width = spritew
	obj.height = spriteh
	obj.direction = 0

	obj.screen_width = sw
	obj.screen_height = sh

	obj.gameplay = gameplay
	obj.last_shot = 0

	return obj
end

local function Player_shoot(self)
	if self.last_shot >= RATE_OF_FIRE then
		-- Create Shot
		local ns = Shot(self.screen_width, self.screen_height, self.gameplay)

		-- Setup Correct Location
		ns.x = self.x + (self.width/2) - (ns.width/2)
		ns.y = self.y - (ns.height)

		-- Add to Gameplay
		self.gameplay:addShot(ns)
		self.gameplay.missle_snd:play()

		self.last_shot = 0
	end
end

local function Player_draw(self)
	local sprite = self.sprite
	sprite:setPosition(self.x, self.y)	
end

local function Player_move(self, direction)
	-- Update Counter
	self.last_shot = self.last_shot + 1

	local direction = self.direction
	--self.direction = 0

	self.x = self.x + (5 * self.direction)
	if self.scrolled then
		self.direction = 0
	end

	if self.x < 0 then
		self.x = 0
	end

	if self.x + self.width > self.screen_width then
		self.x = self.screen_width - self.width
	end
end

Score = oo.class()

function Score:__init(window, sw, sh)
	obj = oo.rawnew(self)
	obj.score = 0
	obj.screen_width = sw
	obj.screen_height = sh
	obj.x = 0
	obj.y = 0 
	
	obj.font = window:styleFont("squeezebox")

	obj.sprite = nil
	obj.window = window

	obj:_update()

	return obj
end

function Score:_update()
	-- Generate Text
	self.surface = Surface:drawText(self.font, 0xFFFFFF80, "Score: " .. self.score)


	if self.sprite != nil then
		self.sprite:setValue(self.surface)
	else 
		-- Add New
		self.sprite = Icon("icon", self.surface)
		self.window:addWidget(self.sprite)
		self.sprite:setPosition(self.x, self.y)
	end
end

function Score:add(i)
	self.score = self.score + i
	self:_update()
end

Gameplay = oo.class()

function Gameplay:__init(sw, sh)
	local obj = oo.rawnew(self)

	obj.player = Player(sw, sh, obj)

	obj.screen_width = sw
	obj.screen_height = sh
	
	obj.shots = {}
	obj.bombs = {}
	obj.invaders = {}
	obj.ufo = nil
	obj.score = nil
	
	obj.invader_spawning = true
	obj.last_invader = 10000
	obj.invaders_count = 10

	obj.gameover = false

	obj.last_ufo = 0

	obj.missle_snd = Framework:loadSound("applets/Invaders/missile.wav", 0)
	obj.photon_snd = Framework:loadSound("applets/Invaders/photon.wav", 1)
	obj.explosion_snd = Framework:loadSound("applets/Invaders/explosion.wav", 0)

	return obj
end

function Gameplay:Setup(window)
	self.window = window

	self.score = Score(window, self.screen_width, self.screen_height)

	window:addWidget(self.player.sprite)
end

function Gameplay:addInvader(inv)
	table.insert(self.invaders, inv)
	self.window:addWidget(inv.sprite)
	Invader_draw(inv)
end

function Gameplay:removeInvader(inv)
	self.window:removeWidget(inv.sprite)

	for i,b in ipairs(self.invaders) do
		if b.id == inv.id then
			table.remove(self.invaders, i)
			break
		end
	end
end

function Gameplay:addShot(s)
	table.insert(self.shots, s)
	self.window:addWidget(s.sprite)
	Shot_draw(s)
end

function Gameplay:addBomb(b)
	table.insert(self.bombs, b)
	self.window:addWidget(b.sprite)
	Bomb_draw(b)
end

function Gameplay:removeShot(s)
	self.window:removeWidget(s.sprite)

	for i,b in ipairs(self.shots) do
		if b.id == s.id then
			table.remove(self.shots, i)
			break
		end
	end
end

function Gameplay:removeBomb(b)
	self.window:removeWidget(b.sprite)

	for i,bomb in ipairs(self.bombs) do
		if bomb.id == b.id then
			table.remove(self.bombs, i)
			break
		end
	end
end

function Gameplay:addUfo()
	self.window:addWidget(self.ufo.sprite)
end

function Gameplay:removeUfo()
	self.window:removeWidget(self.ufo.sprite)

	self.last_ufo = 0
	self.ufo = nil
end

function Gameplay:gameOver()
	local popup = Popup("waiting_popup", "Congratulations!\nYou lost!\n---\nFinal Score: " .. self.score.score)
	popup:addListener(ACTION,
		function(evt)
			self.window:hideToTop(Window.transitionPushLeft)
		end
	)

	self.gameover = true
	popup:show()
end

function Gameplay:Tick()
	if self.gameover == true then
		self.window:hide()
		return
	end

	self.last_invader = self.last_invader + 1

	local p = self.player

	-- Do we need to spawn more invaders?
	if table.getn(self.invaders) == 0 then
		self.invader_spawning = true
		self.invaders_count = self.invaders_count + 2
		
		if self.invaders_count > MAX_INVADERS then
			self.invaders_count = MAX_INVADERS
		end
	end

	if self.invader_spawning then
		if self.last_invader > INVADER_SPAWNRATE then
			local inv = Invader(self.screen_width, self.screen_height, self)
			self:addInvader(inv)

			self.last_invader = 0
		end

		if table.getn(self.invaders) == self.invaders_count then
			self.invader_spawning = false
		end
	end

	if self.ufo == nil then
		if self.last_ufo > UFO_SPAWNRATE then
			self.ufo = Ufo(self.screen_width, self.screen_height, self)
			self:addUfo()
		else 
			self.last_ufo = self.last_ufo + 1
		end
	end

	-- Move Everything
	Player_move(self.player)

	if self.ufo != nil then
		Ufo_move(self.ufo)
	end

	for i, b in ipairs(self.shots) do
		Shot_move(b)
	end

	for i, b in ipairs(self.invaders) do
		Invader_move(b)
	end

	for i, b in ipairs(self.bombs) do
		Bomb_move(b)
	end

	-- Check for Collisions
	for i, s in ipairs(self.shots) do
		for i, inv in ipairs(self.invaders) do
			if Shot_overlap(s, inv) then

				self:removeInvader(inv)
				self:removeShot(s)
				self.explosion_snd:play()

				self.score:add(1)
			end
		end

		if self.ufo != nil then
			if Shot_overlap(s, self.ufo) then
				self:removeShot(s)
				self:removeUfo()
				self.explosion_snd:play()

				self.score:add(5)
			end
		end
	end

	for i, b in ipairs(self.bombs) do
		if Bomb_overlap(b, self.player) then
			self:gameOver()
			self:removeBomb(b)
		end
	end
end


function Gameplay:UpdatePositions()
	Player_draw(self.player)
	
	if self.ufo != nil then
		Ufo_draw(self.ufo)
	end

	for i, b in ipairs(self.shots) do
		Shot_draw(b)
	end

	for i, b in ipairs(self.invaders) do
		Invader_draw(b)
	end

	for i, b in ipairs(self.bombs) do
		Bomb_draw(b)
	end
end


function displayName(self)
	return "Space Invaders"
end

function openWindow(self, ...)
	self.window = self:_window(self, label)
	return self.window
end

function keyhandler_down(self, evt, gameplay)
	if evt:getKeycode() == KEY_LEFT then
		gameplay.player.direction = -1
	elseif evt:getKeycode() == KEY_RIGHT then
		gameplay.player.direction = 1
	elseif evt:getKeycode() == KEY_UP or evt:getKeycode() == KEY_GO then
		Player_shoot(gameplay.player)
	end
end

function keyhandler_up(slef, evt, gameplay)
	gameplay.player.direction = 0
end

function _window(self, ...)
	log:warn("_window")
	log:warn(FRAME_RATE)
	
	local window = Window(self:displayName())
	local w, h = Framework:getScreenSize()

	local gp = Gameplay(w, h, FRAME_RATE)
	self.gameplay = gp

	local srf = Surface:newRGBA(w, h)
	srf:filledRectangle(0, 0, w, h, 0x000000FF)

	self.bg = Icon("icon", srf)

	window:addListener(EVENT_SCROLL,
		function(evt)
			gp.player.direction = evt:getScroll()
			gp.player.scrolled = true
		end
	)

	window:addListener(EVENT_KEY_PRESS, 
		function(evt)
			local kc = evt:getKeycode()
			if kc == KEY_BACK then
				window:hide()
			end
		end
	)

	window:addListener(EVENT_KEY_DOWN,
		function(evt)
			keyhandler_down(self, evt, gp)
		end
	)

	window:addListener(EVENT_KEY_UP,
		function(evt)
			keyhandler_up(self, evt, gp)
		end
	)

	window:addWidget(self.bg)
	gp:Setup(window)

	self.bg:addAnimation(
		function()
			self.gameplay:Tick()
			self.gameplay:UpdatePositions()
		end,
		FRAME_RATE	
	)

	return window
end

function openWindow(self)
	self.window = self:_window("Invaders")
	self:tieAndShowWindow(self.window)
	return self.window
end
