
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


-- Factory Reset
macroSelectMenuItem(100, "Factory Reset")
macroEvent(500, EVENT_KEY_PRESS, KEY_GO)

if not macroScreenshot(1000, "FactoryReset1") then
	return macroFail("FactoryReset1")
end


-- Begin update
macroSelectMenuItem(100, "Continue")
macroEvent(1000, EVENT_KEY_PRESS, KEY_GO)

if not macroScreenshot(1000, "FactoryReset2") then
	return macroFail("FactoryReset2")
end

macroPass("FactoryReset")

-- 1 minute delay to allow upgrade to complete, this is never expected
-- to return
macroDelay(60000)
macroFail("Timeout")
