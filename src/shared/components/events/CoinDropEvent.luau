--!strict
--[[
	CoinDropEvent.luau - Ephemeral event when coins are dropped
	
	Fired when: A zombie dies and drops coins
	Consumed by: VFX systems (coin particles), Audio (coin sound)
	Lifetime: One frame (cleaned by EventCleanupSystem)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type CoinDropEvent = {
	Amount: number, -- Number of coins dropped
	PositionX: number, -- World position X
	PositionY: number, -- World position Y
	PositionZ: number, -- World position Z
	SourceEntityId: number, -- Entity that dropped coins (zombie)
}

return Matter.component("CoinDropEvent")
