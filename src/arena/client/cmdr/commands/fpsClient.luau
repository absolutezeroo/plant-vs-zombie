--!strict
--[[
	fps Command (Client)
	
	Shows current FPS and performance stats.
	Usage: fps
]]

local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

return function(context)
	local fps = math.floor(1 / RunService.RenderStepped:Wait())
	local memory = Stats:GetTotalMemoryUsageMb()
	local ping = game:GetService("Players").LocalPlayer:GetNetworkPing() * 1000
	
	local lines = {
		"=== Performance Stats ===",
		`FPS: {fps}`,
		`Memory: {math.floor(memory)} MB`,
		`Ping: {math.floor(ping)} ms`,
	}
	
	return table.concat(lines, "\n")
end
