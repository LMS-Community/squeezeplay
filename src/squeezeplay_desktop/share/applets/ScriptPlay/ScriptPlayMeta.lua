
--[[
=head1 NAME

applets.ScriptPlay.ScriptPlayMeta - ScriptPlay meta-info

=head1 DESCRIPTION

See L<applets.ScriptPlay.ScriptPlayApplet>.

=head1 FUNCTIONS

See L<jive.AppletMeta> for a description of standard applet meta functions.

=cut
--]]


local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function defaultSettings(meta)
end


function registerApplet(meta)
	meta:registerService("runScript")
end

function configureApplet(self)
	-- nothing to do here
end
