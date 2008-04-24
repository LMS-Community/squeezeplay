return {
  auto=1,
  autostart={ "forcedUpgrade", "softwareUpgrade", "playmode" },
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
    } 
  } 
}