--!strict
--[[
	PoisonCloudComponent.luau - Toxic mutation effect
	
	Applied to plants with Toxic/Venomous mutation.
	When plant dies, spawns a poison cloud that damages zombies.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type PoisonCloudComponent = {
	Radius: number, -- Cloud radius in studs
	DamagePerSecond: number, -- Damage to zombies inside
	Duration: number, -- How long cloud lasts
}

return Matter.component("PoisonCloud")
