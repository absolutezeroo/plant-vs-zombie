--!strict
--[[
	SplashComponent - Applied to projectiles with area damage (Melon-pult, etc.)
	
	When projectile hits, deals splash damage to nearby zombies.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

return Matter.component("SplashComponent", {
	SplashRadius = 0, -- Studs - radius of splash damage
	SplashDamage = 0, -- Damage dealt to splash targets (usually less than direct hit)
})
