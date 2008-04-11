
--[[
=head1 NAME

jive.AppletManager - The applet manager.

=head1 DESCRIPTION

The applet manager discovers applets and loads and unloads them from memory dynamically.

=head1 SYNOPSIS

TODO

=head1 FUNCTIONS

=cut
--]]

-- stuff we use
local package, pairs, error, load, loadfile, io, assert = package, pairs, error, load, loadfile, io, assert
local setfenv, getfenv, require, pcall, unpack = setfenv, getfenv, require, pcall, unpack
local tostring, tonumber, collectgarbage = tostring, tonumber, collectgarbage

local string           = require("string")
                       
local oo               = require("loop.simple")
local io               = require("io")
local lfs              = require("lfs")
                       
local debug            = require("jive.utils.debug")
local log              = require("jive.utils.log").logger("applets.misc")
local locale           = require("jive.utils.locale")
local serialize        = require("jive.utils.serialize")

local JIVE_VERSION     = jive.JIVE_VERSION
local EVENT_ACTION     = jive.ui.EVENT_ACTION
local EVENT_WINDOW_POP = jive.ui.EVENT_WINDOW_POP
local EVENT_CONSUME    = jive.ui.EVENT_CONSUME
local EVENT_UNUSED     = jive.ui.EVENT_UNUSED


module(..., oo.class)


-- all the known (found) applets, indexed by applet name
local _appletsDb = {}

-- the jnt
-- note we cannot have a local jnt = jnt above because at the time AppletManager is loaded
-- the global jnt value is nil!
local jnt

-- loop detection
local _sentinel = function () end


-- _init
-- creates an AppletManager object
-- this just for the side effect of assigning our jnt local
function __init(self, thejnt)
	jnt = thejnt
	return oo.rawnew(self, {})
end


-- _saveApplet
-- creates entries for appletsDb, calculates paths and module names
local function _saveApplet(name, dir)
	log:debug("Found applet ", name, " in ", dir)
	
	if not _appletsDb[name] then
	
		local newEntry = {
			appletName = name,

			-- file paths
			metaFilepath = dir .. "/" .. name .. "/" .. name .. "Meta.lua",
			appletFilepath = dir .. "/" .. name .. "/" .. name .. "Applet.lua",
			stringsFilepath = dir .. "/" .. name .. "/" .. "strings.txt",
			settingsFilepath = dir .. "/" .. name .. "/" .. "settings.lua",

			-- lua paths
			appletModule = "applets." .. name .. "." .. name .. "Applet",
			metaModule = "applets." .. name .. "." .. name .. "Meta",

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
	log:debug("_findApplets")

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


-- _loadMeta
-- loads the meta information of applet entry
local function _loadMeta(entry)
	log:debug("_loadMeta: ", entry.appletName)

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

	-- load applet resources
	_loadLocaleStrings(entry)
	_loadSettings(entry)
	
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
--	log:debug("_ploadMeta: ", entry.appletName)
	
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
	log:debug("_loadMetas")

	for name, entry in pairs(_appletsDb) do
		if not entry.metaLoaded then
			_ploadMeta(entry)
		end
	end
end


-- _evalMeta
-- evaluates the meta information of applet entry
local function _evalMeta(entry)
	log:debug("_evalMeta: ", entry.appletName)

	entry.metaEvaluated = true

	local class = require(entry.metaModule)
	local obj = class()
 
	-- check Applet version
-- FIXME the JIVE_VERSION has changed from '1' to '7.x'. lets not break
-- the applets now.
--	local ver = tonumber(string.match(JIVE_VERSION, "(%d+)"))
	local ver = 1
	local min, max = obj:jiveVersion()
	if min < ver or max > ver then
		error("Incompatible applet " .. entry.appletName)
	end

	if not entry.settings then
		entry.settings = obj:defaultSettings()
	end

	obj._entry = entry
	obj._settings = entry.settings
	obj._stringsTable = entry.stringsTable

	-- we're good to go, the meta should now hook the applet
	-- so it can be loaded on demand.
	log:info("Registering: ", entry.appletName)
	obj:registerApplet()

	-- get rid of us
--	obj._stringsTable = nil
	obj = nil

	return true
end


-- _pevalMeta
-- pcall of _evalMeta
local function _pevalMeta(entry)
--	log:debug("_pevalMeta(", entry.appletName, ")")
	
	local ok, resOrErr = pcall(_evalMeta, entry)
	
	-- trash the meta in all cases, it's done it's job
	package.loaded[entry.metaModule] = nil
	
	-- remove strings eating up mucho valuable memory
--	entry.stringsTable = nil
	
	if not ok then
		entry.metaEvaluated = false
		entry.metaLoaded = false
		log:error("Error while evaluating meta for ", entry.appletName, ":", resOrErr)
		return nil
	end
	
	-- at this point, we have loaded the meta, the applet strings and settings
	-- performed the applet registration and we try to remove all traces of the 
	-- meta but removing it from package.loaded, deleting the string table, etc.
	
	-- we keep settings around to that we minimize writing to flash. If we wanted to
	-- trash them , we would need to store them here (to reload them if the applet ever runs)
	-- because the meta might have changed them.
	
	return resOrErr
end


-- _evalMetas
-- evaluates the meta-information of all applets
local function _evalMetas()
	log:debug("_evalMetas")

	for name, entry in pairs(_appletsDb) do
		if entry.metaLoaded and not entry.metaEvaluated then
			_pevalMeta(entry)
		end
	end
end


-- discover
-- finds and loads applets
function discover(self)
	log:debug("AppletManager:loadApplets")

	_findApplets()

	-- load the sound effects applet first so the startup
	-- sound is played without delay.
	-- FIXME make the startup order of applet configurable
	local soundEffectsEntry = _appletsDb["SetupSoundEffects"]
	_loadMeta(soundEffectsEntry)
	_evalMeta(soundEffectsEntry)

	_loadMetas()
	_evalMetas()
end


-- _loadApplet
-- loads the applet 
local function _loadApplet(entry)
	log:debug("_loadApplet: ", entry.appletName)

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

	-- load applet resources
	_loadLocaleStrings(entry)
	_loadSettings(entry)

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
--	log:debug("_ploadApplet: ", entry.appletName)
	
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
	log:debug("_evalApplet: ", entry.appletName)

	entry.appletEvaluated = true

	local class = require(entry.appletModule)
	local obj = class()

	-- we're run protected
	-- if something breaks, the pcall will catch it

	obj._entry = entry
	obj._settings = entry.settings
	obj._stringsTable = entry.stringsTable

	obj:init()

	entry.appletEvaluated = obj

	return obj
end


-- _pevalApplet
-- pcall of _evalApplet
local function _pevalApplet(entry)
--	log:debug("_pevalApplet: ", entry.appletName)
	
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
function loadApplet(self, appletName)
	log:debug("AppletManager:loadApplet: ", appletName)

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
			log:info("Loaded: ", appletName)
		end
		return obj
	end
end


-- returns true if the applet can be loaded
function hasApplet(self, appletName)
	return _appletsDb[appletName] ~= nil
end


--[[

=head2 jive.AppletManager.getAppletInstance(appletName)

Returns the loaded instance of applet I<appletName>, if any.

=cut
--]]
function getAppletInstance(self, appletName)
	local entry = _appletsDb[appletName]

	-- exists?
	if not entry then
		return nil
	end
	
	-- already loaded?
	-- appletEvaluated is TRUE while the applet is being loaded
	if entry.appletEvaluated and entry.appletEvaluated != true then
		return entry.appletEvaluated
	end

	return nil
end


-- _loadLocaleStrings
--
function _loadLocaleStrings(entry)
	if entry.stringsTable then
		return
	end

	log:debug("_loadLocaleStrings: ", entry.appletName)
	entry.stringsTable = locale:readStringsFile(entry.stringsFilepath)
end


-- _loadSettings
--
function _loadSettings(entry)
	if entry.settings then
		-- already loaded
		return
	end

	log:debug("_loadSettings: ", entry.appletName)

	local fh = io.open(entry.settingsFilepath)
	if fh == nil then
		-- no settings file
		return
	end

	local f, err = load(function() return fh:read() end)
	fh:close()

	if not f then
		log:error("Error reading ", entry.appletName, " settings: ", err)
	else
		-- evalulate the settings in a sandbox
		local env = {}
		setfenv(f, env)
		f()

		entry.settings = env.settings
	end
end


-- _storeSettings
--
function _storeSettings(entry)
	assert(entry)

	log:info("Store settings: ", entry.appletName)

	local file = assert(io.open(entry.settingsFilepath, "w"))
	serialize.save(file, "settings", entry.settings)
	file:close()
end


-- freeApplet
-- frees the applet and all resources used. returns true if the
-- applet could be freed
function freeApplet(self, appletName)
	local entry = _appletsDb[appletName]
	
	-- exists?
	if not entry then
		log:error("Cannot free unknown applet: ", appletName)
		return
	end

	_freeApplet(self, entry)
end


-- _freeApplet
--
function _freeApplet(self, entry)
	log:debug("freeApplet: ", entry.appletName)

	if entry.appletEvaluated then

		local continue = true

		local status, err = pcall(
			function()
				continue = entry.appletEvaluated:free()
			end
		)

		-- swallow any error
		
		if continue == nil then
			-- warn if applet returns nil
			log:warn(entry.appletName, ":free() returned nil")
		end

		if continue == false then
			-- the only way for continue to be false is to have the loaded applet have a free funtion
			-- that successfully executes and returns false.
			return
		end
	end
	
	log:info("Freeing: ", entry.appletName)
	
	entry.appletEvaluated = false
	entry.appletLoaded = false
	package.loaded[entry.appletModule] = nil
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

