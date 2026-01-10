--!strict
--[[
	PoisonCloudSystem.luau - Handles poison clouds and poisoned zombies
	
	Priority: 365 (Combat processing)
	
	Spawns poison clouds when plants with PoisonCloud die.
	Damages zombies inside poison clouds over time.
	
	LIFECYCLE:
	- Init(): No init needed
	- system(): Main loop (CANNOT yield) - processes poison clouds
	- Dispose(): Clear active clouds
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))
local Sift = require(Packages:WaitForChild("Sift"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local Logger = require(Shared.utils.Logger)
local LaneCache = require(Shared.utils.LaneCache)
local GridConfig = require(Shared.config.GridConfig)
local MapConfig = require(Shared.config.MapConfig)

-- Components
local PoisonCloudComponent = Components.PoisonCloudComponent
local PoisonedComponent = Components.PoisonedComponent
local PositionComponent = Components.PositionComponent
local HealthComponent = Components.HealthComponent
local ZombieTypeComponent = Components.ZombieTypeComponent
local DamageEvent = Components.DamageEvent

-- Active poison clouds (entity has been destroyed but cloud lingers)
export type ActiveCloud = {
	Position: {X: number, Y: number, Z: number},
	Lane: number, -- Cached lane for optimized lookups
	Radius: number,
	DamagePerSecond: number,
	RemainingDuration: number,
	LastTickTime: number,
}

local activeClouds: {ActiveCloud} = {}

-- Module API
local API = {}

-- Spawn a poison cloud at a position
function API.SpawnPoisonCloud(position: {X: number, Y: number, Z: number}, radius: number, damagePerSecond: number, duration: number)
	-- Calculate lane from world position for optimized lookups
	local _, lane = MapConfig.WorldToGrid(Vector3.new(position.X, position.Y, position.Z))
	
	table.insert(activeClouds, {
		Position = position,
		Lane = lane or 3, -- Default to middle lane if calculation fails
		Radius = radius,
		DamagePerSecond = damagePerSecond,
		RemainingDuration = duration,
		LastTickTime = os.clock(),
	})
	Logger.Debug("PoisonCloudSystem", `Spawned poison cloud at ({position.X}, {position.Z}) lane {lane or 3} - radius {radius}, {damagePerSecond} dps for {duration}s`)
end

-- Called when a plant with PoisonCloud dies
function API.OnPlantDeath(world, plantEntityId: number)
	if not world:contains(plantEntityId) then return end
	
	local poisonCloud = world:get(plantEntityId, PoisonCloudComponent)
	if not poisonCloud then return end
	
	local pos = world:get(plantEntityId, PositionComponent)
	if not pos then return end
	
	API.SpawnPoisonCloud(
		{X = pos.X, Y = pos.Y, Z = pos.Z},
		poisonCloud.Radius,
		poisonCloud.DamagePerSecond,
		poisonCloud.Duration
	)
end

-- System function
local function PoisonCloudSystem(world)
	local currentTime = os.clock()
	local cloudsToRemove = {}
	
	-- Process each active cloud
	for i, cloud in activeClouds do
		local elapsed = currentTime - cloud.LastTickTime
		cloud.RemainingDuration -= elapsed
		
		if cloud.RemainingDuration <= 0 then
			table.insert(cloudsToRemove, i)
		else
			-- Tick damage every second
			if elapsed >= 1 then
				cloud.LastTickTime = currentTime
				
				-- Calculate how many lanes the cloud radius covers
				local laneRadius = math.ceil(cloud.Radius / GridConfig.CELL_SIZE)
				
				-- O(lane_range) lookup instead of O(N) world:query
				local zombiesInRange = LaneCache.GetEntitiesInLaneRange(cloud.Lane, laneRadius)
				
				-- Find zombies in cloud
				for _, entityId in zombiesInRange do
					if not world:contains(entityId) then continue end
					
					local pos = LaneCache.GetPosition(entityId)
					local health = world:get(entityId, HealthComponent)
					if not pos or not health then continue end
					
					local dx = pos.X - cloud.Position.X
					local dz = pos.Z - cloud.Position.Z
					local distance = math.sqrt(dx * dx + dz * dz)
					
					if distance <= cloud.Radius then
						-- Apply poison damage
						world:insert(entityId, HealthComponent({
							Current = math.max(0, health.Current - cloud.DamagePerSecond),
							Max = health.Max,
						}))
						
						world:insert(entityId, DamageEvent({
							Amount = cloud.DamagePerSecond,
							DamageType = "Poison",
							SourceEntityId = nil,
						}))
					end
				end
			end
		end
	end
	
	-- Remove expired clouds (in reverse order to preserve indices)
	for i = #cloudsToRemove, 1, -1 do
		table.remove(activeClouds, cloudsToRemove[i])
	end
end

-- Reset clouds (for new game)
function API.Reset()
	activeClouds = {}
end

local function Init(_world)
	-- No initialization needed
end

local function Dispose()
	activeClouds = {}
end

return {
	_name = "PoisonCloudSystem",
	priority = 365,
	system = PoisonCloudSystem,
	Init = Init,
	Dispose = Dispose,
	API = API,
}
