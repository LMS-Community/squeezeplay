--------------------------------------------------------------------------------
-- Project: Library Generation Utilities                                      --
-- Release: 1.0 alpha                                                         --
-- Title  : Pre-Loader of Pre-Compiled Lua Script Files                       --
-- Author : Renato Maia <maia@inf.puc-rio.br>                                 --
-- Date   : 13/12/2004 13:51                                                  --
--------------------------------------------------------------------------------

local FILE_SEP = "/"
local FUNC_SEP = "_"
local PACK_SEP = "."
local INIT_PAT = "init$"
local PATH_PAT = FILE_SEP.."$"
local OPEN_PAT = "int%s+luaopen_([%w_]+)%s*%(%s*lua_State%s*%*[%w_]*%);"

local Options = {
	directory = ".",
	filename  = "preload",
	prefix    = "LUAPRELOAD_API",
	includes  = {},
}

local Alias = {
	d = "directory",
	f = "filename",
	p = "prefix",
	I = "includes",
}

function adjustpath(path)
	if string.find(path, PATH_PAT)
		then return path
		else return path..FILE_SEP
	end
end

function processargs(arg)
	local i = 1
	if not arg then
		io.stderr:write([[
Script for generation of code that pre-loads pre-compiled Lua packages.
By Renato Maia <maia@tecgraf.puc-rio.br>

usage: lua preloader.lua [options] <headers>
  
  options:
  
  -d, -directory  Directory where the output files should be generated. Its
                  default is the current directory.
  
  -f, -filename   Name used to form the name of the files generated. Two files
                  are generated: a source code file with the sufix '.c' with
                  the pre-loading code and a header file with the suffix '.h'
                  with the function that pre-loads the scripts. Its default is
                  'preload'.
  
  -I, -includes   Adds a directory to the list of paths where the header files
                  of pre-compiled libraries are searched.
  
  -p, -prefix     Prefix added to the signature of the functions generated.
                  Its default is LUAPRELOAD_API.
]])
		os.exit(1)
	end
	while arg[i] do
		local opt = string.match(arg[i], "^%-(.+)$")
		if not opt then break end
		
		opt = Alias[opt] or opt
		local opkind = type(Options[opt])
		if opkind == "boolean" then
			Options[opt] = true
		elseif opkind == "number" then
			i = i + 1
			Options[opt] = tonumber(arg[i])
		elseif opkind == "string" then
			i = i + 1
			Options[opt] = arg[i]
		elseif opkind == "table" then
			i = i + 1
			table.insert(Options[opt], arg[i])
		else
			io.stderr:write("unknown option ", opt)
		end
		
		i = i + 1
	end
	return i, table.getn(arg)
end

function openfile(name)
	local file = io.open(name)
	if not file then
		for _, path in ipairs(Options.includes) do
			path = adjustpath(path)
			file = io.open(path..name)
			if file then break end
		end
	end
	return file
end

--------------------------------------------------------------------------------

local start, finish = processargs(arg)

Options.directory = adjustpath(Options.directory)
local filepath    = Options.directory..Options.filename

--------------------------------------------------------------------------------

local outh = assert(io.open(filepath..".h", "w"))
outh:write([[
#ifndef __]],string.upper(Options.filename),[[__
#define __]],string.upper(Options.filename),[[__

#ifndef ]],Options.prefix,[[ 
#define ]],Options.prefix,[[ 
#endif

]],Options.prefix,[[ int luapreload_]],Options.filename,[[(lua_State *L);

#endif /* __]],string.upper(Options.filename),[[__ */
]])
outh:close()

--------------------------------------------------------------------------------

local outc = assert(io.open(filepath..".c", "w"))
outc:write([[
#include <lua.h>
#include <lauxlib.h>

#ifdef COMPAT_51
#include "compat-5.1.h"
#endif

]])

for i = start, finish do local file = arg[i]
	outc:write('#include "',file,'"\n')
end

outc:write([[
#include "]],Options.filename,[[.h"

]],Options.prefix,[[ int luapreload_]],Options.filename,[[(lua_State *L) {
  luaL_findtable(L, LUA_GLOBALSINDEX, "package.preload", ]], finish, [[);

]])

for i = start, finish do local file = arg[i]
	local input = assert(openfile(file), "unable to open input file "..file)
	local header = input:read("*a")
	input:close()
	for func in string.gmatch(header, OPEN_PAT) do
		local pack = string.gsub(func, FUNC_SEP, PACK_SEP)
		outc:write([[
	lua_pushcfunction(L, luaopen_]],func,[[);
	lua_setfield(L, -2, "]],pack,[[");
]])
	end
end

outc:write([[

	lua_pop(L, 1);
	return 0;
}
]])

outc:close()
