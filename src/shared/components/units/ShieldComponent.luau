--!strict
--[[
	ShieldComponent.luau - Zombie shield health tracking
	
	Applied to zombies with shields (Screen-Door, Ladder).
	Shield absorbs damage before health is affected.
	Projectiles with PiercesShields bypass this component.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type ShieldComponent = {
	Current: number, -- Current shield health
	Max: number, -- Maximum shield health (from ZombieData.ShieldHealth)
}

return Matter.component("ShieldComponent", {
	Current = 0,
	Max = 0,
})
