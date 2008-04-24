return {
  auto=1,
  autostart={ "softwareUpgrade", "playmode" },
  macros={
    playmode={
      desc="Playmode tests (stop/pause/play).",
      file="PlaymodeMacro.lua",
      name="Playmode" 
    },
    softwareUpgrade={
      desc="User requested software upgrade.",
      file="SoftwareUpgradeMacro.lua",
      name="Software Upgrade" 
    } 
  } 
}