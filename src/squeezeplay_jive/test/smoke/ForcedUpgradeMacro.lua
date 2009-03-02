

-- kill screensaver (if any) and check that the upgrade screen
-- was locked the ui, we don't expect this key press to go home
macroEvent(100, EVENT_KEY_PRESS, KEY_HOME)

-- check screen
if not macroScreenshot(1000, "ForcedUpgrade") then
	return macro_fail("ForcedUpgrade")
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
