--!strict
--[[
	SpawnMinionEvent.luau - Ephemeral minion spawn event
	
	Applied when a zombie should spawn minions (e.g., Gargantuar at 50% HP).
	WaveSpawnSystem or ZombieAbilitySystem processes this to spawn the minion.
	
	Processed by: ZombieAbilitySystem (future) or WaveSpawnSystem
	Cleanup: EventCleanupSystem at Priority 400
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

return Matter.component("SpawnMinionEvent", {
	MinionType = "Imp", -- ZombieType to spawn
	SpawnTime = 0, -- When spawn was triggered (os.clock())
	Processed = false, -- Set to true after spawn is handled
})
