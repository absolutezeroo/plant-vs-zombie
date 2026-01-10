--!strict
--[[
	entities Command (Server)
	
	Shows current entity count and breakdown.
	Usage: entities
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local EntityPool = require(Shared.utils.EntityPool)

return function(context)
	local stats = EntityPool.GetStats()
	
	local lines = {
		"=== Entity Stats ===",
		`Total Pool: {stats.total}`,
		`Available: {stats.available}`,
		`In Use: {stats.inUse}`,
		`Usage: {math.floor((stats.inUse / stats.total) * 100)}%`,
	}
	
	return table.concat(lines, "\n")
end
