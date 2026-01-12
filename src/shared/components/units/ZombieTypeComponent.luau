--!strict
--[[
	ZombieTypeComponent.luau - Zombie entity identifier
	
	Marks an entity as a zombie with its type and lane.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type ZombieTypeComponent = {
	ZombieType: string, -- "Basic", "Cone", "Bucket", etc.
	Lane: number, -- Lane 1-5
	SpawnTime: number, -- os.clock() when spawned
}

return Matter.component("ZombieType")
