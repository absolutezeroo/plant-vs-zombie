--!strict
--[[
	VaultedComponent.luau - Tag for zombies that have used their vault ability
	
	Pole Vaulters get this after jumping over a plant.
	Once applied, they can no longer vault and must eat plants normally.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type VaultedComponent = {
	VaultedAt: number, -- os.clock() when vault occurred
}

return Matter.component("Vaulted", {
	VaultedAt = 0,
})
