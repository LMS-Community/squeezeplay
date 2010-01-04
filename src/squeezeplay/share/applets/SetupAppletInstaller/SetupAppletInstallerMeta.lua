
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

function notify_serverConnected(self, server)
	self:_checkServer()
end

function notify_serverDisconnected(self, server)
	self:_checkServer()
end

function _checkServer(self)
	for _, server in appletManager:callService("iterateSqueezeCenters") do
		if server:isConnected() and not server:isSqueezeNetwork() then
			-- found a local server - show menu entry
			jiveMain:setCustomNode('appletSetupAppletInstaller', 'advancedSettings')
			return
		end
	end
	-- hide menu entry
	jiveMain:removeItemFromNode(self.menu, 'advancedSettings')
end
