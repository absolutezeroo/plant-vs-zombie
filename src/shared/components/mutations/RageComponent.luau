--!strict
--[[
	RageComponent.luau - Zombie rage state
	
	Applied when a zombie becomes enraged (e.g., Newspaper Zombie loses newspaper).
	Affects movement speed and attack damage.
	
	Processed by: ZombieMovementSystem, ZombieAttackSystem
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

return Matter.component("RageComponent", {
	SpeedMultiplier = 2.0, -- Movement speed multiplier
	DamageMultiplier = 1.5, -- Attack damage multiplier
	ActivatedAt = 0, -- When rage started (os.clock())
})
