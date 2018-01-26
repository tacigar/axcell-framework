package = "axcell"
version = "0.1-1"

source = {
	url = "git://github.com/tacigar/axcell",
	tag = "v0.1-1",
}

description = {
	summary = "",
	detailed = [[

	]],
	homepage = "https://github.com/tacigar/axcell",
	license = "GPLv3",
}

dependencies = {
	"lua >= 5.3",
	"rxi-json-lua",
}

build = {
	type = "builtin",
	modules = {
		-- Lua Codes.
		["axcell"]                         = "src/init.lua",
		["axcell._detail"]                 = "src/_detail.lua",
		["axcell.client"]                  = "src/client.lua",
		["axcell.remote_client"]           = "src/remote_client.lua",
		["axcell.resource"]                = "src/resource.lua",
		["axcell.token"]                   = "src/token.lua",
		["axcell.acl"]                     = "src/acl.lua",
		["axcell.mqtt"]                    = "src/mqtt/init.lua",
		["axcell.mqtt.async_client"]       = "src/mqtt/async_client.lua",
		["axcell.mqtt.client"]             = "src/mqtt/client.lua",
		["axcell.mqtt.client_base"]        = "src/mqtt/client_base.lua",
		["axcell.util"]                    = "src/util/init.lua",
		["axcell.util.table"]              = "src/util/table.lua",
		-- C Codes.
		["axcell.mqtt.core"] = {
			sources = { "src/mqtt/mqtt.c" },
	        incdirs = { "/src/mqtt", "$(PAHO_MQTT_INCDIR)" },
	        libdirs = { "$(PAHO_MQTT_LIBDIR)" },
	        libraries = { "paho-mqtt3c" },
		},
		["axcell.mqtt.core.client_base"] = {
			sources = { "src/mqtt/client_base.c", "src/mqtt/token.c", "src/mqtt/message.c" },
	        incdirs = { "/src/mqtt", "$(PAHO_MQTT_INCDIR)" },
	        libdirs = { "$(PAHO_MQTT_LIBDIR)" },
	        libraries = { "paho-mqtt3c" },
		},
		["axcell.mqtt.token"] = {
			sources = { "src/mqtt/token.c" },
	        incdirs = { "/src/mqtt", "$(PAHO_MQTT_INCDIR)" },
	        libdirs = { "$(PAHO_MQTT_LIBDIR)" },
	        libraries = { "paho-mqtt3c" },
		},
		["axcell.uuid"] = "src/uuid/init.c",
	},
}
