--------------------------------------------------------------------------------
---------------------- ##       #####    #####   ######  -----------------------
---------------------- ##      ##   ##  ##   ##  ##   ## -----------------------
---------------------- ##      ##   ##  ##   ##  ######  -----------------------
---------------------- ##      ##   ##  ##   ##  ##      -----------------------
---------------------- ######   #####    #####   ##      -----------------------
----------------------                                   -----------------------
----------------------- Lua Object-Oriented Programming ------------------------
--------------------------------------------------------------------------------
-- Project: LOOP Class Library                                                --
-- Release: 2.2 alpha                                                         --
-- Title  : Timer for Triggering of Events at Regular Rates                   --
-- Author : Renato Maia <maia@inf.puc-rio.br>                                 --
-- Date   : 01/03/2006 12:53                                                  --
--------------------------------------------------------------------------------

local math         = require "math"
local coroutine    = require "coroutine"
local oo           = require "loop.base"

module("loop.thread.Timer", oo.class)

function __init(class, self)
	self = oo.rawnew(class, self)
	self.thread = coroutine.create(function() return self:timer() end)
	return self
end

function timer(self)
	if self.enabled then
		local rate = self.rate
		local scheduler = self.scheduler
		local next = scheduler:time() + rate
		self:action()
		local now = scheduler:time()
		if now < next
			then scheduler:wait(next - now)
			else scheduler:wait(rate - math.fmod(now - next, rate))
		end
		return self:timer()
	end
end

function enable(self)
	if not self.enabled then
		self.enabled = true
		return self.scheduler:register(self.thread)
	end
end

function disable(self)
	self.enabled = nil
end