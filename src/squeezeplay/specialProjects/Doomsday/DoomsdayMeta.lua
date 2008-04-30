local oo            = require("loop.simple")
local AppletMeta    = require("jive.AppletMeta")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function defaultSettings(meta)
        return {
                currentSetting = 0,
        }
end

function registerApplet(meta)
	
	jiveMain:addItem(meta:menuItem('doomsdayApplet', 'home', "DOOMSDAY", function(applet, ...) applet:menu(...) end, 20))

end
