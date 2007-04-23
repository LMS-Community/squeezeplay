CC = 'gcc'
CCFLAGS = ['-I/usr/include/lua5.1', '-O2', '-ansi']
#LIBPATH = ['/usr/local/lib']
LIBS = ['lua5.1', 'dl', 'm']
prefix = '/usr/local'
build_dev = 1
ENV = {'PATH': '/usr/local/bin:/bin:/usr/bin'}
tolua_bin = 'tolua++5.1'
tolua_lib = 'tolua++5.1'
TOLUAPP = 'tolua++5.1'

