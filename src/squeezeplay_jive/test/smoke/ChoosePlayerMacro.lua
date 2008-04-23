
-- go home
macroHome()

for i=1,2 do
	-- key down until Choose Player
	while not macroIsMenuItem("Choose Player") do
		macroEvent(100, EVENT_KEY_PRESS, KEY_DOWN)
	end

	-- key go into Choose Player
	macroEvent(100, EVENT_KEY_PRESS, KEY_GO)

	-- capture screenshot
	macroScreenshot(10000, "ChoosePlayer")

	-- key back from Choose Player
	macroEvent(100, EVENT_KEY_PRESS, KEY_BACK)

	-- key down
	macroEvent(100, EVENT_KEY_PRESS, KEY_DOWN)
end

macroPass("Finished")
