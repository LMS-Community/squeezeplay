#!/bin/bash

##
## This script is a basic startup script for the SqueezePlay binary (jive) that requires a few environment variables be set.
##

## Change these if you changed your install path
INSTALL_DIR=/opt/squeezeplay
LIB_DIR=$INSTALL_DIR/lib
INC_DIR=$INSTALL_DIR/include

## Start up
export LD_LIBRARY_PATH=$LIB_DIR:$LD_LIBRARY_PATH
export LD_INCLUDE_PATH=$INC_DIR:$LD_INCLUDE_PATH
export PATH=$PATH:$INSTALL_DIR/bin

# Portaudio
#
# export USEPADEVICE=null
# export USEPAMAXSAMPLERATE=48000
#
# Portaudio v19
#
# export USEPAHOSTAPI=null
# export USEPALATENCY=86
#
# Portaudio v18
#
# export USEPADEVICEID=null
# export USEPAFRAMESPERBUFFER=8192
# export USEPANUMBEROFBUFFERS=3
#
# ALSA
#
# export USEALSADEVICE=default
# export USEALSACAPTURE=default
# export USEALSASAMPLESIZE=16
#
# Squeezeplay Debug
#
# export SQUEEZEPLAY_DECODE_DEBUG=1
# export SQUEEZEPLAY_UPLOAD=1

cd $INSTALL_DIR/bin
./jive

