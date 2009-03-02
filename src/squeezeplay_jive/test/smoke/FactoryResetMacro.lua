
-- go home
macroHome()


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


-- Factory Reset
if not macroSelectMenuItem(100, "Factory Reset") then
	return macro_fail("FactoryReset1")
end
macroEvent(1000, EVENT_KEY_PRESS, KEY_GO)

if not macroScreenshot(1000, "FactoryReset1") then
	return macro_fail("FactoryReset1")
end


-- Begin update
if not macroSelectMenuItem(100, "Continue") then
	return macro_fail("FactoryReset2")
end
macroEvent(1000, EVENT_KEY_PRESS, KEY_GO)

if not macroScreenshot(100, "FactoryReset2") then
	return macro_fail("FactoryReset2")
end

macro_pass("FactoryReset")

-- 1 minute delay to allow upgrade to complete, this is never expected
-- to return
macroDelay(60000)
macro_fail("Timeout")
