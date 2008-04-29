

-- kill screensaver (if any) and check that the upgrade screen
-- was locked the ui, we don't expect this key press to go home
macroEvent(100, EVENT_KEY_PRESS, KEY_HOME)

-- check screen
if not macroScreenshot(1000, "ForcedUpgrade") then
	return macroFail("ForcedUpgrade")
end


-- Begin update
macroSelectMenuItem(100, "Begin update")
macroEvent(1000, EVENT_KEY_PRESS, KEY_GO)

if not macroScreenshot(1000, "CopyingUpdate") then
	return macroFail("CopyingUpdate")
end

macroPass("SoftwareUpgrade")

-- 5 minute delay to allow upgrade to complete, this is never expected
-- to return
macroDelay(300000)
macroFail("Timeout")
