
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

	if cli.cmdArray then
		
		local c = {}
		for _, cmdTerm in ipairs(cli.cmdArray) do
			table.insert(c, cmdTerm)
		end
		
		if cli.pageFrom then
			table.insert(c, cli.pageFrom)
		end
		
		if cli.pageQty then
			table.insert(c, cli.pageQty)
		end
		
		if cli.params then
			
			for k, v in pairs(cli.params) do
				table.insert(c, k .. ":" .. v)
			end
		end
		
--		t["cmd"] = c
		table.insert(t, c)
	end
	
	log:debug(t)
	
	return t
end


function jive.slim.RequestCli:__init(sink, player, cmdArray, from, qty, params, options)
	log:debug("RequestCli:__init()")
	
	assert(cmdArray)
	
	local cli = {
		["cmdArray"] = cmdArray,
		["pageFrom"] = from or false,
		["pageQty"] = qty or false,
		["params"] = params or {},
		["player"] = player or false,
	}	

	local obj = oo.rawnew(self, RequestJsonRpc(
		sink, 
		'jsonrpc.js', 
		'slim.request', 
		_calcParams(cli), 
		options))
		
	obj.cli = cli

	return obj
end


-- __tostring
-- handy for debugging
function jive.slim.RequestCli:__tostring()
	if self.cli.cmdArray then
		return "RequestCli {" .. table.concat(self.cli.cmdArray, " ") .. "}"
	else
		return "RequestCli {}"
	end
end


-----------------------------------------------------------------------------
-- RequestCliXJive
-----------------------------------------------------------------------------
jive.slim.RequestCliXJive = oo.class({}, jive.slim.RequestCli)

function jive.slim.RequestCliXJive:__init(sink, player, cmdArray, from, qty, timeout, params, options)
	log:debug("RequestCliXJive:__init()")
	
	if timeout then
		log:debug("RequestCliXJive:__init: timeout: ", tostring(timeout))
		if not params then
			params = {}
		end
		params["subscribe"] = timeout
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
		cmdArray, 
		from, 
		qty, 
		params, 
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
	if self.cli.cmdArray then
		return "RequestCliXJive {" .. table.concat(self.cli.cmdArray, " ") .. "}"
	else
		return "RequestCliXJive {}"
	end
end


-----------------------------------------------------------------------------
-- RequestServerstatus
-----------------------------------------------------------------------------
jive.slim.RequestServerstatus = oo.class({}, jive.slim.RequestCliXJive)

function jive.slim.RequestServerstatus:__init(sink, from, qty, timeout, params, options)
	log:debug("RequestServerstatus:__init()")

	return oo.rawnew(self, jive.slim.RequestCliXJive(
		sink, 
		nil, 
		{'serverstatus'}, 
		from or 0, 
		qty or 50, 
		timeout, 
		params, 
		options))
end




-- __tostring
-- handy for debugging
function jive.slim.RequestServerstatus:__tostring()
	if self.cli.cmdArray then
		return "RequestServerstatus {" .. table.concat(self.cli.cmdArray, " ") .. "}"
	else
		return "RequestServerstatus {}"
	end
end


-----------------------------------------------------------------------------
-- RequestStatus
-----------------------------------------------------------------------------
jive.slim.RequestStatus = oo.class({}, jive.slim.RequestCliXJive)

function jive.slim.RequestStatus:__init(sink, player, from, qty, timeout, params, options)
	log:debug("RequestStatus:__init()")
	
	assert(player, "Cannot create RequestStatus without player")
	
	return oo.rawnew(self, jive.slim.RequestCliXJive(
		sink, 
		player, 
		{'status'}, 
		from or "-", 
		qty or 10, 
		timeout, 
		params, 
		options))
end




-- __tostring
-- handy for debugging
function jive.slim.RequestStatus:__tostring()
	if self.cli.cmdArray then
		return "RequestStatus {" .. table.concat(self.cli.cmdArray, " ") .. "}"
	else
		return "RequestStatus {}"
	end
end


-----------------------------------------------------------------------------
-- RequestDisplaystatus
-----------------------------------------------------------------------------
jive.slim.RequestDisplaystatus = oo.class({}, jive.slim.RequestCliXJive)

function jive.slim.RequestDisplaystatus:__init(sink, player, subscribe)
	log:debug("RequestDisplaystatus:__init()")
	
	assert(player, "Cannot create RequestDisplaystatus without player")
	
	return oo.rawnew(self, jive.slim.RequestCliXJive(
		sink, 
		player, 
		{'displaystatus'}, 
		nil, 
		nil, 
		subscribe, 
		nil, 
		nil))
end




-- __tostring
-- handy for debugging
function jive.slim.RequestDisplaystatus:__tostring()
	if self.cli.cmdArray then
		return "RequestDisplaystatus {" .. table.concat(self.cli.cmdArray, " ") .. "}"
	else
		return "RequestDisplaystatus {}"
	end
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

