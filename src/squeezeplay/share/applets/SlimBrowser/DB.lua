
--[[
=head1 NAME

applets.SlimBrowser.DB - Item database.

=head1 DESCRIPTION

This object is designed to store and manage the browsing data Jive receives.

Conceptually, this data is a long list of items n1, n2, n3..., which is received by chunks. Each chunk 
is a table with many properties but of particular interest are:
- count: indicates the number of items in the long list
- offset: indicates the first index of the data in the item_obj array
- item_obj: array of consecutive elements, from offset to offset+#item_obj
- playlist_timestamp: timestamp of the data (optional)

If count is 0, then the other fields are optional (and may not even be looked at).

Fresh data always refreshes old data, except if it would be cost prohibitive to do so.

There should be one DB per long list "type". If the count or the timestamp of the long list
is different from the existing stored info, the existing info is discarded.

=head1 SYNOPSIS

TODO

=head1 FUNCTIONS

=cut
--]]

-- stuff we use
local _assert, tonumber, tostring, type, ipairs = _assert, tonumber, tostring, type, ipairs

local oo = require("loop.base")
local RadioGroup = require("jive.ui.RadioGroup")

local math = require("math")
local debug = require("jive.utils.debug")
local log = require("jive.utils.log").logger("player.browse.data")

-- our class
module(..., oo.class)


local BLOCK_SIZE = 200


-- init
-- creates an empty database object
function __init(self, windowSpec)
	log:debug("DB:__init()")

	return oo.rawnew(self, {
		
		-- data
		store = {},
		last_chunk = false,  -- last_chunk received, to access other non DB fields

		-- major items extracted from data
		count = 0,           -- =last_chunk.count, the total number of items in the long list
		ts = false,          -- =last_chunk.timestamp, the timestamp of the current long list (if available)
		currentIndex = 0,    -- =last_chunk.playlist_cur_index, index of the current song (if available)

		-- cache
		last_indexed_chunk = false,
		complete = false,
		
		-- windowSpec (to create labels in renderer)
		windowSpec = windowSpec,
	})
end


function menuStyle(self)
	return self.windowSpec.menuStyle
end


function labelItemStyle(self)
	return self.windowSpec.labelItemStyle
end


-- getRadioGroup
-- either returns self.radioGroup or creates and returns it
function getRadioGroup(self)
	if not self.radioGroup then
		self.radioGroup = RadioGroup()
	end
	return self.radioGroup
end


-- status
-- Update the DB status from the chunk.
function updateStatus(self, chunk)
	-- sanity check on the chunk
	_assert(chunk["count"], "chunk must have count field")

	-- keep the chunk as header, in all cases
	self.last_chunk = chunk
	
	-- update currentIndex if we have it
	local currentIndex = chunk["playlist_cur_index"]
	if currentIndex then
		self.currentIndex = currentIndex + 1
	end
	
	-- detect change that invalidates data
	local ts = chunk["playlist_timestamp"] or false
	
	-- get the count
	local cCount = tonumber( chunk["count"] )

	local reset = false
	if cCount != self.count then
		-- count has changed, drop the data
		log:debug("..store invalid, different count")
		reset = true
		
	elseif ts and self.ts != ts then
		-- ts has changed, drop the data
		log:debug("..store invalid, different timestamp")
		reset = true
	end

	if reset then
		self.store = {}
		self.complete = false
	end

	-- update the window properties
	if chunk and chunk.window then
		local window = chunk.window

		if window.menuStyle then
			self.windowSpec.menuStyle = window.menuStyle .. "menu"
			self.windowSpec.labelItemStyle = window.menuStyle .. "item"
		end
	end


	self.ts = ts
	self.count = cCount

	return reset
end


-- menuItems
-- Stores the chunk in the DB and returns data suitable for the menu:setItems call
function menuItems(self, chunk)
	log:debug(self, " menuItems()")

	-- we may be called with no chunk, f.e. when building the window
	if not chunk then
		return self, self.count
	end

	-- update the status
	updateStatus(self, chunk)

	-- fix offset, CLI is 0 based and we're 1-based
	local cFrom = 0
	local cTo = 0
	if self.count > 0 then
	
		_assert(chunk["item_loop"], "chunk must have item_loop field if count>0")
		_assert(chunk["offset"], "chunk must have offset field if count>0")
		
		cFrom = chunk["offset"] + 1
		cTo = cFrom + #chunk["item_loop"] - 1
	end

	-- store chunk
	local key = math.modf(cFrom / BLOCK_SIZE)
	self.store[key] = chunk["item_loop"]

	return self, self.count, cFrom, cTo
end


function chunk(self)
	return self.last_chunk
end


function playlistIndex(self)
	if self.ts then
		return self.currentIndex
	else
		return nil
	end
end


function item(self, index)
	local current = (index == self.currentIndex)

	index = index - 1

	local key = math.modf(index / BLOCK_SIZE)
	local offset = math.fmod(index, BLOCK_SIZE) + 1

	if not self.store[key] then
		return
	end

	return self.store[key][offset], current
end


function size(self)
	return self.count
end


function missing(self, accel, dir, index)
	log:debug(self, " missing accel=", accel, " index=", index, " dir=", dir)

	-- use our cached result
	if self.complete then
		log:debug(self, " complete (cached)")
		return
	end

	-- load first chunk
	if not self.store[0] then
		return 0, BLOCK_SIZE
	end
	
	local count = tonumber(self.last_chunk.count)

	-- load last chunk
	local lastKey = 0
	if count > BLOCK_SIZE then
		lastKey = math.modf(count / BLOCK_SIZE)
		if lastKey * BLOCK_SIZE == count then
			lastKey = lastKey - 1
		end
		if not self.store[lastKey] then
			return lastKey * BLOCK_SIZE, BLOCK_SIZE
		end
	end

	-- otherwise load in the direction of scrolling
	local fromKey, toKey, step = 1, lastKey, 1
	if dir < 0 then
		fromKey, toKey, step = toKey, fromKey, -1
	end

	-- search for chunks to load
	for key = fromKey, toKey, step do
		if not self.store[key] then
			local idx = key * BLOCK_SIZE

			log:debug(self, " missing ", BLOCK_SIZE, " items from pos ", idx)
			return idx, BLOCK_SIZE
		end
	end

	-- if we reach here we're complete (for next time)
	log:debug(self, " complete (calculated)")
	self.complete = true
	return
end


function __tostring(self)
	return "DB {" .. tostring(self.windowSpec.text) .. "}"
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

