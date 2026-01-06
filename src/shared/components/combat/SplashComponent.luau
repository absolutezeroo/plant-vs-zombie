--!strict
--[[
	SplashComponent - Applied to projectiles with area damage (Melon-pult, etc.)
	
	When projectile hits, deals splash damage to nearby zombies.
]]

return function()
	return {
		SplashRadius = 0,      -- Studs - radius of splash damage
		SplashDamage = 0,      -- Damage dealt to splash targets (usually less than direct hit)
	}
end
