.PHONY: test

install:
	luarocks make PAHO_MQTT_INCDIR=/usr/local/include PAHO_MQTT_LIBDIR=/usr/local/lib

test:
	lua test/acl/test_principal_name.lua
	lua test/acl/test_reference_monitor.lua
