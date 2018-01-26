--
-- axcell
-- Copyright (C) tacigar 2017
--

local mqtt = require 'axcell.mqtt'

local Client = {}

-- Constructor
--
-- Clinet.new({ }, function(_ENV) ... end)
function Client.new(params)
	return function(body)
		local __index = function(self, key)
			local resourceName = string.format("%s.%s", self.id, key)

			if self.resources[resourceName] ~= nil then
				return self.resources[resourceName]
			elseif rawget(self, key) ~= nil then
				return rawget(self, key)
			else
				return Client[key]
			end
		end

		local __newindex = function(tbl, key, val)
			if type(val) == "function" then
				local resourceName = string.format("%s.%s", self.id, key)
			else

			end
		end
	end
end
