
-- go home
macroHome(500)


-- Settings
if not macroSelectMenuItem(100, "Settings") then
	return macro_fail("Settings")
end
macroEvent(1000, EVENT_KEY_PRESS, KEY_GO)

if not macroScreenshot(1000, "Settings") then
	return macro_fail("Settings")
end


-- Advanced
if not macroSelectMenuItem(100, "Advanced") then
	return macro_fail("Advanced")
end
macroEvent(1000, EVENT_KEY_PRESS, KEY_GO)

if not macroScreenshot(1000, "Advanced") then
	return macro_fail("Advanced")
end


-- Software Update
if not macroSelectMenuItem(100, "Software Update") then
	return macro_fail("SoftwareUpdate")
end
macroEvent(1000, EVENT_KEY_PRESS, KEY_GO)

if not macroScreenshot(1000, "SoftwareUpdate") then
	return macro_fail("SoftwareUpdate")
end


-- Begin update
if not macroSelectMenuItem(100, "Begin update") then
	return macro_fail("CopyingUpdate")
end
macroEvent(1000, EVENT_KEY_PRESS, KEY_GO)

if not macroScreenshot(1000, "CopyingUpdate") then
	return macro_fail("CopyingUpdate")
end

macro_pass("SoftwareUpgrade")

-- 5 minute delay to allow upgrade to complete, this is never expected
-- to return
macroDelay(300000)
macro_fail("Timeout")
