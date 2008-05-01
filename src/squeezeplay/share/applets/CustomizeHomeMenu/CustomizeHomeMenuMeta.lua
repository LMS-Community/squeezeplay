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
        }
end

function registerApplet(meta)
	
	jiveMain:addItem(meta:menuItem('customizeHomeApplet', 'home', "CUSTOMIZE_HOME", function(applet, ...) applet:menu(...) end, 1))

end
