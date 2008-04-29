return {
  auto=false,
  autostart={ "homeMenu", "playmode" },
  macros={
    factoryReset={
      desc="Verify a factory reset.",
      file="FactoryResetMacro.lua",
      name="Factory Reset" 
    },
    forcedUpgrade={
      desc="Forced software upgrade.",
      file="ForcedUpgradeMacro.lua",
      name="Forced Upgrade" 
    },
    homeMenu={
      desc="Verify the home menu.",
      file="HomeMenuMacro.lua",
      name="Home Menu",
      passed="Sun Apr 13 09:23:07 2008" 
    },
    playmode={
      desc="Playmode tests (stop/pause/play).",
      file="PlaymodeMacro.lua",
      name="Playmode",
      passed="Sun Apr 13 09:29:03 2008" 
    },
    softwareUpgrade={
      desc="User requested software upgrade.",
      file="SoftwareUpgradeMacro.lua",
      name="Software Upgrade" 
    } 
  } 
}