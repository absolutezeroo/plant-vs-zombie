--!strict
--[[
	BurnEffectComponent.luau - Fire mutation effect
	
	Applied to projectiles or plants with Fire/Inferno mutation.
	When hitting a zombie, applies burn DoT.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type BurnEffectComponent = {
	DamagePerSecond: number,  -- Burn damage per second
	Duration: number,         -- Total burn duration
}

return Matter.component("BurnEffect")
