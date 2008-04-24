return {
  auto=1,
  autostart={ "homeMenu", "playmode" },
  macros={
    forcedUpgrade={
      desc="Forced software upgrade.",
      file="ForcedUpgradeMacro.lua",
      name="Forced Upgrade",
    },
    playmode={
      desc="Playmode tests (stop/pause/play).",
      file="PlaymodeMacro.lua",
      name="Playmode" 
    },
    softwareUpgrade={
      desc="User requested software upgrade.",
      file="SoftwareUpgradeMacro.lua",
      name="Software Upgrade" 
    },
    homeMenu={
      desc="Verify the home menu.",
      file="HomeMenuMacro.lua",
      name="Home Menu" 
    } 
  } 
}