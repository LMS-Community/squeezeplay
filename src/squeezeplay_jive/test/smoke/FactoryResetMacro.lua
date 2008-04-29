
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


-- Factory Reset
if not macroSelectMenuItem(100, "Factory Reset") then
	return macroFail("FactoryReset1")
end
macroEvent(500, EVENT_KEY_PRESS, KEY_GO)

if not macroScreenshot(1000, "FactoryReset1") then
	return macroFail("FactoryReset1")
end


-- Begin update
if not macroSelectMenuItem(100, "Continue") then
	return macroFail("FactoryReset2")
end
macroEvent(1000, EVENT_KEY_PRESS, KEY_GO)

if not macroScreenshot(1000, "FactoryReset2") then
	return macroFail("FactoryReset2")
end

macroPass("FactoryReset")

-- 1 minute delay to allow upgrade to complete, this is never expected
-- to return
macroDelay(60000)
macroFail("Timeout")
