/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file contains Original Code and/or Modifications of Original Code
** as defined in and that are subject to the Logitech Public Source License 
** Version 1.0 (the "License"). You may not use this file except in
** compliance with the License.  You should obtain a copy of the License at 
** http://www.logitech.com/ and read it before using this file.  Note that
** the License is not an "open source" license, as that term is defined in
** the Open Source Definition, http://opensource.org/docs/definition.php.
** The terms of the License do not permit distribution of source code.
** 
** The Original Code and all software distributed under the License are 
** distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER 
** EXPRESS OR IMPLIED, AND LOGITECH HEREBY DISCLAIMS ALL SUCH WARRANTIES, 
** INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY, FITNESS
** FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.  Please see the License for
** the specific language governing rights and limitations under the License.
*/


/* Standard includes */
#include "common.h"

#if defined (_MSC_VER)
#include <windows.h>
#endif

/* Lua API */
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

/* Module initialization functions */
int luaopen_jive(lua_State *L);
int luaopen_jive_ui_framework(lua_State *L);


/* OPEN_ALL_STDLIBS
** If defined, we will open all standard lua libraries
*/
#define OPEN_ALL_STDLIBS

/* LUA_DEFAULT_SCRIPT
** The default script this program runs, unless another script is given
** on the command line
*/
#define LUA_DEFAULT_SCRIPT "jive.JiveMain"

/* LUA_DEFAULT_PATH
** Relative path from the standard location of jive to the directory
** containing scripts (no trailing "/")
** Default value is "../share/jive"
*/
#define LUA_DEFAULT_PATH "../share/jive"



/* GLOBALS
*/

// our lua state
static lua_State *globalL = NULL;

/* lmessage
** prints a message to std err. pname is optional 
*/
static void l_message (const char *pname, const char *msg) {

	if (pname) {
		fprintf(stderr, "%s: ", pname);
	}
		
	fprintf(stderr, "%s\n", msg);
	fflush(stderr);
}


/******************************************************************************/
/* Code below is specific to jive                                       */
/******************************************************************************/

/* openlibs
** open the libraries we want to use
*/
static void openlibs(lua_State *L) {

#ifdef OPEN_ALL_STDLIBS

	// default lua call to open all libs
	 luaL_openlibs(L);

#else
	// individual selection; in this case they must be require-d from lua
	lua_pushcfunction(L, luaopen_base);
	lua_call(L, 0, 0);
	
	lua_pushcfunction(L, luaopen_io);
	lua_call(L, 0, 0);
	
	lua_pushcfunction(L, luaopen_debug);
	lua_call(L, 0, 0);
	
	lua_pushcfunction(L, luaopen_package);
	lua_call(L, 0, 0);
	
	lua_pushcfunction(L, luaopen_string);
	lua_call(L, 0, 0);
	
	lua_pushcfunction(L, luaopen_table);
	lua_call(L, 0, 0);
	
	lua_pushcfunction(L, luaopen_math);
	lua_call(L, 0, 0);
#endif

	lua_pushcfunction(L, luaopen_thread_core);
	lua_call(L, 0, 0);

	// jive version
	lua_newtable(L);
	lua_pushstring(L, PACKAGE_VERSION);
	lua_setfield(L, -2, "JIVE_VERSION");
	lua_setglobal(L, "jive");

	// jive lua extensions
	lua_pushcfunction(L, luaopen_jive);
	lua_call(L, 0, 0);

	lua_pushcfunction(L, luaopen_jive_ui_framework);
	lua_call(L, 0, 0);
}


#if defined(WIN32)
char *realpath(const char *filename, char *resolved_name) {
	GetFullPathName(filename, PATH_MAX, resolved_name, NULL);
	return resolved_name;
}

char *dirname(char *path) {
	// FIXME
	return path;
}
#endif


/* paths_setup
** Modify the lua path and cpath, prepending standard directories
** relative to this executable.
*/
static void paths_setup(lua_State *L, char *app) {
	char *temp, *binpath, *path;

	DEBUG_TRACE("Setting up paths");

	temp = malloc(PATH_MAX+1);
	if (!temp) {
		l_message("Error", "malloc failure for temp");
		exit(-1);
	}
	binpath = malloc(PATH_MAX+1);
	if (!binpath) {
		l_message("Error", "malloc failure for binpath");
		exit(-1);
	}
	path = malloc(PATH_MAX+1);
	if (!path) {
		l_message("Error", "malloc failure for path");
		exit(-1);
	}


	// full path to jive binary
	if (app[0] == '/') {
		// we were called with a full path
		strcpy(path, app);
	}
	else {
		// add working dir + app and resolve
		getcwd(temp, PATH_MAX+1);
		strcat(temp, "/");       
		strcat(temp, app);
		realpath(temp, path);
	}

	// directory containing jive
	strcpy(binpath, dirname(path));

	DEBUG_TRACE("* Jive binary directory: %s", binpath);


	// set paths in lua (package.path & package cpath)
	lua_getglobal(L, "package");
	if (lua_istable(L, -1)) {
		luaL_Buffer b;
		luaL_buffinit(L, &b);

		// default lua path
		lua_getfield(L, -1, "path");
		luaL_addvalue(&b);
		luaL_addstring(&b, ";");

		// lua path relative to executable
#if !defined(WIN32)
		strcpy(temp, binpath);
		strcat(temp, "/../share/lua/5.1");
		realpath(temp, path);
#endif

		luaL_addstring(&b, path);
		luaL_addstring(&b, DIR_SEPARATOR_STR "?.lua;");
		luaL_addstring(&b, path);
		luaL_addstring(&b, DIR_SEPARATOR_STR "?" DIR_SEPARATOR_STR "?.lua;");

		// script path relative to executale
		strcpy(temp, binpath);
		strcat(temp, "/" LUA_DEFAULT_PATH);
		realpath(temp, path);
		DEBUG_TRACE("* Script directory: %s", path);

		luaL_addstring(&b, path);
		luaL_addstring(&b, DIR_SEPARATOR_STR "?.lua;");

		// set lua path
		luaL_pushresult(&b);

		DEBUG_TRACE("* LUA_PATH: %s", lua_tostring(L, -1));
		lua_setfield(L, -2, "path");


		luaL_buffinit(L, &b);

		// default lua cpath
		lua_getfield(L, -1, "cpath");
		luaL_addvalue(&b);
		luaL_addstring(&b, ";");

		// lua cpath
#if !defined(WIN32)
		strcpy(temp, binpath);
		strcat(temp, "/../lib/lua/5.1");
		realpath(temp, path);
#endif

		luaL_addstring(&b, path);
		luaL_addstring(&b, DIR_SEPARATOR_STR "?." LIBRARY_EXT ";");
		luaL_addstring(&b, path);
		luaL_addstring(&b, DIR_SEPARATOR_STR "?" DIR_SEPARATOR_STR "core." LIBRARY_EXT ";");

		// cpath relative to executable
		strcpy(temp, binpath);
		strcat(temp, "/" LUA_DEFAULT_PATH);
		realpath(temp, path);

		luaL_addstring(&b, path);
		luaL_addstring(&b, DIR_SEPARATOR_STR "?." LIBRARY_EXT ";");

		// set lua cpath
		luaL_pushresult(&b);

		DEBUG_TRACE("* LUA_CPATH: %s", lua_tostring(L, -1));
		lua_setfield(L, -2, "cpath");
	}
	else {
		l_message("Error", "'package' is not a table");
	}

	// pop package table off the stack
	lua_pop(L, 1); 

	free(temp);
	free(binpath);
	free(path);
}


/******************************************************************************/
/* Code below almost identical to lua code                                    */
/******************************************************************************/

/* report
** prints an error message from the lua stack if any 
*/
static int report (lua_State *L, int status) {

	if (status && !lua_isnil(L, -1)) {
	
		const char *msg = lua_tostring(L, -1);
		if (msg == NULL) {
			msg = "(error object is not a string)";
		}
		l_message("Jive", msg);
		lua_pop(L, 1);
  	}
	return status;
}


/* lstop
** manages signals during processing
*/
static void lstop (lua_State *L, lua_Debug *ar) {
	(void)ar;  /* unused arg. */
	
	lua_sethook(L, NULL, 0, 0);
	luaL_error(L, "interrupted!");
}

/* laction
** manages signals during processing
*/
static void laction (int i) {

	// if another SIGINT happens before lstop
	// terminate process (default action) 
	signal(i, SIG_DFL);
	
	lua_sethook(globalL, lstop, LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, 1);
}

/* traceback
** provides error messages
*/
static int traceback (lua_State *L) {
	
	lua_getfield(L, LUA_GLOBALSINDEX, "debug");
	if (!lua_istable(L, -1)) {
		lua_pop(L, 1);
		return 1;
	}
	
	lua_getfield(L, -1, "traceback");
	if (!lua_isfunction(L, -1)) {
		lua_pop(L, 2);
		return 1;
	}
	
	// pass error message
	lua_pushvalue(L, 1); 
	
	// skip this function and traceback
	lua_pushinteger(L, 2);
	
	// call debug.traceback
	lua_call(L, 2, 1);
	return 1;
}


/* getargs
** pushes arguments on the lua stack for the called script
*/
static int getargs (lua_State *L, char **argv, int n) {
	int narg;
	int i;
	int argc = 0;
	
	// count total number of arguments
	while (argv[argc]) {
		argc++;
	}
	
	// number of arguments to the script
	// => all arguments minus program name [0] and any other arguments found 
	// before
	narg = argc - (n + 1);
	
	// check stack has enough room
	luaL_checkstack(L, narg + 3, "too many arguments to script");
	
	// push arguments
	for (i=n+1; i < argc; i++) {
		lua_pushstring(L, argv[i]);
	}
	
	// create a table with narg array elements and n+1 non array elements
	lua_createtable(L, narg, n + 1);
	for (i=0; i < argc; i++) {
		// push the argument
		lua_pushstring(L, argv[i]);
		// insert into table (-2 on stack) [i-n] value popped from stack
		lua_rawseti(L, -2, i - n);
	}
	
	return narg;
}


/* docall
** calls the script
*/
static int docall (lua_State *L, int narg, int clear) {
	int status;
  
	// get the function index
	int base = lua_gettop(L) - narg;
  
	// push traceback function
	lua_pushcfunction(L, traceback);
  
	// put it under chunk and args
	lua_insert(L, base); 
  
	signal(SIGINT, laction);
	status = lua_pcall(L, narg, (clear ? 0 : LUA_MULTRET), base);
	signal(SIGINT, SIG_DFL);
  
	// remove traceback function
	lua_remove(L, base);  

	return status;
}


/* handle_script
** does the work, load the script
*/
static int handle_script (lua_State *L, char **argv, int n) {
	int status, narg;
	
	// do we have a script?
	// set fname to the name of the script to execute
	const char *fname;
	if (n != 0) {
		fname = argv[n];
	}
	else {
		fname = LUA_DEFAULT_SCRIPT;
	}

	l_message("\nLoading", fname);

	// use 'require' to search the lua path
	lua_getglobal(L, "require");
	lua_pushstring(L, fname);

	// collect arguments in a table on stack
	narg = getargs(L, argv, n);
	
	// name table on the stack
	lua_setglobal(L, "arg");
	
	// load and run the script
	status = docall(L, narg + 1, 0);
	return report(L, status);
}


/* Smain
** used to transfer arguments and status to protected main 
*/
struct Smain {
	int argc;
	char **argv;
	int status;
};


/* pmain
** our main, called in lua protected mode by main
*/
static int pmain (lua_State *L) {
	
	// fetch *Smain from the stack
	struct Smain *s = (struct Smain *)lua_touserdata(L, 1);
	int script = 0;
	char **argv = s->argv;
	
	// set our global state
	globalL = L;
	
	// stop collector during initialization
	lua_gc(L, LUA_GCSTOP, 0);
	
	// open libraries
	openlibs(L);
	
	// restart collector
	lua_gc(L, LUA_GCRESTART, 0);

	// setup our paths
	paths_setup(L, argv[0]);

	// do we have an argument?
	if (argv[1] != NULL) {
		script = 1;
	}
	
	// do a script
	s->status = handle_script(L, argv, script);
	if (s->status != 0) {
		return 0;
	}

	return 0;
}

/* main 
*/
int main (int argc, char **argv) {
	int status;
	struct Smain s;
	lua_State *L;

	// say hello
	l_message(NULL, "\nJive " PACKAGE_VERSION);
	
	// create state
	L = lua_open();
	if (L == NULL) {
		l_message(argv[0], "cannot create state: not enough memory");
		return EXIT_FAILURE;
	}
	
	// call our main in protected mode
	s.argc = argc;
	s.argv = argv;
	status = lua_cpcall(L, &pmain, &s);
	
	// report on any error
	report(L, status);
	
	// close state
	lua_close(L);
	
	// report status to caller
	return (status || s.status) ? EXIT_FAILURE : EXIT_SUCCESS;
}


