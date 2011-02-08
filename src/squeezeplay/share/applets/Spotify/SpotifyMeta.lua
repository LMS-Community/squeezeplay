local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")
local Playback      = require("jive.audio.Playback")
local log           = require("jive.utils.log").logger("audio.decode")

local appletManager = appletManager
local jiveMain      = jiveMain
local jnt           = jnt

local hasSpprivate, spprivate = pcall(require, "spprivate")

module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 1, 1
end


function registerApplet(self)
	if hasSpprivate then			 
		self:registerService("spotify")
		Playback:registerHandler('spotify', function(...) appletManager:callService("spotify", ...) end)
	else
		log:warn("Spotify decoder not available, disabling Spotify support")
	end
end

