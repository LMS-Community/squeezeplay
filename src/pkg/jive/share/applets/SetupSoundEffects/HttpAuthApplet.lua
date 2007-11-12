
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
local log             = require("jive.utils.log").logger("applets.setup")

module(...)
oo.class(_M, Applet)


function settingsShow(self)
	-- setup menu
	local window = Window("window", self:string("HTTP_AUTH", 'settingstitle'))
	local menu = SimpleMenu("menu",
	{
		-- username
		{	
			text = self:string("HTTP_AUTH_USERNAME"),
			callback = function(event, menuItem)
				self:enterTextWindow('username', menuItem)
			end
		},
		-- password
		{
			text = self:string("HTTP_AUTH_PASSWORD"),
			callback = function(event, menuItem)
				self:enterTextWindow('password', menuItem)
			end
		}
	})
		
	window:addWidget(Textarea("help", self:string("HTTP_AUTH_HELP")))
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end

function enterTextWindow(self, userOrPass, menuItem)
	local window = Window("window", menuItem.text)

	local helpText = self:string("HTTP_AUTH_ENTER_HELP", userOrPass)

	local defaultText = self:getSettings()[userOrPass]
	if defaultText == nil then
		defaultText = ""
	end

	local input = Textinput("textinput", defaultText,
				function(_, value)
					log:warn("Input ", value)
					self:storeInput(userOrPass, value)
					window:hide(Window.transitionPushLeft)
					return true
				end)

	window:addWidget(Textarea("softHelp", helpText))
	window:addWidget(Label("softButton1", "Insert"))
	window:addWidget(Label("softButton2", "Delete"))
	window:addWidget(input)

	self:tieAndShowWindow(window)
	return window
end

function storeInput(self, userOrPass, value)
	self:getSettings()[userOrPass] = value
	self:storeSettings()
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

