--!strict
--[[
	SunOnKillComponent.luau - Solar mutation effect
	
	Applied to plants with Solar/Radiant mutation.
	When killing a zombie, spawns sun.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type SunOnKillComponent = {
	SunAmount: number,  -- How much sun to spawn per kill
}

return Matter.component("SunOnKill")
