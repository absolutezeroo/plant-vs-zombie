--!strict
--[[
	EnhancedProjectileComponent - Applied to projectiles enhanced by Torchwood
	
	Fire peas deal double damage and thaw frozen zombies.
]]

return function()
	return {
		IsFirePea = false,       -- Passed through Torchwood?
		DamageMultiplier = 2,    -- Extra damage multiplier
		ThawsFrozen = true,      -- Removes slow from zombies
	}
end
