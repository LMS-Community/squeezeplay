
-- go home
macroHome()


-- Settings
if not macroSelectMenuItem(100, "Settings") then
	return macroFail("Settings")
end
macroEvent(100, EVENT_KEY_PRESS, KEY_GO)

if not macroScreenshot(1000, "Settings") then
	return macroFail("Settings")
end


-- Advanced
if not macroSelectMenuItem(100, "Advanced") then
	return macroFail("Advanced")
end
macroEvent(100, EVENT_KEY_PRESS, KEY_GO)

if not macroScreenshot(1000, "Advanced") then
	return macroFail("Advanced")
end


-- Software Update
if not macroSelectMenuItem(100, "Software Update") then
	return macroFail("SoftwareUpdate")
end
macroEvent(500, EVENT_KEY_PRESS, KEY_GO)

if not macroScreenshot(1000, "SoftwareUpdate") then
	return macroFail("SoftwareUpdate")
end


-- Begin update
if not macroSelectMenuItem(100, "Begin update") then
	return macroFail("CopyingUpdate")
end
macroEvent(1000, EVENT_KEY_PRESS, KEY_GO)

if not macroScreenshot(1000, "CopyingUpdate") then
	return macroFail("CopyingUpdate")
end

macroPass("SoftwareUpgrade")

-- 5 minute delay to allow upgrade to complete, this is never expected
-- to return
macroDelay(300000)
macroFail("Timeout")
