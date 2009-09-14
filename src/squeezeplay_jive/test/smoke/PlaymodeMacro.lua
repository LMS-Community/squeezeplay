
-- go home
macroHome(500)

-- select Now Playing
if not macroSelectMenuItem(100, "Now Playing") then
	return macro_fail("Now Playing")
end

-- key go into Now Playing
macroEvent(1000, EVENT_KEY_PRESS, KEY_GO)

-- play, wait until after show briefly
macroEvent(5000, EVENT_KEY_PRESS, KEY_PLAY)
if not macroScreenshot(1000, "PlaymodePlay") then
	return macro_fail("Playmode Play")
end

-- pause, wait until after show briefly
macroEvent(5000, EVENT_KEY_PRESS, KEY_PAUSE)
if not macroScreenshot(1000, "PlaymodePause") then
	return macro_fail("Playmode Pause")
end

-- stop (hold pause), wait until after show briefly
macroEvent(5000, EVENT_KEY_HOLD, KEY_PAUSE)
if not macroScreenshot(1000, "PlaymodeStop") then
	return macro_fail("Playmode Stop")
end


macro_pass("Playmode")
