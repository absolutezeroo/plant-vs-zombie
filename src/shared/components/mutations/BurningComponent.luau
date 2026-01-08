--!strict
--[[
	BurningComponent.luau - Active burn status on zombie
	
	Applied to zombies that have been hit by a burn effect.
	Takes damage over time until duration expires.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type BurningComponent = {
	DamagePerSecond: number,  -- Damage taken per second
	RemainingDuration: number, -- Seconds left
	LastTickTime: number,     -- os.clock() of last damage tick
}

return Matter.component("Burning")
