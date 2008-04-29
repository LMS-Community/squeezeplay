return {
  auto=1,
  autostart={ "forcedUpgrade", "softwareUpgrade", "factoryReset", "setupWPA", "homeMenu", "playmode" },
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
    setupWPA={
      desc="Setup using WPA network.",
      file="SetupWPAMacro.lua",
      name="Setup WPA",
      region="Europe",
      ssid="linksys",
      wpa="adgjmptw",
      player="Transporter",
    }
  } 
}