

-- go home
macroHome(1000)

-- select top menu item
macroSelectMenuIndex(100, 1)

-- check screen
if not macroScreenshot(1000, "HomeMenu") then
	return macro_fail("HomeMenu")
end

macro_pass("HomeMenu")
