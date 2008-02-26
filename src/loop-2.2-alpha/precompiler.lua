--------------------------------------------------------------------------------
-- Project: Library Generation Utilities                                      --
-- Release: 1.0 alpha                                                         --
-- Title  : Pre-Compiler of Lua Script Files                                  --
-- Author : Renato Maia <maia@inf.puc-rio.br>                                 --
-- Date   : 13/12/2004 13:51                                                  --
--------------------------------------------------------------------------------

local FILE_SEP = "/"
local FUNC_SEP = "_"
local PACK_SEP = "."
local INIT_PAT = "init$"
local PATH_PAT = FILE_SEP.."$"

local Options = {
	luapath   = ".",
	directory = ".",
	filename  = "precompiled",
	prefix    = "LUAOPEN_API",
}

local Alias = {
	l = "luapath",
	d = "directory",
	f = "filename",
	p = "prefix",
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
Script for pre-compilation of Lua script files
By Renato Maia <maia@tecgraf.puc-rio.br>

usage: lua precompiler.lua [options] <scripts>
  
  options:
  
  -d, -directory  Directory where the output files should be generated. Its
                  default is the current directory.
  
  -f, -filename   Name used to form the name of the files generated. Two files
                  are generates: a source code file with the sufix '.c' with
                  the pre-compiled scripts and a header file with the sufix
                  '.h' with function signatures. Its default is 'precompiled'.
  
  -l, -luapath    Root directory of the script files to be compiled.
                  The script files must follow the same hierarchy of the
                  packages they implement, similarly to the hierarchy imposed
                  by the value of the 'package.path' defined in the standard
                  Lua distribution. Its default is the current directory.
  
  -p, -prefix     Prefix added to the signature of the functions generated.
                  Its default is LUAOPEN_API.
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

function getname(file)
	local name = string.match(file, "(.+)%..+")
	if string.find(name, INIT_PAT) then
		name = string.sub(name, 1, -6)
	end
	return string.gsub(name, FILE_SEP, FUNC_SEP)
end

--------------------------------------------------------------------------------

local start, finish = processargs(arg)

Options.luapath   = adjustpath(Options.luapath)
Options.directory = adjustpath(Options.directory)
local filepath    = Options.directory..Options.filename

local outc = assert(io.open(filepath..".c", "w"))
local outh = assert(io.open(filepath..".h", "w"))

outh:write([[
#ifndef __]],string.upper(Options.filename),[[__
#define __]],string.upper(Options.filename),[[__

#include <lua.h>

#ifndef ]],Options.prefix,[[ 
#define ]],Options.prefix,[[ 
#endif

]])

outc:write([[
#include <lua.h>
#include <lauxlib.h>
#include "]],Options.filename,[[.h"

]])

for i = start, finish do local file = arg[i]
	local bytecodes = string.dump(assert(loadfile(Options.luapath..file)))
	outc:write("static const unsigned char B",i-start,"[]={\n")
	for index = 1, string.len(bytecodes) do
  	outc:write(string.format("%3u,", string.byte(bytecodes, index)))
		if math.fmod(index, 20) == 0 then outc:write("\n") end
  end
	outc:write("\n};\n\n")
end

for index = start, finish do local file = arg[index]
	local i = index - start
	local func = getname(file)

	outh:write(Options.prefix," int luaopen_",func,"(lua_State *L);\n")

	outc:write(
Options.prefix,[[ int luaopen_]],func,[[(lua_State *L) {
	int arg = lua_gettop(L);
	luaL_loadbuffer(L,(const char*)B]],i,[[,sizeof(B]],i,[[),"]],file,[[");
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}
]])

end

outh:write([[

#endif /* __]],string.upper(Options.filename),[[__ */
]])

outh:close()
outc:close()
