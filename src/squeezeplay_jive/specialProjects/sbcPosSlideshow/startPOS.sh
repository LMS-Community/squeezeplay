#!/bin/sh

# from 7.1 forward, squeezeos-boot.sh is the boot script name

# startPos.sh should execute squeezeos-boot.sh, then start jive
/mnt/mmc/squeezeos-boot.sh
/usr/bin/jive &

