
-- go home
macroHome()

-- key down until Now Playing
while not macroIsMenuItem("Now Playing") do
	macroEvent(100, EVENT_KEY_PRESS, KEY_DOWN)
end

-- key go into Now Playing
macroEvent(100, EVENT_KEY_PRESS, KEY_GO)

-- capture screenshot
if not macroScreenshot(100, "NowPlaying") then
	return macroFail("Screenshot")
end

macroPass("Finished")
