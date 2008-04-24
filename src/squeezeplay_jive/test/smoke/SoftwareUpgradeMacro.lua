
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


-- Software Update
while not macroIsMenuItem("Software Update") do
	macroEvent(100, EVENT_KEY_PRESS, KEY_DOWN)
end
macroEvent(500, EVENT_KEY_PRESS, KEY_GO)

if not macroScreenshot(1000, "SoftwareUpdate") then
	return macroFail("SoftwareUpdate")
end


-- Begin update
while not macroIsMenuItem("Begin update") do
	return macroEvent(100, EVENT_KEY_PRESS, KEY_DOWN)
end
macroEvent(1000, EVENT_KEY_PRESS, KEY_GO)

if not macroScreenshot(1000, "CopyingUpdate") then
	return macroFail("CopyingUpdate")
end

macroPass("SoftwareUpgrade")
