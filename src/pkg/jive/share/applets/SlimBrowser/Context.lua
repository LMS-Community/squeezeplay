-----------------------------------------------------------------------------
-- Context.lua
-----------------------------------------------------------------------------


local unpack, tostring, pairs, ipairs = unpack, tostring, pairs, ipairs

local oo = require("loop.base")
local table = require("table")

require("jive.slim.RequestsCli")
local RequestCli = jive.slim.RequestCli

local log = require("jive.utils.log").logger("player.browse")

-- our class
module(..., oo.class)


-- init
-- creates a context object
function __init(self, player, hierarchy)
	log:debug("Context:__init()")
	
	return oo.rawnew(self, {
		player = player,
		hierarchy = hierarchy,
		ids = {},
		level = 1,
	})
end

-- for each level, we need to know
--- how to craft a command to get the relevant data
---- static part of cmdArray + tags
---- dynamic part of tags/ids at each level browsed
----- we can "forget" things... if we have a track_id, we do not need the rest...
----- add to static part list of possible dynamic parts!
--- what are key fields in returned data (this only depends on query, not dynamic)
----- loop name, tag containing title, tag containing id, tag containing artwork_id


local level2cmd = {
	["contributor"]      = {cmdarray = {"artists"}},
	["album"]            = {cmdarray = {"albums"}, tags = {["tags"] = "lja"}},
	["track"]            = {cmdarray = {"tracks"}},
	["year"]             = {cmdarray = {"years"}},
	["genre"]            = {cmdarray = {"genres"}},
	["age"]              = {cmdarray = {"albums"}, tags = {["sort"] = "new", ["tags"] = "lja"}},
	["playlist"]         = {cmdarray = {"playlists"}},
	["playlisttrack"]    = {cmdarray = {"playlists", "tracks"}},
	["radios"]           = {cmdarray = {"radios"}},
	["status"]           = {cmdarray = {"status"}},
		-- FIXME: what tags to show -- some are missing in CLI (vol adj, sample rate)
		-- FIXME: songinfo details TBD
	["info"]             = {cmdarray = {"songinfo"}, tags = {["tags"] = "altypodrfnuv"}},
}
local level2id = {
	["contributor"]      = "artist_id",
	["album"]            = "album_id",
	["track"]            = "track_id",
	["year"]             = "year",
	["genre"]            = "genre_id",
	["age"]              = "album_id",
	["playlist"]         = "playlist_id",
	["playlisttrack"]    = "track_id",
	["radios"]           = "cmd",
	["status"]           = "id",
	["info"]             = "track_id",
}

-- getBrowseRequest
-- returns a request for browsing our hierarchy at the current level
function getBrowseRequest(self, sink)
	log:debug("Context:getBrowseRequest()")

	-- general idea is to walk down our hierarchy, collecting arguments (tags)
	-- as we go
	
	local cmdarray ={}
	local from = 0
	local to = 100
	local tags = {}
		
	-- special case the bottom, i.e. info...
	if self.hierarchy[self.level] == "info" then
	
		cmdarray = level2cmd["info"]["cmdarray"]
		local cmdtags = level2cmd["info"]["tags"]
		
		if cmdtags then
			for k,v in pairs(cmdtags) do
				tags[k] = v
			end
		end

		for i = 1,self.level do
			if self.hierarchy[i] == "track" or self.hierarchy[i] == "playlisttrack" or self.hierarchy[i] == "status" then
				
				tags["track_id"] = self.ids[i]
			end
		end
	else
	
		local hasalbumid = false
	
		for i = 1,self.level do
		
			log:debug("Context:getcmd: level: ", tostring(i), " = ", tostring(self.hierarchy[i]))

			if i == self.level then

				-- final thing, get the command
				local cmdstuff = level2cmd[self.hierarchy[i]]

				-- the command is the first item of the array
				-- make sure we duplicate the array!
				for i,v in ipairs(cmdstuff["cmdarray"]) do
					cmdarray[i] = v
				end
				
				if cmdstuff["tags"] then
					for k,v in pairs(cmdstuff["tags"]) do
						tags[k] = v
					end
				end

				-- if we have an album_id, sort by tracknum...
				if self.hierarchy[i] == "track" and hasalbumid then
					tags["sort"] = "tracknum"
				end					

			else

				local paramkey = level2id[self.hierarchy[i]]
				if paramkey == "album_id" then hasalbumid = true end
				tags[paramkey] = self.ids[i]
			end
		end
	end
	
	return RequestCli(sink, self.player, cmdarray, from, to, tags)
end




function getPlayCmd(self)
	log:debug("Context:getPlayCmd(", self.hierarchy[self.level], ")")
	log:debug(self.hierarchy)
	
	local params = {}
	
	-- special case the bottom, i.e. info...
	if self.hierarchy[self.level] == "info" then
	
		local param
		
		-- play the track we're showing!
		for i = 1,self.level do
			if self.hierarchy[i] == "track" or self.hierarchy[i] == "playlisttrack" then
				
				param = "track_id:" .. self.ids[i]
				log:debug("Context:getplaycmd: param: ", param)
				table.insert(params, param)
			end
		end
		
		if param == nil then
			log:error("Context:getplaycmd() cannot find track_id for info!")
		end
		
	else
	
		local hasalbumid = false
	
		for i = 1,self.level do
		
			log:debug("Context:getplaycmd: level: ", tostring(i), " = ", tostring(self.hierarchy[i]))

			if i == self.level then

				-- final thing, get the command
				local cmdstuff = level2cmd[self.hierarchy[i]]

				-- if there's a second item, it's a param
				if cmdstuff[2] then
					table.insert(params, cmdstuff[2])
					log:debug("Context:getcmd: param: ", cmdstuff[2])
				end

				-- if we have an album_id, sort by tracknum...
				if self.hierarchy[i] == "track" and hasalbumid then
					table.insert(params, "sort:tracknum")
					log:debug("Context:getcmd: param: sort:tracknum")
				end					

			else

				local paramkey = level2id[self.hierarchy[i]]
				if paramkey == "album_id" then hasalbumid = true end
				local param = paramkey .. ":" .. self.ids[i]
				log:debug("Context:getplaycmd: param: ", param)
				table.insert(params, param)

			end
		end
	end	
	
	return {'playlistcontrol', 'cmd:load', unpack(params)}
end

local level2keys = { -- loop, title, id, artwork
	["contributor"]      = {"artists_loop", "artist", "id"},
	["album"]            = {"albums_loop", "album", "id", "artwork_track_id"},
	["track"]            = {"titles_loop", "title", "id"},
	["year"]             = {"years_loop", "year", "year"},
	["genre"]            = {"genres_loop", "genre", "id"},
	["age"]              = {"albums_loop", "album", "id", "artwork_track_id"},
	["playlist"]         = {"playlists_loop", "playlist", "id"},
	["playlisttrack"]    = {"playlisttracks_loop", "title", "id"},
	["radios"]           = {"radioss_loop", "name", "cmd"},
	["status"]           = {"playlist_loop", "title", "id", "coverart"},
	["info"]             = {}
}


-- getkeys
-- returns the key fields in the returned data
-- loop, title, id
function getkeys(self)
	log:debug("Context:getkeys: level: ", tostring(self.level), " = ", tostring(self.hierarchy[self.level]))
	
	return unpack(level2keys[self.hierarchy[self.level]])
end


function setid(self, id)
	self.ids[self.level] = id
end


-- down
-- returns a new context for the level down, given the id of the current level
function down(self, id)
	log:debug("Context:down(", tostring(id), ")")
	
	if self.level == #self.hierarchy then
		log:error("Context:down() at the bottom already!")
		return
	end
	
	self:setid(id)
	
	local newContext = _M(self.player, self.hierarchy)
	newContext.level = self.level + 1
	for i=1, self.level do
		newContext.ids[i] = self.ids[i]
	end
	
	return newContext
end


function isStatus(self)
	return self.hierarchy[self.level] == "status"
end


-- store/restore
-- use the context to store arbitrary data
function store(self, ...)
	self.storage = arg
end
function restore(self)
	if self.storage then
		return unpack(self.storage)
	else
		log:warn("Context:restore() called with nothing previously stored!!!")
	end
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

