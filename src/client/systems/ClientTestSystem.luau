--!strict
--[[
	Client Test System - Validates client ECS loop is working
	
	Priority: 999 (runs last for testing)
	
	This system is for development only.
	REMOVE IN PRODUCTION.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

local INTERVAL = 15 -- seconds between test logs (less frequent on client)
local lastLogTime = 0

local function ClientTestSystem(world)
	local now = tick()
	if now - lastLogTime >= INTERVAL then
		Logger.Debug("ClientTestSystem", "Client ECS loop running", {
			WorldSize = world:size(),
		})
		
		lastLogTime = now
	end
end

return {
	system = ClientTestSystem,
	priority = 999,
}
