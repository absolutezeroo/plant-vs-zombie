--!strict
--[[
	PoisonedComponent.luau - Poison status on zombie
	
	Applied to zombies inside a poison cloud.
	Takes damage over time while in the cloud.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type PoisonedComponent = {
	DamagePerSecond: number,  -- Poison damage per second
	SourceCloudId: number?,   -- Entity ID of cloud (for refreshing)
	LastTickTime: number,     -- os.clock() of last damage tick
}

return Matter.component("Poisoned")
