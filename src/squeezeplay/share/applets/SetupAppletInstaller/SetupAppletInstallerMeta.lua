
--[[
=head1 NAME

applets.SetupAppletInstaller.SetupAppletInstallerMeta - SetupAppletInstaller meta-info

=head1 DESCRIPTION

See L<applets.SetupAppletInstaller.SetupAppletInstallerApplet>.

=head1 FUNCTIONS

See L<jive.AppletMeta> for a description of standard applet meta functions.

=cut
--]]


local oo            = require("loop.simple")

local jiveMain      = jiveMain
local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local jnt           = jnt

module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 1, 1
end

function defaultSettings(self)
	return {}
end

function registerApplet(self)
	jnt:subscribe(self)
	self.menu = self:menuItem('appletSetupAppletInstaller', 'hidden', self:string("APPLET_INSTALLER"), function(applet, ...) applet:menu(...) end)
	-- to begin with, we place this in the 'hidden' node
	jiveMain:addItem(self.menu)
end

function notify_playerDelete(self, player)
	jiveMain:removeItemFromNode(self.menu, 'advancedSettings')
end

function notify_playerCurrent(self, player)
	if player == nil or ( player:getSlimServer() and player:getSlimServer():isSqueezeNetwork() ) then
		jiveMain:removeItemFromNode(self.menu, 'advancedSettings')
	else
		jiveMain:setCustomNode('appletSetupAppletInstaller', 'advancedSettings')
	end
end
