
--[[
=head1 NAME

applets.Quit.QuitApplet - Add a main menu option to quit Jive.

=head1 DESCRIPTION

A simple applet to implement a Quit menu item

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 
QuitApplet does not override any jive.Applet method.

=cut
--]]


-- stuff we use
local oo             = require("loop.simple")

local Applet         = require("jive.Applet")

local log            = require("jive.utils.log").logger("browser")

local EVENT_CONSUME  = jive.ui.EVENT_CONSUME
local EVENT_QUIT     = jive.ui.EVENT_QUIT


module(...)
oo.class(_M, Applet)


function openWindow(menu_item)
	log:info("Quitting...")
	return nil, (EVENT_CONSUME | EVENT_QUIT)
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

