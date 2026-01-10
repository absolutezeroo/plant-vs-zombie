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
		`Total Pool: {stats.Total}`,
		`Available: {stats.Available}`,
		`In Use: {stats.InUse}`,
		`Usage: {math.floor((stats.InUse / math.max(stats.Total, 1)) * 100)}%`,
	}
	
	return table.concat(lines, "\n")
end
