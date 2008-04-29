
-- go home
macroHome(100)

-- select Now Playing
macroSelectMenuItem(100, "Now Playing")

-- key go into Now Playing
macroEvent(100, EVENT_KEY_PRESS, KEY_GO)


-- stop (hold pause), wait until after show briefly
macroEvent(5000, EVENT_KEY_HOLD, KEY_PAUSE)
if not macroScreenshot(1000, "PlaymodeStop") then
	return macroFail("Playmode Stop")
end

-- play, wait until after show briefly
macroEvent(5000, EVENT_KEY_PRESS, KEY_PLAY)
if not macroScreenshot(1000, "PlaymodePlay") then
	return macroFail("Playmode Play")
end

-- pause, wait until after show briefly
macroEvent(5000, EVENT_KEY_PRESS, KEY_PAUSE)
if not macroScreenshot(1000, "PlaymodePause") then
	return macroFail("Playmode Pause")
end

macroPass("Playmode")
