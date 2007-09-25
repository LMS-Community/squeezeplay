-----------------------------------------------------------------------------
-- perfs.lua
-----------------------------------------------------------------------------

--[[
=head1 NAME

jive.util.perfs - performance

=head1 DESCRIPTION


=head1 SYNOPSIS


=head1 FUNCTIONS

=cut
--]]

-- import some global stuff
local setmetatable, ipairs, print, tostring = setmetatable, ipairs, print, tostring

local Framework = require("jive.ui.Framework")
local jud = require("jive.utils.debug")
 
module(...)

local objects = setmetatable({}, {_mode = "k"})
local classes = {}


function check(class, obj, step)
	local time = Framework:getTicks()

	-- do we know this object
	local obj_ = objects[obj]

	if step > 1 and obj_ then
				
		obj_.times[step] = time

		-- we might have missed a step so search for the last time
		local j = step-1
		while obj_.times[j] == nil do
			j = j-1
		end

		local diff = time - obj_.times[j]

		local stats = classes[obj_.fclass][step]
		if stats then
			stats.time = stats.time + diff
			stats.cnt = stats.cnt + 1
		else
			classes[obj_.fclass][step] = {
				time = diff,
				cnt = 1,
			}
		end
	else
		--if not class or class == "" then class = "Anonymous" print("ANONYMOUS") end
		objects[obj] = {
			times = {},
			fclass = class,
		}
		objects[obj].times[step] = time
		if not classes[class] then
			classes[class] = {[1]={time=0, cnt=1}}
		end
	end
end


function dump(class)
	if class and classes[class] then
		print("Statistics for " .. class .. ":")
		for i,v in ipairs(classes[class]) do
			if i>1 then
				local stat = classes[class][i].time / classes[class][i].cnt
				print("Average time to step " .. tostring(i) .. ": " .. tostring(stat) .. " (sample:" .. tostring(classes[class][i].cnt) .. ")")
			end
		end
	end
end



--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

