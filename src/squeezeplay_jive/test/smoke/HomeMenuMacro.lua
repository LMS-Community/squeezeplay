

-- go home
macroHome(1000)

-- check screen
if not macroScreenshot(1000, "HomeMenu") then
	return macroFail("HomeMenu")
end

macroPass("HomeMenu")
