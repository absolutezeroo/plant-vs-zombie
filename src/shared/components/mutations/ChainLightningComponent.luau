--!strict
--[[
	ChainLightningComponent.luau - Electric mutation effect
	
	Applied to projectiles or plants with Electric/Tesla mutation.
	When hitting a zombie, damage chains to nearby zombies.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type ChainLightningComponent = {
	ChainCount: number, -- How many zombies to chain to
	ChainDamage: number, -- Damage multiplier per chain (0.5 = 50%)
	ChainRange: number, -- Studs to search for next target
}

return Matter.component("ChainLightning")
