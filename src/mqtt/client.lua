--
-- Axcell
-- Copyright (c) 2018 tacigar
--

local ClientBase = require "axcell.mqtt.client_base"
local CoreClientBase = require "axcell.mqtt.core.client_base"

--- Sync client class.
local Client = {}
Client.__index = Client

setmetatable(Client, {
	--- Creates a new sync client.
	__call = function(_, options)
		return setmetatable(ClientBase(options), Client)
	end,
	__index = ClientBase,
})

----------
-- This function performs a synchronous receive of incoming messages. It
-- should be used only when the client application has not set callback
-- methods to support asynchronous receipt of messages.
function Client:receive(timeout)
	return self._core:receive(timeout)
end

return Client
