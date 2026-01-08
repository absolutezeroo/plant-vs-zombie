--!strict
--[[
	SplashDamageComponent.luau - Primal mutation effect
	
	Applied to plants with Primal/Savage mutation.
	Attacks deal splash damage to nearby zombies.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type SplashDamageComponent = {
	Radius: number,       -- Splash radius in studs
	Percent: number,      -- Damage percent for splash (0.3 = 30%)
	Knockback: number?,   -- Studs to push back (optional)
}

return Matter.component("SplashDamage")
