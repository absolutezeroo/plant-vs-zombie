--!strict
--[[
	Test System - Validates ECS loop is working
	
	Priority: 999 (runs last for testing)
	
	This system is for development only.
	It logs a message every few seconds to confirm the loop is running.
	REMOVE IN PRODUCTION.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

local INTERVAL = 10 -- seconds between test logs
local lastLogTime = 0

local function TestSystem(world)
	-- IMPORTANT: Systems MUST be stateless functions
	-- All state must be in components or outside the system
	
	local now = tick()
	if now - lastLogTime >= INTERVAL then
		local entityCount = 0
		for _ in world do
			entityCount = entityCount + 1
		end
		
		Logger.Debug("TestSystem", "ECS loop running", {
			EntityCount = entityCount,
			WorldSize = world:size(),
		})
		
		lastLogTime = now
	end
end

return {
	system = TestSystem,
	priority = 999,  -- Runs last
}
