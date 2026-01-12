--!strict
--[[
	MutationsComponent.luau - Tracks active mutations on a plant
	
	Stores the list of mutation IDs applied to this plant entity.
	Used by MutationSystem to apply effects on spawn.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type MutationsComponent = {
	MutationIds: { string }, -- List of active mutation IDs
	OwnerId: number, -- Player.UserId who owns the plant
}

return Matter.component("Mutations")
