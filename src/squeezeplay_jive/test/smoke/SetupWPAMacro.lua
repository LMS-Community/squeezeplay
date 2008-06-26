
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
if not macroScreenshot(1000, "ChooseLanguage") then
	return macroFail("ChooseLanguage")
end
macroEvent(1000, EVENT_KEY_PRESS, KEY_GO)


-- Welcome
if not macroScreenshot(1000, "Welcome") then
	return macroFail("Welcome")
end
macroEvent(1000, EVENT_KEY_PRESS, KEY_GO)


-- Wireless Region
if not macroScreenshot(1000, "WirelessRegion") then
	return macroFail("WirelessRegion")
end

local region = macroParameter("region")
if not macroSelectMenuItem(100, region) then
	return macroFail("Region: ", region)
end
macroEvent(1000, EVENT_KEY_PRESS, KEY_GO)


-- Finding Networks (allow 5 seconds)
macroDelay(5000)


-- Wireless Networks
if not macroScreenshot(1000, "WirelessNetworks") then
	return macroFail("WirelessNetworks")
end

local ssid = macroParameter("ssid")
if not macroSelectMenuItem(100, ssid) then
	return macroFail("SSID: ", ssid)
end
macroEvent(1000, EVENT_KEY_PRESS, KEY_GO)


local wpa = macroParameter("wpa")
if wpa ~= '' then
	-- Wireless Password
	if not macroScreenshot(1000, "WirelessPassword") then
		return macroFail("WirelessPassword")
	end
	macroTextInput(100, wpa)
	macroEvent(1000, EVENT_KEY_PRESS, KEY_GO)
end


-- Connecting to <ssid> (allow 20 seconds)
macroDelay(20000)


-- Choose Player (allow 10 seconds)
macroDelay(10000)
if not macroScreenshot(1000, "ChoosePlayer") then
	return macroFail("ChoosePlayer")
end

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
if not macroScreenshot(1000, "Continue") then
	return macroFail("Continue")
end
macroEvent(1000, EVENT_KEY_PRESS, KEY_GO)


-- All done!
macroPass("SetupWPA")
