--
-- Axcell
-- Copyright (C) 2017 tacigar
--

local _M = {}

function _M.merge(lhs, rhs)
	local res = {}
	for k, v in pairs(rhs) do
		res[k] = v
	end
	for k, v in pairs(lhs) do
		res[k] = v
	end
	return res
end

return _M
