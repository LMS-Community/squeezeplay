# makefile for lsyslog library for Lua

# change these to reflect your Lua installation
LUA= $(LUA_SRC)
LUAINC= $(LUA)/include
LUALIB= $(LUA)/lib
LUABIN= $(LUA)/bin

# no need to change anything below here
CFLAGS= $(INCS) $(WARN) -O2 $G
WARN= -pedantic -Wall
INCS= -I$(LUAINC)

MYNAME= syslog
MYLIB= $(MYNAME)
T= $(MYLIB).so
OBJS= l$(MYLIB).o
TEST= test.lua

all:	test

test:	$T
	LUA_CPATH='./?.so' $(LUABIN)/lua -l$(MYNAME) $(TEST)

o:	$(MYLIB).o

so:	$T

$T:	$(OBJS)
	$(CC) -o $@ -shared $(OBJS)

clean:
	rm -f $(OBJS) $T core core.* a.out


