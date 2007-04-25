
--[[
=head1 NAME

jive.ui.Textarea - A text area widget.

=head1 DESCRIPTION

A text area widget, extends L<jive.ui.Widget>.

=head1 SYNOPSIS

 -- Create a new text area
 local textarea = jive.ui.Textarea("text", "This is some\ntext that spans\nseveral lines")

 -- Scroll the text down by 2 lines
 textarea:scroll(2)

 -- Set the text
 textarea:setText("Different text")

=head1 STYLE

The Label includes the following style parameters in addition to the widgets basic parameters.

=over

B<bg> : the background color, defaults to no background color.

B<fg> : the foreground color, defaults to black.

B<bg_img> : the background image.

B<font> : the text font, a L<jive.ui.Font> object.

B<line_height> : the line height to use, defaults to the font ascend height.
=back

B<text_align> : the text alignment.

=head1 METHODS

=cut
--]]


-- stuff we use
local assert, string, tostring, type = assert, string, tostring, type

local oo	= require("loop.simple")
local Widget	= require("jive.ui.Widget")
local Slider	= require("jive.ui.Slider")

local EVENT_SCROLL	= jive.ui.EVENT_SCROLL
local EVENT_KEY_PRESS	= jive.ui.EVENT_KEY_PRESS

local EVENT_CONSUME	= jive.ui.EVENT_CONSUME
local EVENT_UNUSED	= jive.ui.EVENT_UNUSED

local KEY_FWD		= jive.ui.KEY_FWD
local KEY_REW		= jive.ui.KEY_REW
local KEY_GO		= jive.ui.KEY_GO
local KEY_BACK		= jive.ui.KEY_BACK
local KEY_UP          = jive.ui.KEY_UP
local KEY_DOWN        = jive.ui.KEY_DOWN
local KEY_LEFT        = jive.ui.KEY_LEFT
local KEY_RIGHT       = jive.ui.KEY_RIGHT


-- our class
module(...)
oo.class(_M, Widget)


--[[

=head2 jive.ui.Textarea(style, text)

Construct a new Textarea widget. I<style> is the widgets style. I<text> is the initial text displayed.

=cut
--]]
function __init(self, style, text)
	assert(type(style) == "string")
	assert(type(text) == "string")

	local obj = oo.rawnew(self, Widget(style))
	obj.scrollbar = Slider("scrollbar")
	obj.scrollbar.parent = obj
	
	obj.topLine = 0
	obj.visibleLine = 0
	obj.text = text

	obj:addListener(EVENT_SCROLL | EVENT_KEY_PRESS,
			 function (event)
				return obj:_eventHandler(event)
			 end)
	
	return obj
end


--[[

=head2 jive.ui.Textarea:getText()

Returns the text contained in this Textarea.

=cut
--]]
function getText(self)
	return self.text
end


--[[

=head2 jive.ui.Textarea:setText(text)

Sets the text in the Textarea to I<text>.

=cut
--]]
function setText(self, text)
	assert(type(text) == "string")

	self.text = text

	self:layout()
end


--[[

=head2 jive.ui.Textarea:isScrollable()

Returns true if the textarea is scrollable, otherwise it returns false.

=cut
--]]
function isScrollable(self)
	return true -- #self.items > self.visibleItems
end


--[[

=head2 jive.ui.Textarea:scrollBy(scroll)

Scroll the Textarea by I<scroll> items. If I<scroll> is negative the text scrolls up, otherwise the text scrolls down.

=cut
--]]
function scrollBy(self, scroll)
	assert(type(scroll) == "number")

	self.topLine = self.topLine + scroll

	if self.topLine < 0 then
		self.topLine = 0
	end
	if self.topLine + self.visibleLines > self.numLines then
		self.topLine = self.numLines - self.visibleLines
	end

	self.scrollbar:setScrollbar(0, self.numLines, self.topLine + 1, self.visibleLines)
	self:dirty()
end


function _eventHandler(self, event)
	local type = event:getType()

	if type == EVENT_SCROLL then

		self:scrollBy(event:getScroll())
		return EVENT_CONSUME
		
	elseif type == EVENT_KEY_PRESS then
		local keycode = event:getKeycode()

		if keycode == KEY_UP then
			self:scrollBy( -(self.visibleLines - 1) )
			return EVENT_CONSUME

		elseif keycode == KEY_DOWN then
			self:scrollBy( self.visibleLines - 1 )
			return EVENT_CONSUME

		elseif keycode == KEY_GO or
			keycode == KEY_RIGHT then
			self:getWindow():bumpRight()
			return EVENT_CONSUME

		elseif keycode == KEY_BACK or
			keycode == KEY_LEFT then
			self:hide()
			return EVENT_CONSUME
		end

	end

	return EVENT_UNUSED
end

--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

