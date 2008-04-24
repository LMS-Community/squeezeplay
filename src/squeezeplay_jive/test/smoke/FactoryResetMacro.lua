
-- go home
macroHome()


-- Settings
while not macroIsMenuItem("Settings") do
	macroEvent(100, EVENT_KEY_PRESS, KEY_DOWN)
end
macroEvent(100, EVENT_KEY_PRESS, KEY_GO)

if not macroScreenshot(1000, "Settings") then
	return macroFail("Settings")
end


-- Advanced
while not macroIsMenuItem("Advanced") do
	macroEvent(100, EVENT_KEY_PRESS, KEY_DOWN)
end
macroEvent(100, EVENT_KEY_PRESS, KEY_GO)

if not macroScreenshot(1000, "Advanced") then
	return macroFail("Advanced")
end


-- Factory Reset
while not macroIsMenuItem("Factory Reset") do
	macroEvent(100, EVENT_KEY_PRESS, KEY_DOWN)
end
macroEvent(500, EVENT_KEY_PRESS, KEY_GO)

if not macroScreenshot(1000, "FactoryReset1") then
	return macroFail("FactoryReset1")
end


-- Begin update
while not macroIsMenuItem("Continue") do
	macroEvent(100, EVENT_KEY_PRESS, KEY_DOWN)
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
