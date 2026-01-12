--!strict
--[[
	FreezeEffectComponent.luau - Ice mutation effect
	
	Applied to projectiles or plants with Ice/Frost mutation.
	When hitting a zombie, chance to freeze completely.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type FreezeEffectComponent = {
	FreezeChance: number, -- 0.0-1.0 chance to freeze
	FreezeDuration: number, -- How long freeze lasts
	EnhancedSlow: number?, -- Extra slow percent if not frozen
}

return Matter.component("FreezeEffect")
