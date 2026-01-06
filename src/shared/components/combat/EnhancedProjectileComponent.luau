--!strict
--[[
	EnhancedProjectileComponent - Applied to projectiles enhanced by Torchwood
	
	Fire peas deal double damage and thaw frozen zombies.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

return Matter.component("EnhancedProjectileComponent", {
	IsFirePea = false,       -- Passed through Torchwood?
	DamageMultiplier = 2,    -- Extra damage multiplier
	ThawsFrozen = true,      -- Removes slow from zombies
})
