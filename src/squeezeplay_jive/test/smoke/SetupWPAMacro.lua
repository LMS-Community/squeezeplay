
-- go home
macroHome(1000)


-- Return to Setup
if not macroSelectMenuItem(100, "Return to Setup") then
	return macroFail("Return to Setup")
end
macroEvent(1000, EVENT_KEY_PRESS, KEY_GO)


-- Choose Language
if not macroSelectMenuItem(100, "English") then
	return macroFail("English")
end
macroEvent(1000, EVENT_KEY_PRESS, KEY_GO)


-- Welcome
macroEvent(1000, EVENT_KEY_PRESS, KEY_GO)


-- Wireless Region
local region = macroParameter("region")
if not macroSelectMenuItem(100, region) then
	return macroFail("Region: ", region)
end
macroEvent(1000, EVENT_KEY_PRESS, KEY_GO)


-- Finding Networks (allow 5 seconds)
macroDelay(5000)


-- Wireless Networks
local ssid = macroParameter("ssid")
if not macroSelectMenuItem(100, ssid) then
	return macroFail("SSID: ", ssid)
end
macroEvent(1000, EVENT_KEY_PRESS, KEY_GO)


-- Wireless Password
local wpa = macroParameter("wpa")
macroTextInput(100, wpa)
macroEvent(1000, EVENT_KEY_PRESS, KEY_GO)


-- Connecting to <ssid> (allow 20 seconds)
macroDelay(20000)


-- Choose Player (allow 10 seconds)
macroDelay(10000)

local player = macroParameter("player")
if not macroSelectMenuItem(100, player) then
	return macroFail("Player: ", player)
end
macroEvent(1000, EVENT_KEY_PRESS, KEY_GO)


-- Connecting to <player> (allow 10 seconds)
macroDelay(10000)


-- That's it!
if not macroSelectMenuItem(100, "Continue") then
	return macroFail("Continue")
end
macroEvent(1000, EVENT_KEY_PRESS, KEY_GO)


-- All done!
macroPass("SetupWPA")
