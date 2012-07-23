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
-- Title  : Interactive Inspector of Application State                        --
-- Author : Renato Maia <maia@inf.puc-rio.br>                                 --
-- Date   : 27/02/2006 08:51                                                  --
--------------------------------------------------------------------------------

local type         = type
local error        = error
local xpcall       = xpcall
local rawset       = rawset
local rawget       = rawget
local select       = select
local setfenv      = setfenv
local getfenv      = getfenv
local tostring     = tostring
local loadstring   = loadstring
local getmetatable = getmetatable
local _G           = _G

local coroutine = require "coroutine"
local io        = require "io"
local debug     = require "debug"
local oo        = require "loop.base"
local Viewer    = require "loop.debug.Viewer"

module("loop.debug.Inspector", oo.class)

active = true
input = io.stdin
viewer = Viewer

local function call(self, op, ...)
	self = self[".thread"]
	if self
		then return op(self, ...)
		else return op(...)
	end
end

local self
local infoflags = "Slnuf"
local Command = {}

function Command.see(...)
	self.viewer:write(...)
	self.viewer.output:write("\n")
end

function Command.loc(which, ...)
	local level = self[".level"]
	if level then
		local index = 1
		local name, value
		repeat
			name, value = call(self, debug.getlocal, level, index)
			if not which and name then
				viewer.output:write(name)
				viewer.output:write(" = ")
				viewer:write(value)
				viewer.output:write("\n")
			elseif name == which then
			if select("#", ...) == 0
				then return value
				else return call(self, debug.setlocal, level, index, (...))
			end
			end
			index = index + 1
		until not name
	end
end

function Command.upv(which, ...)
	local func = self[".current"].func
	local index = 1
	local name, value
	repeat
		name, value = debug.getupvalue(func, index)
		if not which and name then
			viewer.output:write(name," = ")
			viewer:write(value)
			viewer.output:write("\n")
		elseif name == which then
			if select("#", ...) == 0
				then return value
				else return debug.setupvalue(func, index, (...))
			end
		end
		index = index + 1
	until not name
end

function Command.env(which, ...)
	local env = getfenv(self[".current"].func)
	if which then
		if select("#", ...) == 0
			then return env[which]
			else env[which] = (...)
		end
	else
		viewer:print(env)
	end
end

function Command.goto(where)
	local kind = type(where)
	if kind == "thread" then
		local status = coroutine.status(where)
		if status ~= "running" and status ~= "suspended" then
			error("unable to inspect an inactive thread")
		end
	elseif kind ~= "function" then
		error("invalid inspection value, got `"..kind.."' (`function' or `thread' expected)")
	end

	if self[".level"] then
		rawset(self, #self+1, self[".level"])
		rawset(self, #self+1, self[".thread"])
	else
		rawset(self, #self+1, self[".current"].func)
	end
	if kind == "thread" then
		self[".level"] = 1
		self[".thread"] = where
		self[".current"] = call(self, debug.getinfo, self[".level"], infoflags)
	else
		self[".level"] = false
		self[".thread"] = false
		self[".current"] = call(self, debug.getinfo, where, infoflags)
	end
end

function Command.goup()
	local level = self[".level"]
	if level then
		local next = call(self, debug.getinfo, level + 1, infoflags)
		if next then
			rawset(self, #self+1, -1)
			self[".level"] = level + 1
			self[".current"] = next
		else
			error("top level reached")
		end
	else
		error("unable to go up in inactive functions")
	end
end

function Command.back()
	if #self > 0 then
		local kind = type(self[#self])
		if kind == "number" then
			self[".level"] = self[".level"] + self[#self]
			self[".current"] = call(self, debug.getinfo, self[".level"], infoflags)
			self[#self] = nil
		elseif kind == "function" then
			self[".level"] = false
			self[".thread"] = false
			self[".current"] = call(self, debug.getinfo, self[#self], infoflags)
			self[#self] = nil
		else
			self[".thread"] = self[#self]
			self[#self] = nil
			self[".level"] = self[#self]
			self[#self] = nil
			self[".current"] = call(self, debug.getinfo, self[".level"], infoflags)
		end
	else
		error("no more backs avaliable")
	end
end

function Command.hist()
	local index = #self
	while self[index] ~= nil do
		local kind = type(self[index])
		if kind == "number" then
			self.viewer:print("  up one level")
			index = index - 1
		elseif kind == "function" then
			self.viewer:print("  left inactive ",self[index])
			index = index - 1
		else
			self.viewer:print("  left ",self[index] or "main thread"," at level ",self[index-1])
			index = index - 2
		end
	end
end

function Command.curr()
	local viewer = self.viewer
	local level  = self[".level"]
	if level then
		local thread = self[".thread"]
		if thread
			then viewer:write(thread)
			else viewer.output:write("main thread")
		end
		viewer:print(", level ", call(self, debug.traceback, level, level))
	else
		viewer:print("inactive function ",self[".current"].func)
	end
end

function Command.done()
	while #self > 0 do
		self[#self] = nil
	end
	self[".thread"] = false
	self[".level"] = false
	self[".current"] = false
end

--------------------------------------------------------------------------------

function __index(inspector, field)
	if rawget(_M, field) ~= nil then
		return rawget(_M, field)
	end
	
	if Command[field] then
		self = inspector
		return Command[field]
	end

	local name, value
	
	local func = rawget(inspector, ".level")
	if func then
		local index = 1
		repeat
			name, value = call(inspector, debug.getlocal, func, index)
			if name == field
				then return value
				else index = index + 1
			end
		until not name
	end
	
	local func = rawget(inspector, ".current")
	if func then
		func = func.func
		local index = 1
		repeat
			name, value = debug.getupvalue(func, index)
			if name == field
				then return value
				else index = index + 1
			end
		until not name
		
		value = getfenv(func)[field]
		if value ~= nil then return value end
	end
	
	return _G[field]
end

function __newindex(inspector, field, value)
	if rawget(_M, field) ~= nil then
		rawset(inspector, field, value)
	end
	
	local name
	local index
	local func = inspector[".level"]
	if func then
		index = 1
		repeat
			name = call(inspector, debug.getlocal, func, index)
			if name == field
				then return call(inspector, debug.setlocal, func, index, value)
				else index = index + 1
			end
		until not name
	end
	
	func = inspector[".current"].func
	index = 1
	repeat
		name = debug.getupvalue(func, index)
		if name == field
			then return debug.setupvalue(func, index, value)
			else index = index + 1
		end
	until not name

	getfenv(func)[field] = value
end

local function results(self, success, ...)
	if not success then
		io.stderr:write(..., "\n")
	elseif select("#", ...) > 0 then
		self.viewer:write(...)
		self.viewer.output:write("\n")
	end
end
function stop(self, level)
	if self.active then
		level = level or 1
		rawset(self, ".thread", coroutine.running() or false)
		rawset(self, ".current", call(self, debug.getinfo, level + 2, infoflags))
		rawset(self, ".level", level + 5) -- call, command, <inspection>, xpcall, stop
		local viewer = self.viewer
		local input = self.input
		local cmd, errmsg
		repeat
			local info = self[".current"]
			viewer.output:write(
				info.short_src or info.what,
				":",
				(info.currentline ~= -1 and info.currentline) or
				(info.linedefined ~= -1 and info.linedefined) or "?",
				" ",
				info.namewhat,
				info.namewhat == "" and "" or " ",
				info.name or viewer:tostring(info.func),
				"> "
			)
			cmd = input:read()
			local short = cmd:match("^%s*([%a_][%w_]*)%s*$")
			if short and Command[short]
				then cmd = short.."()"
				else cmd = cmd:gsub("^%s*=", "return ")
			end
			cmd, errmsg = loadstring(cmd, "inspection")
			if cmd then
				setfenv(cmd, self)
				results(self, xpcall(cmd, debug.traceback))
			else
				io.stderr:write(errmsg, "\n")
			end
		until not rawget(self, ".current")
	end
end
