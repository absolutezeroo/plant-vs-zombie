--!strict
--[[
	SunOnKillSystem.luau - Spawns sun when plants kill zombies
	
	Priority: 375 (After kill detection)
	
	Plants with SunOnKillComponent spawn sun when they kill a zombie.
	Works with projectile kills and direct damage kills.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local Logger = require(Shared.utils.Logger)

-- Components
local SunOnKillComponent = Components.SunOnKillComponent
local PositionComponent = Components.PositionComponent
local SunComponent = Components.SunComponent
local OwnerComponent = Components.OwnerComponent

-- Module API
local API = {}

-- Called when a plant's attack kills a zombie
function API.OnPlantKillsZombie(world, plantEntityId: number, zombiePosition: {X: number, Y: number, Z: number})
	if not world:contains(plantEntityId) then return end
	
	local sunOnKill = world:get(plantEntityId, SunOnKillComponent)
	if not sunOnKill then return end
	
	local owner = world:get(plantEntityId, OwnerComponent)
	if not owner then return end
	
	-- Spawn sun at zombie death location
	local sunAmount = sunOnKill.SunAmount
	
	world:spawn(
		PositionComponent({
			X = zombiePosition.X,
			Y = zombiePosition.Y + 3, -- Above ground
			Z = zombiePosition.Z,
		}),
		SunComponent({
			Value = sunAmount,
			OwnerId = owner.PlayerId,
			SpawnTime = os.clock(),
			AutoCollect = true, -- Auto-collect after delay
		})
	)
	
	Logger.Debug("SunOnKillSystem", `Spawned {sunAmount} sun from kill by plant {plantEntityId}`)
end

-- System function (no per-frame logic, API-driven)
local function SunOnKillSystem(world)
	-- Sun spawning is triggered via API.OnPlantKillsZombie
	-- No per-frame processing needed
end

return {
	system = SunOnKillSystem,
	priority = 375,
	API = API,
}
