

-- go home
macroHome(1000)

-- select top menu item
macroSelectMenuIndex(100, 1)

-- check screen
if not macroScreenshot(1000, "HomeMenu") then
	return macroFail("HomeMenu")
end

macroPass("HomeMenu")
