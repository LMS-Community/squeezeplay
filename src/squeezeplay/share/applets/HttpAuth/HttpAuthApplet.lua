
--[[
=head1 NAME

applets.HttpAuth.HttpAuthApplet - An applet to configure user/password to SqueezeCenter

=head1 DESCRIPTION

This applets lets the user configure a username and password to SqueezeCenter

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>. 
HttpAuthApplet overrides the following methods:

=cut
--]]


-- stuff we use
local ipairs, pairs, tostring = ipairs, pairs, tostring

local table           = require("table")

local oo              = require("loop.simple")

local Applet          = require("jive.Applet")
local Framework       = require("jive.ui.Framework")
local SimpleMenu      = require("jive.ui.SimpleMenu")
local Window          = require("jive.ui.Window")
local Icon            = require("jive.ui.Icon")
local Group           = require("jive.ui.Group")
local Label           = require("jive.ui.Label")
local Choice          = require("jive.ui.Choice")
local Textarea        = require("jive.ui.Textarea")
local Textinput       = require("jive.ui.Textinput")
local Keyboard        = require("jive.ui.Keyboard")
local Button          = require("jive.ui.Button")

local SocketHttp      = require("jive.net.SocketHttp")

local log             = require("jive.utils.log").logger("applets.setup")

module(...)
oo.class(_M, Applet)


function squeezeCenterPassword(self, server, setupNext, titleStyle)
	self.server = server
	if setupNext then
		self.setupNext = setupNext
	end
	if titleStyle then
		self.titleStyle = titleStyle
	end

	self.topWindow = self:_enterTextWindow("username", "HTTP_AUTH_USERNAME", "HTTP_AUTH_USERNAME_HELP", _enterPassword)
end


function _enterPassword(self)
	self:_enterTextWindow("password", "HTTP_AUTH_PASSWORD", "HTTP_AUTH_PASSWORD_HELP", _enterDone)
end


function _enterDone(self)
	local protected, realm = self.server:isPasswordProtected()

	-- store username/password
	local settings = self:getSettings()
	settings[self.server:getName()] = {
		realm = realm,
		username = self.username,
		password = self.password
	}
	self:storeSettings()

	-- set authorization
	self.server:setCredentials({
		realm = realm,
		username = self.username,
		password = self.password,
	})

	self.username = nil
	self.password = nil

	-- FIXME delay here to check if the username/password are correct
	if self.setupNext then
		return self.setupNext()
	end

	self.topWindow:hideToTop(Window.transitionPushLeft)
end

function _helpWindow(self, title, token)
	local window = Window("window", self:string(title), self.titleStyle)
	window:setAllowScreensaver(false)
	window:addWidget(Textarea("textarea", self:string(token)))

	self:tieAndShowWindow(window)
	return window
end

function _enterTextWindow(self, key, title, help, next)
	local window = Window("window", self:string(title), self.titleStyle)

	local input = Textinput("textinput", self[key] or "",
				function(_, value)
					self[key] = value

					window:playSound("WINDOWSHOW")
					next(self)
					return true
				end)

	local helpButton = Button( 
				Label( 
					'helpTouchButton', 
					self:string("HTTP_AUTH_HELP")
				), 
				function() 
					self:_helpWindow('HTTP_AUTH', help) 
				end 
	)

	local keyboard = Keyboard("keyboard", "qwerty")

        window:addWidget(helpButton)
	window:addWidget(input)
	window:addWidget(keyboard)
	window:focusWidget(input)

	self:tieAndShowWindow(window)
	return window
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

