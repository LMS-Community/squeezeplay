require "syslog"

syslog.openlog("lua syslog", syslog.LOG_PERROR + syslog.LOG_ODELAY, "LOG_USER")
syslog.syslog("LOG_WARNING", "Hi all " .. os.time())
syslog.closelog()

