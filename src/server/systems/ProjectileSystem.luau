--!strict
--[[
	ProjectileSystem.luau - Server-side projectile spawning and movement
	
	Priority: 160 (Simulation phase - after zombie movement)
	
	Handles:
	- Peashooters firing peas at zombies in their lane
	- Projectile movement
	- Projectile collision detection
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = Shared.components
local GridConfig = require(Shared.config.GridConfig)
local PlantData = require(Shared.data.PlantData)
local Logger = require(Shared.utils.Logger)

-- Network
local Server = script.Parent.Parent
local Network = require(Server.network.generated)

-- Components
local PositionComponent = require(Components.PositionComponent)
local PlantTypeComponent = require(Components.PlantTypeComponent)
local ProjectileComponent = require(Components.ProjectileComponent)
local ZombieTypeComponent = require(Components.ZombieTypeComponent)

-- Projectile config
local ProjectileConfig = {
	SPEED = 15,              -- Studs per second
	FIRE_INTERVAL = 0.67,    -- Seconds between shots (1.5 attacks/sec)
	MAX_RANGE = 100,         -- Max distance before despawn
	DAMAGE = 20,             -- Base pea damage
	SLOW_PERCENT = 0.5,      -- SnowPea slows by 50%
	SLOW_DURATION = 3,       -- Slow lasts 3 seconds
	REPEATER_DELAY = 0.1,    -- Delay between Repeater's two shots
}

-- Track last fire time per plant
local _plantFireTimes: {[number]: number} = {}
local _repeaterSecondShot: {[number]: number} = {} -- Track pending second shots

-- Check if there are zombies in the lane ahead of the plant
local function hasZombiesInLane(world: any, lane: number, plantX: number): boolean
	for id, pos, zombie in world:query(PositionComponent, ZombieTypeComponent) do
		if zombie.Lane == lane and pos.X > plantX then
			return true
		end
	end
	return false
end

-- Spawn a pea projectile
local function spawnPea(world: any, plantId: number, lane: number, startX: number, isFrozen: boolean?): number
	local z = (lane - 1) * GridConfig.CELL_SIZE + GridConfig.CELL_SIZE / 2 + GridConfig.GRID_ORIGIN_Z
	
	local entityId = world:spawn(
		PositionComponent({
			X = startX + 2, -- Slightly ahead of plant
			Y = 2.5,        -- At plant height
			Z = z
		}),
		ProjectileComponent({
			Damage = ProjectileConfig.DAMAGE,
			Speed = ProjectileConfig.SPEED,
			SourceEntity = plantId,
			Lane = lane,
			SpawnX = startX,
			IsFrozen = isFrozen or false,
			SlowPercent = if isFrozen then ProjectileConfig.SLOW_PERCENT else nil,
			SlowDuration = if isFrozen then ProjectileConfig.SLOW_DURATION else nil,
		})
	)
	
	-- Broadcast to clients
	Network.ProjectileSpawned.FireAll({
		EntityId = entityId,
		Lane = lane :: any,
		StartX = startX + 2,
		TargetEntityId = nil, -- Non-homing
	})
	
	return entityId
end

local function ProjectileSystem(world)
	local currentTime = os.clock()
	local dt = 1/60
	
	-- Process pending Repeater second shots
	for plantId, fireTime in _repeaterSecondShot do
		if currentTime >= fireTime then
			-- Check plant still exists
			if world:contains(plantId) then
				local pos = world:get(plantId, PositionComponent)
				local plant = world:get(plantId, PlantTypeComponent)
				if pos and plant then
					spawnPea(world, plantId, plant.Lane, pos.X, false)
					Logger.Debug("Projectile", `Repeater {plantId} fired second pea`)
				end
			end
			_repeaterSecondShot[plantId] = nil
		end
	end
	
	-- Process plants that can shoot
	for plantId, pos, plant in world:query(PositionComponent, PlantTypeComponent) do
		-- Check if this plant type can shoot
		local plantType = plant.PlantType
		local canShoot = plantType == "Peashooter" or plantType == "SnowPea" or plantType == "Repeater"
		
		if not canShoot then
			continue
		end
		
		-- Check fire cooldown
		local lastFire = _plantFireTimes[plantId] or 0
		if currentTime - lastFire < ProjectileConfig.FIRE_INTERVAL then
			continue
		end
		
		-- Check if zombies in lane
		if not hasZombiesInLane(world, plant.Lane, pos.X) then
			continue
		end
		
		-- Fire based on plant type
		local isFrozen = plantType == "SnowPea"
		spawnPea(world, plantId, plant.Lane, pos.X, isFrozen)
		_plantFireTimes[plantId] = currentTime
		
		-- Repeater fires a second pea after short delay
		if plantType == "Repeater" then
			_repeaterSecondShot[plantId] = currentTime + ProjectileConfig.REPEATER_DELAY
		end
		
		Logger.Debug("Projectile", `{plantType} {plantId} fired pea in lane {plant.Lane}`)
	end
	
	-- Move projectiles
	for projId, pos, proj in world:query(PositionComponent, ProjectileComponent) do
		local newX = pos.X + proj.Speed * dt
		
		-- Check max range
		if newX - proj.SpawnX > ProjectileConfig.MAX_RANGE then
			world:despawn(projId)
			continue
		end
		
		-- Update position
		world:insert(projId, PositionComponent({
			X = newX,
			Y = pos.Y,
			Z = pos.Z
		}))
	end
	
	-- Clean up fire times for despawned plants
	for plantId in _plantFireTimes do
		if not world:contains(plantId) then
			_plantFireTimes[plantId] = nil
		end
	end
end

return {
	system = ProjectileSystem,
	priority = 160,
}
