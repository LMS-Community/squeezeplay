
-- go home
macroHome()


-- Settings
macroSelectMenuItem(100, "Settings")
macroEvent(100, EVENT_KEY_PRESS, KEY_GO)

if not macroScreenshot(1000, "Settings") then
	return macroFail("Settings")
end


-- Advanced
macroSelectMenuItem(100, "Advanced")
macroEvent(100, EVENT_KEY_PRESS, KEY_GO)

if not macroScreenshot(1000, "Advanced") then
	return macroFail("Advanced")
end


-- Software Update
macroSelectMenuItem(100, "Software Update")
macroEvent(500, EVENT_KEY_PRESS, KEY_GO)

if not macroScreenshot(1000, "SoftwareUpdate") then
	return macroFail("SoftwareUpdate")
end


-- Begin update
macroSelectMenuItem(100, "Begin Update")
macroEvent(1000, EVENT_KEY_PRESS, KEY_GO)

if not macroScreenshot(1000, "CopyingUpdate") then
	return macroFail("CopyingUpdate")
end

macroPass("SoftwareUpgrade")

-- 5 minute delay to allow upgrade to complete, this is never expected
-- to return
macroDelay(300000)
macroFail("Timeout")
