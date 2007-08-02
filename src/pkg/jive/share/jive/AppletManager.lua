
--[[
=head1 NAME

jive.AppletManager - The applet manager.

=head1 DESCRIPTION

TODO

=head1 SYNOPSIS

TODO

=head1 FUNCTIONS

=cut
--]]

-- stuff we use
local package, pairs, error, loadfile, io, assert = package, pairs, error, loadfile, io, assert
local setfenv, getfenv, require, pcall, unpack = setfenv, getfenv, require, pcall, unpack
local tostring, tonumber, collectgarbage = tostring, tonumber, collectgarbage

local string           = require("string")
                       
local oo               = require("loop.simple")
local lfs              = require("lfs")
                       
local Label            = require("jive.ui.Label")
                       
local log              = require("jive.utils.log").logger("applets.misc")
local locale           = require("jive.utils.locale")

local JIVE_VERSION     = jive.JIVE_VERSION
local EVENT_ACTION     = jive.ui.EVENT_ACTION
local EVENT_WINDOW_POP = jive.ui.EVENT_WINDOW_POP
local EVENT_CONSUME    = jive.ui.EVENT_CONSUME
local EVENT_UNUSED     = jive.ui.EVENT_UNUSED

local jnt              = jnt


module(..., oo.class)


-- all the found applets, indexed by applet name
local _appletsDb = {}


local _sentinel = function () end


-- _saveApplet
-- creates entries for appletsDb, calculates paths and module names
local function _saveApplet(name, dir)
	log:debug("Found applet [", name, "] in ", dir)
	
	if not _appletsDb[name] then
	
		local newEntry = {
			appletName = name,
			appletPath = dir,
			appletFilepath = dir .. "/" .. name .. "/" .. name .. "Applet.lua",
			metaFilepath = dir .. "/" .. name .. "/" .. name .. "Meta.lua",
			appletModule = "applets." .. name .. "." .. name .. "Applet",
			metaModule = "applets." .. name .. "." .. name .. "Meta",
			stringsFilepath = dir .. "/" .. name .. "/" .. "strings.txt",
			settings = false,
			metaLoaded = false,
			metaEvaluated = false,
			appletLoaded = false,
			appletEvaluated = false,
		}
		_appletsDb[name] = newEntry
	end
end


-- _findApplets
-- find the available applets and store the findings in the appletsDb
local function _findApplets()
	log:debug("_findApplets()")

	-- Find all applets/* directories on lua path
	for dir in package.path:gmatch("([^;]*)%?[^;]*;") do
	
		dir = dir .. "applets"
		log:debug("..in ", dir)
		
		local mode = lfs.attributes(dir, "mode")
		if mode == "directory" then
			for entry in lfs.dir(dir) do
				if not entry:match("^%.") then
					_saveApplet(entry, dir)
				end
			end
		end
	end
end


-- _loadLocaleStrings
function _loadLocaleStrings(entry)
	-- load the strings into a table
	if entry.stringsTable == nil then
		entry.stringsTable = locale.readStringsFile(entry.stringsFilepath)
	end
end


-- _loadMeta
-- loads the meta information of applet entry
local function _loadMeta(entry)
	log:debug("_loadMeta(", entry.appletName, ")")

	local p = entry.metaLoaded
	if p then
		if p == _sentinel then
			error (string.format ("loop or previous error loading meta '%s'", entry.appletName))
		end
		return p
	end
	local f, err = loadfile(entry.metaFilepath)
	if not f then
		error (string.format ("error loading meta `%s' (%s)", entry.appletName, err))
	end

	-- get the strings
	_loadLocaleStrings(entry)
	
	entry.metaLoaded = _sentinel
	
	-- give the function the global environment
	-- sandboxing would happen here!
	setfenv(f, getfenv(0))
	
	local res = f(entry.metaModule)
	if res then
		entry.metaLoaded = res
	end
	if entry.metaLoaded == _sentinel then
		entry.metaLoaded = true
	end
	return entry.metaLoaded
end


-- _ploadMeta
-- pcall of _loadMeta
local function _ploadMeta(entry)
--	log:debug("_ploadMeta(", entry.appletName, ")")
	
	local ok, resOrErr = pcall(_loadMeta, entry)
	if not ok then
		entry.metaLoaded = false
		log:error("Error while loading meta for ", entry.appletName, ":", resOrErr)
		return nil
	end
	return resOrErr
end


-- _loadMetas
-- loads the meta-information of all applets
local function _loadMetas()
	log:debug("_loadMetas()")

	for name, entry in pairs(_appletsDb) do
		if not entry.metaLoaded then
			_ploadMeta(entry)
		end
	end
end


-- _evalMeta
-- evaluates the meta information of applet entry
local function _evalMeta(entry)
	log:debug("_evalMeta(", entry.appletName, ")")

	entry.metaEvaluated = true

	local class = require(entry.metaModule)
	local obj = class()

	-- check Applet version
	local ver = tonumber(JIVE_VERSION)
	local min, max = obj:jiveVersion()
	if min < ver or max > ver then
		error("Incompatible applet " .. entry.appletName)
	end

	obj._stringsTable = entry.stringsTable

	-- we're good to go, the meta should now hook the applet
	-- so it can be loaded on demand.
	log:info("Registering applet ", entry.appletName)
	obj:registerApplet()

	entry.metaEvaluated = obj

	return obj
end


-- _pevalMeta
-- pcall of _evalMeta
local function _pevalMeta(entry)
--	log:debug("_pevalMeta(", entry.appletName, ")")
	
	local ok, resOrErr = pcall(_evalMeta, entry)
	if not ok then
		entry.metaEvaluated = false
		entry.metaLoaded = false
		package.loaded[entry.metaModule] = nil
		log:error("Error while evaluating meta for ", entry.appletName, ":", resOrErr)
		return nil
	end
	return resOrErr
end


-- _evalMetas
-- evaluates the meta-information of all applets
local function _evalMetas()
	log:debug("_evalMetas()")

	for name, entry in pairs(_appletsDb) do
		if entry.metaLoaded and not entry.metaEvaluated then
			_pevalMeta(entry)
		end
	end
end


-- discover
-- finds and loads applets
function discover(self)
	log:debug("AppletManager:loadApplets()")

	_findApplets()
	_loadMetas()
	_evalMetas()
end


-- _loadApplet
-- loads the applet 
local function _loadApplet(entry)
	log:debug("_loadApplet(", entry.appletName, ")")

	-- check to see if Applet is already loaded
	local p = entry.appletLoaded
	if p then
		if p == _sentinel then
			error (string.format ("loop or previous error loading applet '%s'", entry.appletName))
		end
		return p
	end
	local f, err = loadfile(entry.appletFilepath)
	if not f then
		error (string.format ("error loading applet `%s' (%s)", entry.appletName, err))
	end

	-- get the strings
	_loadLocaleStrings(entry)

	entry.appletLoaded = _sentinel
	
	-- give the function the global environment
	-- sandboxing would happen here!
	setfenv(f, getfenv(0))
	
	local res = f(entry.appletModule)
	if res then
		entry.appletLoaded = res
	end
	if entry.appletLoaded == _sentinel then
		entry.appletLoaded = true
	end
	return entry.appletLoaded
end


-- _ploadApplet
-- pcall of _loadApplet
local function _ploadApplet(entry)
--	log:debug("_ploadApplet(", entry.appletName, ")")
	
	local ok, resOrErr = pcall(_loadApplet, entry)
	if not ok then
		entry.appletLoaded = false
		log:error("Error while loading applet ", entry.appletName, ":", resOrErr)
		return nil
	end
	return resOrErr
end


-- _evalApplet
-- evaluates the applet
local function _evalApplet(entry)
	log:debug("_evalApplet(", entry.appletName, ")")

	entry.appletEvaluated = true

	local class = require(entry.appletModule)
	local obj = class()

	-- FIXME the setting should be loaded on demand
	if obj then
		if not entry.settings then
			entry.settings = obj:defaultSettings()
		end
		obj:setSettings(entry.settings)

		obj._stringsTable = entry.stringsTable
	end

	entry.appletEvaluated = obj

	return obj
end


-- _pevalApplet
-- pcall of _evalApplet
local function _pevalApplet(entry)
--	log:debug("_pevalApplet(", entry.appletName, ")")
	
	local ok, resOrErr = pcall(_evalApplet, entry)
	if not ok then
		entry.appletEvaluated = false
		entry.appletLoaded = false
		package.loaded[entry.appletModule] = nil
		log:error("Error while evaluating applet ", entry.appletName, ":", resOrErr)
		return nil
	end
	return resOrErr
end


-- load
-- loads an applet. returns an instance of the applet
function load(self, appletName)
	log:debug("AppletManager:load(", appletName, ")")

	local entry = _appletsDb[appletName]
	
	-- exists?
	if not entry then
		log:error("Unknown applet: ", appletName)
		return nil
	end
	
	-- already loaded?
	if entry.appletEvaluated then
		return entry.appletEvaluated
	end
	
	-- meta processed?
	if not entry.metaEvaluated then
		if not entry.metaLoaded and not _ploadMeta(entry) then
			return nil
		end
		if not _pevalMeta(entry) then
			return nil
		end
	end
	
	-- already loaded? (through meta calling load again)
	if entry.appletEvaluated then
		return entry.appletEvaluated
	end
	
	
	if _ploadApplet(entry) then
		local obj = _pevalApplet(entry)
		if obj then
			log:info("Loaded applet ", appletName)
		end
		return obj
	end
end


-- menuItem
-- creates a menuItem for an applet
function menuItem(self, menuName, appletName, method, ...)
	log:debug("AppletManager:menuItem(", menuName, ", ", appletName, ")")

	local args = {...}

	local menuItem = {
		text = menuName,
		callback = function(event, menuItem)
				   local window, r = self:openWindow(appletName, method, menuItem, unpack(args))
				   return r
			   end
	}

	return menuItem
end


-- getApplet
-- returns instance of the applet
function getApplet(self, appletName)
	return self:load(appletName)
end


-- openWindow
-- opens a window for the applet
function openWindow(self, appletName, method, ...)
	local window, r

	local status, err = pcall(
		function(...)
			local applet = self:load(appletName)

			if applet then
				window, r = applet[method](applet, ...)
				log:debug("WINDOW=", window, " R=", r)

				if window then
					window:addListener(EVENT_WINDOW_POP,
						function() 
							self:freeApplet(appletName) 
						end
					)
					window:show()
				end
			end
		end,
		...)

	if status == true then
		return window, r or EVENT_CONSUME
	else
		-- FIXME create error dialog
		log:error("Cannot open applet window: ", err)
		self:freeApplet(appletName)
		return nil, EVENT_UNUSED
	end
end


-- frees the applet and all resources used. returns true if the
-- applet could be freed
function freeApplet(self, appletName)
	log:debug("AppletManager:freeApplet(", appletName, ")")

	local entry = _appletsDb[appletName]
	
	-- exists?
	if not entry then
		log:error("Unknown applet: ", appletName)
		return
	end

	if entry.appletEvaluated then

		local continue = true

		local status, err = pcall(
			function()
				continue = entry.appletEvaluated:free()
			end
		)

		-- swallow any error
		-- the only way for continue to be false is to have the loaded applet have a free funtion
		-- that successfully executes and returns false.
		if not continue then
			return
		end
	end
	
	log:info("Freeing ", appletName)
	
	entry.appletEvaluated = false
	entry.appletLoaded = false
	package.loaded[entry.appletModule] = nil

	-- run the garbage collector later, some garbage may be in scope
	-- on the stack
	-- FIXME should check the garbage collector in lua is thread safe
	self.jnt:perform(
		function()
			log:debug("calling collectgarbage()")
			collectgarbage()
		end
	)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

