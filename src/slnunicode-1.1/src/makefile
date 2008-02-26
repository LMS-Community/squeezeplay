#------
# Load configuration
#
include ../config
include ../config_include.${PLATFORM}

#------
# Hopefully no need to change anything below this line
#

#------
# Modules belonging to socket-core
#

UNICODE_OBJS:= \
	slnunico.o 

all: $(UNICODE_SO)

$(UNICODE_SO): $(UNICODE_OBJS)
	$(CC) $(MYLDFLAGS) $(LDFLAGS) -o $@ $(UNICODE_OBJS)

.c.o:
	$(CC) $(MYCFLAGS) $(CFLAGS) $(MYCFLAGS) -c -o $@ $<

#------
# List of dependencies
#
slnunico.o: slnunico.c slnudata.c

clean:
	rm -f $(UNICODE_SO) $(UNICODE_OBJS) 

#------
# End of makefile configuration
#
