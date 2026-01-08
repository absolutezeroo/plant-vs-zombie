--!strict
--[[
	SpecialPlantSystem.luau - Server-side special plant abilities
	
	Priority: 175 (Simulation phase - after projectiles, before combat)
	
	Handles:
	- CherryBomb/DoomShroom explosion (immediate area damage)
	- PotatoMine arming and detonation
	- Jalapeno lane-wide fire
	- IceShroom global freeze
	- Chomper instant-kill + chewing
	- Squash jump-and-squash
	- Explode-o-nut death explosion
	
	LIFECYCLE:
	- Init(): No init needed
	- system(): Main loop (CANNOT yield) - processes special plants
	- Dispose(): Clear tracking state
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GridConfig = require(Shared.config.GridConfig)
local PlantData = require(Shared.data.PlantData)
local Logger = require(Shared.utils.Logger)

-- Network
local Network = require(Shared.network.generated.server)

-- Server modules
local Server = script.Parent.Parent.Parent
local GridService = require(Server.services.GridService)

-- Components (via index module)
local PositionComponent = Components.PositionComponent
local HealthComponent = Components.HealthComponent
local PlantTypeComponent = Components.PlantTypeComponent
local ZombieTypeComponent = Components.ZombieTypeComponent
local ArmedComponent = Components.ArmedComponent
local ChewingComponent = Components.ChewingComponent
local JumpingComponent = Components.JumpingComponent
local SlowComponent = Components.SlowComponent
local MovementComponent = Components.MovementComponent

-- Config defaults (used when PlantData doesn't specify)
local SpecialDefaults = {
	-- Explosion defaults
	FUSE_TIME = 0.5,           -- Seconds before explosion
	EXPLOSION_RADIUS = 9,      -- Studs (1.5 cells in each direction)
	
	-- Armed plant defaults
	ARM_DURATION = 15,         -- Seconds to arm
	TRIGGER_RADIUS = 2,        -- Studs to trigger explosion
	
	-- Chomper defaults
	CHEW_DURATION = 42,        -- Seconds to digest
	CHOMP_RANGE = 6,           -- Studs to chomp
	
	-- Squash defaults
	JUMP_DURATION = 0.5,       -- Seconds for jump
	SQUASH_RANGE = 6,          -- Studs to detect target
	
	-- Freeze defaults
	FREEZE_DURATION = 4,       -- Seconds frozen
}

-- Track plants with fuse timers
local _fusePlants: {[number]: {explodeTime: number, plantType: string}} = {}

-- Track Squash jumping state
local _squashJumps: {[number]: {targetX: number, targetZ: number, startTime: number, startX: number, startZ: number}} = {}

-- Called by PlacementSystem when a special plant is placed
local SpecialPlantAPI = {}

function SpecialPlantAPI.OnPlantPlaced(world: any, entityId: number, plantType: string)
	local stats = PlantData[plantType]
	if not stats then
		return
	end
	
	-- Check behavior flags instead of hardcoded names
	if stats.ExplodesOnPlace then
		-- CherryBomb/DoomShroom/IceShroom/Jalapeno: Start fuse timer
		local fuseTime = stats.FuseTime or SpecialDefaults.FUSE_TIME
		_fusePlants[entityId] = {
			explodeTime = os.clock() + fuseTime,
			plantType = plantType,
		}
		Logger.Debug("SpecialPlant", `{plantType} {entityId} fuse started ({fuseTime}s)`)
	elseif stats.NeedsArming then
		-- PotatoMine: Add ArmedComponent (starts unarmed)
		local armDuration = stats.ArmDuration or SpecialDefaults.ARM_DURATION
		world:insert(entityId, ArmedComponent({
			IsArmed = false,
			ArmTime = os.clock(),
			ArmDuration = armDuration,
		}))
		Logger.Debug("SpecialPlant", `{plantType} {entityId} placed, arming in {armDuration}s`)
	end
end

-- Handle explosion for various plant types
local function handleExplosion(world: any, entityId: number, pos: any, plantType: string)
	local stats = PlantData[plantType]
	if not stats then return end
	
	local killCount = 0
	local currentTime = os.clock()
	
	if stats.FreezesAll then
		-- IceShroom: Freeze ALL zombies on screen
		local freezeDuration = stats.FreezeDuration or SpecialDefaults.FREEZE_DURATION
		for zombieId, zombiePos, zombie in world:query(PositionComponent, ZombieTypeComponent) do
			-- Apply freeze (slow to 0%)
			world:insert(zombieId, SlowComponent({
				SlowPercent = 1.0,  -- 100% slow = frozen
				Duration = freezeDuration,
				AppliedAt = currentTime,
			}))
			
			-- Stop movement
			world:insert(zombieId, MovementComponent({
				VelocityX = 0,
				VelocityY = 0,
				VelocityZ = 0,
			}))
			
			-- Small damage
			local health = world:get(zombieId, HealthComponent)
			if health then
				world:insert(zombieId, HealthComponent({
					Current = math.max(0, health.Current - (stats.Damage or 20)),
					Max = health.Max,
				}))
			end
			killCount += 1
		end
		Logger.Info("SpecialPlant", `IceShroom {entityId} froze {killCount} zombies for {freezeDuration}s`)
		
	elseif stats.IsLaneWide then
		-- Jalapeno: Destroy entire lane
		local plant = world:get(entityId, PlantTypeComponent)
		if plant then
			for zombieId, zombiePos, zombie in world:query(PositionComponent, ZombieTypeComponent) do
				if zombie.Lane == plant.Lane then
					local health = world:get(zombieId, HealthComponent)
					if health then
						world:insert(zombieId, HealthComponent({
							Current = 0,
							Max = health.Max,
						}))
						killCount += 1
					end
				end
			end
		end
		Logger.Info("SpecialPlant", `Jalapeno {entityId} burned lane, killed {killCount} zombies`)
		
		-- Fire VFX for entire lane
		Network.ExplosionVFX.FireAll({
			PositionX = pos.X,
			PositionY = 1,
			PositionZ = pos.Z,
			Radius = GridConfig.GRID_COLUMNS * GridConfig.CELL_SIZE, -- Lane-wide
		})
		
	else
		-- Normal explosion (CherryBomb, DoomShroom)
		local explosionRadius = (stats.Range and stats.Range > 0) and stats.Range or SpecialDefaults.EXPLOSION_RADIUS
		
		for zombieId, zombiePos, zombie in world:query(PositionComponent, ZombieTypeComponent) do
			local dx = zombiePos.X - pos.X
			local dz = zombiePos.Z - pos.Z
			local distance = math.sqrt(dx * dx + dz * dz)
			
			if distance <= explosionRadius then
				local health = world:get(zombieId, HealthComponent)
				if health then
					world:insert(zombieId, HealthComponent({
						Current = 0,
						Max = health.Max,
					}))
					killCount += 1
				end
			end
		end
		
		Logger.Info("SpecialPlant", `{plantType} {entityId} exploded! Killed {killCount} zombies`)
		
		-- Broadcast explosion VFX
		Network.ExplosionVFX.FireAll({
			PositionX = pos.X,
			PositionY = 1,
			PositionZ = pos.Z,
			Radius = explosionRadius,
		})
	end
	
	-- Clear grid cell
	local plant = world:get(entityId, PlantTypeComponent)
	if plant then
		GridService.Clear(plant.Column, plant.Lane)
	end

	-- Broadcast entity death
	Network.EntityDied.FireAll({
		EntityId = entityId,
	})
	
	-- Destroy the plant
	world:despawn(entityId)
end

-- Explode PotatoMine: kill the triggering zombie
local function explodePotatoMine(world: any, mineId: number, minePos: any, triggeredByZombieId: number)
	Logger.Info("SpecialPlant", `PotatoMine {mineId} detonated by zombie {triggeredByZombieId}!`)
	
	-- Kill the zombie
	local health = world:get(triggeredByZombieId, HealthComponent)
	if health then
		world:insert(triggeredByZombieId, HealthComponent({
			Current = 0,
			Max = health.Max,
		}))
	end
	
	-- Clear grid cell
	local plant = world:get(mineId, PlantTypeComponent)
	if plant then
		GridService.Clear(plant.Column, plant.Lane)
	end

	-- Broadcast explosion VFX
	Network.ExplosionVFX.FireAll({
		PositionX = minePos.X,
		PositionY = 1,
		PositionZ = minePos.Z,
		Radius = 6,
	})
	
	-- Broadcast entity death
	Network.EntityDied.FireAll({
		EntityId = mineId,
	})
	
	-- Destroy the mine
	world:despawn(mineId)
end

-- Find nearest zombie in range for Chomper/Squash
local function findNearestZombieInRange(world: any, plantPos: any, lane: number, range: number): (number?, any?)
	local nearestId = nil
	local nearestPos = nil
	local nearestDist = range + 1
	
	for zombieId, zombiePos, zombie in world:query(PositionComponent, ZombieTypeComponent) do
		if zombie.Lane ~= lane then continue end
		
		local distance = zombiePos.X - plantPos.X
		if distance > 0 and distance <= range and distance < nearestDist then
			nearestId = zombieId
			nearestPos = zombiePos
			nearestDist = distance
		end
	end
	
	return nearestId, nearestPos
end

local function SpecialPlantSystem(world)
	local currentTime = os.clock()
	
	-- Process fuse plants (CherryBomb, DoomShroom, IceShroom, Jalapeno)
	for entityId, fuseData in _fusePlants do
		if currentTime >= fuseData.explodeTime then
			if world:contains(entityId) then
				local pos = world:get(entityId, PositionComponent)
				if pos then
					handleExplosion(world, entityId, pos, fuseData.plantType)
				end
			end
			_fusePlants[entityId] = nil
		end
	end
	
	-- Process armed plants (PotatoMine) triggering
	for mineId, pos, plant, armed in world:query(PositionComponent, PlantTypeComponent, ArmedComponent) do
		local stats = PlantData[plant.PlantType]
		if not stats or not stats.NeedsArming then
			continue
		end
		
		-- Check if still arming
		if not armed.IsArmed then
			if currentTime - armed.ArmTime >= armed.ArmDuration then
				-- Now armed!
				world:insert(mineId, ArmedComponent({
					IsArmed = true,
					ArmTime = armed.ArmTime,
					ArmDuration = armed.ArmDuration,
				}))
				Logger.Debug("SpecialPlant", `{plant.PlantType} {mineId} is now armed!`)
			end
			continue
		end
		
		-- Armed mine - check for zombie contact
		local triggerRadius = stats.TriggerRadius or SpecialDefaults.TRIGGER_RADIUS
		for zombieId, zombiePos, zombie in world:query(PositionComponent, ZombieTypeComponent) do
			if zombie.Lane ~= plant.Lane then continue end
			
			local distance = math.abs(zombiePos.X - pos.X)
			if distance <= triggerRadius then
				explodePotatoMine(world, mineId, pos, zombieId)
				break
			end
		end
	end
	
	-- Process Chomper chewing completion
	for plantId, pos, plant, chewing in world:query(PositionComponent, PlantTypeComponent, ChewingComponent) do
		if currentTime - chewing.ChewStartTime >= chewing.ChewDuration then
			-- Done chewing, remove component
			world:remove(plantId, ChewingComponent)
			Logger.Debug("SpecialPlant", `Chomper {plantId} finished chewing`)
		end
	end
	
	-- Process Chomper looking for targets (when not chewing)
	for plantId, pos, plant in world:query(PositionComponent, PlantTypeComponent) do
		local stats = PlantData[plant.PlantType]
		if not stats or not stats.IsInstantKill then continue end
		if stats.JumpsToTarget then continue end -- Squash handled separately
		
		-- Skip if already chewing
		if world:get(plantId, ChewingComponent) then continue end
		
		local chompRange = stats.Range or SpecialDefaults.CHOMP_RANGE
		local zombieId, zombiePos = findNearestZombieInRange(world, pos, plant.Lane, chompRange)
		
		if zombieId then
			-- Chomp! Instant kill
			local health = world:get(zombieId, HealthComponent)
			if health then
				world:insert(zombieId, HealthComponent({
					Current = 0,
					Max = health.Max,
				}))
			end
			
			-- Start chewing
			local chewDuration = stats.ChewDuration or SpecialDefaults.CHEW_DURATION
			world:insert(plantId, ChewingComponent({
				ChewDuration = chewDuration,
				ChewStartTime = currentTime,
			}))
			
			Logger.Info("SpecialPlant", `Chomper {plantId} ate zombie {zombieId}, chewing for {chewDuration}s`)
			
			-- Broadcast to clients
			Network.EntityDied.FireAll({
				EntityId = zombieId,
			})
		end
	end
	
	-- Process Squash jumping
	for plantId, jumpData in _squashJumps do
		if not world:contains(plantId) then
			_squashJumps[plantId] = nil
			continue
		end
		
		local jumpProgress = (currentTime - jumpData.startTime) / SpecialDefaults.JUMP_DURATION
		
		if jumpProgress >= 1 then
			-- Landed! Kill zombie at target location
			local plant = world:get(plantId, PlantTypeComponent)
			if plant then
				for zombieId, zombiePos, zombie in world:query(PositionComponent, ZombieTypeComponent) do
					local dx = math.abs(zombiePos.X - jumpData.targetX)
					local dz = math.abs(zombiePos.Z - jumpData.targetZ)
					if dx < 3 and dz < 3 then
						local health = world:get(zombieId, HealthComponent)
						if health then
							world:insert(zombieId, HealthComponent({
								Current = 0,
								Max = health.Max,
							}))
							Logger.Info("SpecialPlant", `Squash {plantId} squashed zombie {zombieId}`)
							Network.EntityDied.FireAll({ EntityId = zombieId })
						end
						break
					end
				end
				
				-- Squash dies after landing
				GridService.Clear(plant.Column, plant.Lane)
				Network.EntityDied.FireAll({ EntityId = plantId })
				world:despawn(plantId)
			end
			_squashJumps[plantId] = nil
		else
			-- Update position during jump (arc motion)
			local arcHeight = math.sin(jumpProgress * math.pi) * 5  -- Arc up to 5 studs
			local newX = jumpData.startX + (jumpData.targetX - jumpData.startX) * jumpProgress
			local newZ = jumpData.startZ + (jumpData.targetZ - jumpData.startZ) * jumpProgress
			
			world:insert(plantId, PositionComponent({
				X = newX,
				Y = 2.5 + arcHeight,
				Z = newZ,
			}))
		end
	end
	
	-- Process Squash looking for targets
	for plantId, pos, plant in world:query(PositionComponent, PlantTypeComponent) do
		local stats = PlantData[plant.PlantType]
		if not stats or not stats.JumpsToTarget then continue end
		
		-- Skip if already jumping
		if _squashJumps[plantId] then continue end
		
		local squashRange = stats.Range or SpecialDefaults.SQUASH_RANGE
		local zombieId, zombiePos = findNearestZombieInRange(world, pos, plant.Lane, squashRange)
		
		if zombieId and zombiePos then
			-- Start jumping!
			_squashJumps[plantId] = {
				targetX = zombiePos.X,
				targetZ = zombiePos.Z,
				startTime = currentTime,
				startX = pos.X,
				startZ = pos.Z,
			}
			Logger.Debug("SpecialPlant", `Squash {plantId} jumping to zombie {zombieId}`)
		end
	end
	
	-- Cleanup tracking for despawned entities
	for entityId in _fusePlants do
		if not world:contains(entityId) then
			_fusePlants[entityId] = nil
		end
	end
end

local function Init(_world)
	-- No initialization needed
end

local function Dispose()
	table.clear(_fusePlants)
	table.clear(_squashJumps)
end

return {
	_name = "SpecialPlantSystem",
	priority = 175,
	system = SpecialPlantSystem,
	Init = Init,
	Dispose = Dispose,
	API = SpecialPlantAPI,
}
