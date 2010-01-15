
--[[
=head1 NAME

jive.System - system properties

=head1 DESCRIPTION

Access system specific properties, including files.


=head2 System:getUUID()

Return the SqueezePlay UUID.

=head2 System:getMacAddress()

Return the mac address, used as a unique id by SqueezePlay.

=head2 System:getArch()

Return the system architecture (e.g. i386, armv5tejl, etc).

=head2 System:getMachine()

Return the machine (e.g. squeezeplay, jive, etc).

=head2 System:getUserPath()

Return the user-specific path that holds settings, 3rd-party applets, wallpaper, etc. The path is part of the overall Lua path.

=head2 System.findFile(path)

Find a file on the lua path. Returns the full path of the file, or nil if it was not found.

--]]

local oo           = require("loop.simple")


-- our class
module(...)
oo.class(_M, System)


function isHardware(class)
	return (class:getMachine() ~= "squeezeplay")
end


-- C implementation


--[[

=head1 LICENSE

Copyright 2010 Logitech. All Rights Reserved.

This file is licensed under BSD. Please see the LICENSE file for details.

=cut
--]]

