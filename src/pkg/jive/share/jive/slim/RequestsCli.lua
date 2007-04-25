
--[[
=head1 NAME

jive.slim.RequestCli - Cli requests.

=head1 DESCRIPTION

TODO

=head1 SYNOPSIS

TODO

=head1 FUNCTIONS

=cut
--]]

-- stuff we use
local oo             = require("loop.simple")

local RequestJsonRpc = require("jive.net.RequestJsonRpc")

local log            = require("jive.utils.log").logger("net.cli")

-----------------------------------------------------------------------------
-- Base request class
-----------------------------------------------------------------------------
jive.slim = {}
jive.slim.RequestCli = oo.class({}, RequestJsonRpc)


local function _calcParams(cli)
	log:debug("_calcParams()")

	local t = {}
	
	if cli.player then
--		t["clientid"] = self.player:getId()
		table.insert(t, cli.player:getId())
	else
		table.insert(t, "")
	end

	if cli.cmdarray then
		
		local c = {}
		for i, cmdterm in ipairs(cli.cmdarray) do
			table.insert(c, cmdterm)
		end
		
		if cli.pagefrom then
			table.insert(c, cli.pagefrom)
		end
		
		if cli.pageto then
			table.insert(c, cli.pageto)
		end
		
		if cli.tags then
			
			for k, v in pairs(cli.tags) do
				table.insert(c, k .. ":" .. v)
			end
		end
		
--		t["cmd"] = c
		table.insert(t, c)
	end
	
	log:debug(t)
	
	return t
end


function jive.slim.RequestCli:__init(sink, player, cmdarray, from, to, tags, options)
	log:debug("RequestCli:__init()")
	
	assert(cmdarray)
	
	local cli = {
		["cmdarray"] = cmdarray,
		["pagefrom"] = from or false,
		["pageto"] = to or false,
		["tags"] = tags or {},
		["player"] = player or false,
	}	

	local obj = oo.rawnew(self, RequestJsonRpc(
		sink, 
		'/plugins/Jive/jive.js', 
		'slim.request', 
		_calcParams(cli), 
		options))
		
	obj.cli = cli

	return obj
end


-- __tostring
-- handy for debugging
function jive.slim.RequestCli:__tostring()
	if self.cli.cmdarray then
		return "RequestCli {" .. table.concat(self.cli.cmdarray, " ") .. "}"
	else
		return "RequestCli {}"
	end
end


-----------------------------------------------------------------------------
-- RequestCliXJive
-----------------------------------------------------------------------------
jive.slim.RequestCliXJive = oo.class({}, jive.slim.RequestCli)

function jive.slim.RequestCliXJive:__init(sink, player, cmdarray, from, to, timeout, tags, options)
	log:debug("RequestCliXJive:__init()")
	
	if timeout then
		log:debug("RequestCliXJive:__init: timeout: ", tostring(timeout))
		if not tags then
			tags = {}
		end
		tags["subscribe"] = timeout
		if not options then
			options = {}
		end
		if not options.headers then
			options.headers = {}
		end
		options.headers["X-Jive"] = "Jive"
	end

	return oo.rawnew(self, jive.slim.RequestCli(
		sink, 
		player, 
		cmdarray, 
		from, 
		to, 
		tags, 
		options))
end


-- t_getResponseSinkMode
-- returns the sink mode
function jive.slim.RequestCliXJive:t_getResponseSinkMode()
	log:debug("RequestCliXJive:t_getResponseSinkMode()")
	
	if self:t_getResponseHeader("X-Jive") then
		return 'jive-by-chunk'
	else
		return 'jive-concat'
	end
end


-- __tostring
-- handy for debugging
function jive.slim.RequestCliXJive:__tostring()
	if self.cli.cmdarray then
		return "RequestCliXJive {" .. table.concat(self.cli.cmdarray, " ") .. "}"
	else
		return "RequestCliXJive {}"
	end
end


-----------------------------------------------------------------------------
-- RequestServerstatus
-----------------------------------------------------------------------------
jive.slim.RequestServerstatus = oo.class({}, jive.slim.RequestCliXJive)

function jive.slim.RequestServerstatus:__init(sink, from, to, timeout, tags, options)
	log:debug("RequestServerstatus:__init()")

	return oo.rawnew(self, jive.slim.RequestCliXJive(
		sink, 
		nil, 
		{'serverstatus'}, 
		from or 0, 
		to or 50, 
		timeout, 
		tags, 
		options))
end




-- __tostring
-- handy for debugging
function jive.slim.RequestServerstatus:__tostring()
	if self.cli.cmdarray then
		return "RequestServerstatus {" .. table.concat(self.cli.cmdarray, " ") .. "}"
	else
		return "RequestServerstatus {}"
	end
end


-----------------------------------------------------------------------------
-- RequestStatus
-----------------------------------------------------------------------------
jive.slim.RequestStatus = oo.class({}, jive.slim.RequestCliXJive)

function jive.slim.RequestStatus:__init(sink, player, from, to, timeout, tags, options)
	log:debug("RequestStatus:__init()")
	
	assert(player, "Cannot create RequestStatus without player")
	
	return oo.rawnew(self, jive.slim.RequestCliXJive(
		sink, 
		player, 
		{'status'}, 
		from or "-", 
		to or 10, 
		timeout, 
		tags, 
		options))
end




-- __tostring
-- handy for debugging
function jive.slim.RequestStatus:__tostring()
	if self.cli.cmdarray then
		return "RequestStatus {" .. table.concat(self.cli.cmdarray, " ") .. "}"
	else
		return "RequestStatus {}"
	end
end
	--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

