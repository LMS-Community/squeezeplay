
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
local assert, tostring, ipairs = assert, tostring, ipairs

local oo = require("loop.base")
local RadioGroup = require("jive.ui.RadioGroup")

local log = require("jive.utils.log").logger("player.browse.db")

-- our class
module(..., oo.class)


-- init
-- creates an empty database object
function __init(self, windowSpec)
	log:debug("DB:__init()")
	
	return oo.rawnew(self, {
		
		-- data
		head = false,        -- pointer to first stored chunk
		last_chunk = false,  -- last_chunk received, to access other non DB fields

		-- major items extracted from data
		count = 0,           -- =last_chunk.count, the total number of items in the long list
		ts = false,          -- =last_chunk.timestamp, the timestamp of the current long list (if available)
		currentIndex = 0,    -- =last_chunk.playlist_cur_index, index of the current song (if available)

		-- statistics
--		headcount = 0,       -- total count of elements stored

		-- cache
		last_indexed_chunk = false,
		complete = false,
		
		-- windowSpec (to create labels in renderer)
		windowSpec = windowSpec,
	})
end


function labelItemStyle(self)
	return self.windowSpec.labelItemStyle
end


-- dump
-- dumps the db
function dump(self)
	
	if not log:isDebug() then
		return
	end
	
	log:debug("-------------------------------- ", self, ":")

	local txt = ""
	if self.complete then txt="complete" end

	log:debug(" ", self.count, " items / ", self.ts, " / ", self.head, " / ", txt)
	
	local next = self.head
	local chIdx = 1
	while next do
		log:debug("  ", chIdx, ": ", next["_from"], " - ", next["_to"])
		next = next["_next"]
	end
	log:debug("--------------------------------")
end

-- getRadioGroup
-- either returns self.radioGroup or creates and returns it
function getRadioGroup(self)
	if not self.radioGroup then
		self.radioGroup = RadioGroup()
	end
	return self.radioGroup
end

-- menuItems
-- Stores the chunk in the DB and returns data suitable for the menu:setItems call
function menuItems(self, chunk)
	log:debug(self, " menuItems()")

	-- we may be called with no chunk, f.e. when building the window
	if not chunk then
		return self, self.count
	end

	-- sanity check on the chunk
	assert(chunk["count"], "chunk must have count field")

	-- print the state before we change it
	self:dump()

	-- keep the chunk as header, in all cases
	self.last_chunk = chunk
	
	-- update currentIndex if we have it
	local currentIndex = chunk["playlist_cur_index"]
	if currentIndex then
		self.currentIndex = currentIndex + 1
	end
	
	-- get the count
	local cCount = chunk["count"]

	-- fix offset, CLI is 0 based and we're 1-based
	local cFrom = 0
	local cTo = 0
	if cCount>0 then
	
		assert(chunk["item_loop"], "chunk must have item_loop field if count>0")
		assert(chunk["offset"], "chunk must have offset field if count>0")
		
		-- add _from and _to to the chunk rather than redo the calculation every time
		cFrom = chunk["offset"] + 1
		chunk["_from"] = cFrom
		cTo = cFrom + #chunk["item_loop"] - 1
		chunk["_to"] = cTo
	end
	
	-- detect change that invalidates data
	local valid = true
	local ts = chunk["playlist_timestamp"] or false
	
	if cCount != self.count then
	
		-- count has changed, drop the data
		log:debug("..store invalid, different count")
		valid = false
		
	elseif ts then
	
		if self.ts != ts then
		
			-- ts has changed, drop the data
			log:debug("..store invalid")
			valid = false
		end
	end
	
	-- update DB
	self.ts = ts
	self.count = cCount
	
	-- store the chunk
	if cCount == 0 then
	
		-- simplest case, nothing in the list so nothing to store!
		log:debug("..store is empty")
		self.head = false
		-- we're complete, obviously
		self.complete = true

	elseif not valid or not self.head then

		-- simple case, invalid existing data or empty store, replace head...
		log:debug("..store is new chunk")
		self.head = chunk
		-- not sure we're complete or not
		self.complete = false

	else
	
		-- we need to update the store with the new data
		log:debug("..new chunk range: ", cFrom, " - ", cTo)

		-- not sure we're complete or not
		self.complete = false

		-- need to find a place to insert/replace the data
		local next = self.head
		local prev
		local prevprev
		local sFrom
		local sTo
		local done = false
	
		while next and not done do
			sFrom = next["_from"]
			sTo   = next["_to"]
			log:debug("..store chunk range: ", sFrom, " - ", sTo)


			-- new chunk same bounds as next
			-- old: ...|---|...|--|.....|--|...
			-- new:    |---|
			-- new:            |--|
			if cFrom == sFrom and cTo == sTo then
			
				-- replace next
				log:debug("..new chunk replaces old")
				assert(next)
				chunk["_next"] = next["_next"]
				if prev then
					prev["_next"] = chunk
				else
					self.head = chunk
				end
				done = true
				break

			-- new chunk ends before next starts
			-- old: ...|---|...|--|.....|--|...
			-- new:          -|
			elseif cTo < sFrom then
				
				-- no prev chunk, or new starts after prev ends
				-- old: ...|---|...|--|.....|--|...
				-- new:  -|
				-- new:         |-|
				if not prev or prev["_to"] < cFrom then
				
					-- new chunk becomes head
					log:debug("..new chunk inserted between (prev) and next")
					assert(next)
					if prev then
						prev["_next"] = chunk
					else
						self.head = chunk
					end
					chunk["_next"] = next
					done = true
					break
				
				-- new overlaps prev
				-- old: ...|---|...|--|.....|--|...
				-- new:       |---|
				else
					log:debug("..OVERLAP 1: new chunk overlaps prev (but not over next)")
					-- same case than if we reach the end of the chunks, so let's go there!
					break
				end
			
			
			-- new chunk starts before next (but ends after/over)
			-- old: ...|---|...|--|.....|--|...
			-- new:  |--
			-- new:          |--
			elseif cFrom < sFrom then
			
				log:debug("..OVERLAP 2: new chunk over next (but not over prev)")
				
				-- old: ...|---|...|--|.....|--|...
				-- new:  |-----|
				if cTo >= next["_to"] then
				
					log:debug("..new chunk replaces (eats) next")
					
					-- how far does the rabbit hole go...
					-- old: ...|---|...|--|.....|--|...
					-- new:  |-------|
					-- new:  |----------|
					
					-- remove next
					local nextnext = next["_next"]
					if prev then
						prev["_next"] = nextnext
					else
						
						-- check next is not the only chunk!
						if nextnext then
							self.head = nextnext
						else
							
							-- head is chunk and done!
							log:debug("..store is new chunk")
							self.head = chunk
							done = true
							break
						end
					end
					-- fix next
					next = nextnext
				
					-- and let the loop sort it out...

				-- old: ...|---|...|--|.....|--|...
				-- new:          |--|
				else
				
					-- copy items from next to chunk
					-- store: 2-6, new 1-5, => store 1-6 (copy 6 (item 5 of store))
					-- store: 20-50, new 10-40 => store 10-50 (copy 41-50 (item 21 of store))
					-- FIXME: optimize by copying only different items?
					log:debug("..new chunk extended by next")
					-- cFrom:1, cTo: 5, sFrom: 2, sTo: 6 => 5 + 1 - 2 + 1 = 5
					-- cFrom:10, cTo: 40, sFrom: 20, sTo: 50 => 40 + 1 - 20 + 1 = 22
					local nextIdx = cTo + 1 - sFrom + 1
					local source = next["item_loop"]
					local data = chunk["item_loop"]
					for i = nextIdx, #source do
						data[#data+1] = source[nextIdx]
					end
					
					-- remove next
					chunk["_next"] = next["_next"]
					chunk["_to"] = sTo
					chunk["count"] = sTo - cFrom + 1
					if prev then
						prev["_next"] = chunk
					else
						self.head = chunk
					end
					done = true
					break
					
				end
				
			-- go to the next chunk
			else
				log:debug("..next chunk")
				prevprev = prev
				prev = next
				next = next["_next"]
			end
		end -- while next and not done
		
		
		if not done then
			
			-- new chunk starts after last db chunk
		
			-- old: ...|---|...|--|.....|--|...
			-- new:       |---|
			if cFrom <= prev["_to"] then
				log:debug("..OVERLAP 1b: to of prev =< from of new")
			
				-- old: ...|---|...|--|.....|--|...
				-- new:    |-----|
				if cFrom == prev["_from"] then
				
					log:debug("..new chunk replaces (eats) prev")
					if prevprev then
						prevprev["_next"] = chunk
					else
						self.head = chunk
					end
					chunk["_next"] = next
				
				-- old: ...|---|...|--|.....|--|...
				-- new:     |----|
				else
				
					-- copy items from chunk to prev
					-- store: 1-5, new 2-6, => store 1-6
					-- store: 20-50, new 40-60 => store 20-60
					-- FIXME: optimize by copying only different items?
					log:debug("..new chunk extends prev")
					local prevIdx = cFrom - prev["_from"] + 1
					for _,v in ipairs(chunk["item_loop"]) do
						prev["item_loop"][prevIdx] = v
						prevIdx = prevIdx + 1
					end
					prev["_to"] = cTo
				
				end

			-- old: ...|---|...|--|.....|--|...
			-- new:                         |---|
			else
				log:debug("..new chunk is last")
				assert(prev)
				prev["_next"] = chunk
				self:dump()
				return self, self.count, cFrom, cTo
			end
			
		end -- if not done then
	end -- else
	
	self.last_indexed_chunk = false
	self:dump()
--	log:debug("..returning ", self.count, ", ", cFrom, ", ", cTo)
	return self, self.count, cFrom, cTo

end


function chunk(self)
	return self.last_chunk
end


function item(self, index)
--	log:debug("item(", index, ")")
	
	-- avoid a wild chase...
	if index > self.count then
		log:debug("item ", index, " larger than count ", self.cont)
		return
	end
	
	local current = (index == self.currentIndex)

	-- start from head
	local next = self.head

	-- try the last access chunk first
	local last = self.last_indexed_chunk
	if last then
		
		local sTo = last["_to"]
--		log:debug("last to:", sTo)
		if index > sTo then
--			log:debug("next = last")
			next = last
		else
			local sFrom = last["_from"]
--			log:debug("last from:", sFrom)
			if index >= sFrom then
				local itemIndex = index - sFrom + 1
--				log:debug("item ", index, " found in last_indexed_chunk")
				return last["item_loop"][itemIndex], current
			end
		end
	end

	while next do

		local sTo = next["_to"]
		
		if index <= sTo then
			local sFrom = next["_from"]
			if index >= sFrom then
				local itemIndex = index - sFrom + 1
				self.last_indexed_chunk = next
--				log:debug("item ", index, " found")
				return next["item_loop"][itemIndex], current
			end
		end
		next = next["_next"]
	end

--	log:debug("item ", index, " NOT found")
end


function missing(self, maxQty)

	-- use our cached result
	if self.complete then
		log:debug(self, " complete (cached)")
		return
	end
	
	local next = self.head	
	local pTo = 0
	local sFrom
	local sTo = 0

	while next do
		sFrom = next["_from"]
		sTo = next["_to"]

		if sFrom != pTo + 1 then
			-- hole from pTo + 1 until sFrom - 1
			local from = pTo + 1
			local to = sFrom - 1
			local qty = to - from + 1
			if maxQty and qty > maxQty then
				qty = maxQty
			end
			-- sanity check
			if qty < 0 then
				return
			end
			-- outside world is 0 based!
			log:debug(self, " missing ", qty, " items from pos ", from)
			return from - 1, qty
		end
		pTo = sTo
		next = next["_next"]
	end

	if sTo != self.count then
		-- hole from sTo + 1 until count
		local from = sTo + 1
		local to = self.count
		local qty = to - from + 1
		if maxQty and qty > maxQty then
			qty = maxQty
		end
		-- sanity check
		if qty < 0 then
			return
		end
		-- outside world is 0 based!
		log:debug(self, " missing ", qty, " items from pos ", from)
		return from - 1, qty
	end
	
	-- if we reach here we're complete (for next time)
	log:debug(self, " complete (calculated)")
	self.complete = true
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

