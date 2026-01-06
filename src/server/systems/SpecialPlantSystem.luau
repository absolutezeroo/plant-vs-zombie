--!strict
--[[
	SpecialPlantSystem.luau - Server-side special plant abilities
	
	Priority: 175 (Simulation phase - after projectiles, before combat)
	
	Handles:
	- CherryBomb explosion (immediate 3x3 damage)
	- PotatoMine arming and detonation
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
local GridState = require(Server.modules.GridState)

-- Components
local PositionComponent = require(Components.PositionComponent)
local HealthComponent = require(Components.HealthComponent)
local PlantTypeComponent = require(Components.PlantTypeComponent)
local ZombieTypeComponent = require(Components.ZombieTypeComponent)
local ArmedComponent = require(Components.ArmedComponent)

-- Config
local SpecialConfig = {
	-- CherryBomb
	CHERRY_EXPLOSION_RADIUS = 9,   -- Studs (1.5 cells in each direction)
	CHERRY_DAMAGE = 1800,          -- Instant kill most zombies
	CHERRY_FUSE_TIME = 0.5,        -- Seconds before explosion (visual cue)
	
	-- PotatoMine
	POTATO_ARM_TIME = 15,          -- Seconds to arm
	POTATO_TRIGGER_RADIUS = 2,     -- Studs to trigger explosion
	POTATO_DAMAGE = 1800,          -- Instant kill
}

-- Track CherryBombs that are about to explode
local _cherryBombFuse: {[number]: number} = {} -- entityId -> explode time

-- Track newly placed CherryBombs (need to start fuse)
local _newCherryBombs: {[number]: boolean} = {}

-- Called by PlacementSystem when a special plant is placed
local SpecialPlantAPI = {}

function SpecialPlantAPI.OnPlantPlaced(world: any, entityId: number, plantType: string)
	if plantType == "CherryBomb" then
		-- Start fuse timer
		_cherryBombFuse[entityId] = os.clock() + SpecialConfig.CHERRY_FUSE_TIME
		Logger.Debug("SpecialPlant", `CherryBomb {entityId} fuse started`)
	elseif plantType == "PotatoMine" then
		-- Add ArmedComponent (starts unarmed)
		world:insert(entityId, ArmedComponent({
			IsArmed = false,
			ArmTime = os.clock(),
			ArmDuration = SpecialConfig.POTATO_ARM_TIME,
		}))
		Logger.Debug("SpecialPlant", `PotatoMine {entityId} placed, arming in {SpecialConfig.POTATO_ARM_TIME}s`)
	end
end

-- Explode CherryBomb: damage all zombies in radius
local function explodeCherryBomb(world: any, entityId: number, pos: any)
	local killCount = 0
	
	-- Find all zombies in explosion radius
	for zombieId, zombiePos, zombie in world:query(PositionComponent, ZombieTypeComponent) do
		local dx = zombiePos.X - pos.X
		local dz = zombiePos.Z - pos.Z
		local distance = math.sqrt(dx * dx + dz * dz)
		
		if distance <= SpecialConfig.CHERRY_EXPLOSION_RADIUS then
			-- Apply massive damage
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
	
	Logger.Info("SpecialPlant", `CherryBomb {entityId} exploded! Killed {killCount} zombies`)
	
	-- Clear grid cell
	local plant = world:get(entityId, PlantTypeComponent)
	if plant then
		GridState.Clear(plant.Column, plant.Lane)
	end
	
	-- Broadcast explosion VFX event
	Network.ExplosionVFX.FireAll({
		PositionX = pos.X,
		PositionY = 1,
		PositionZ = pos.Z,
		Radius = SpecialConfig.CHERRY_EXPLOSION_RADIUS,
	})
	
	-- Broadcast entity death
	Network.EntityDied.FireAll({
		EntityId = entityId,
	})
	
	-- Destroy the CherryBomb
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
		GridState.Clear(plant.Column, plant.Lane)
	end
	
	-- Broadcast explosion VFX event
	Network.ExplosionVFX.FireAll({
		PositionX = minePos.X,
		PositionY = 1,
		PositionZ = minePos.Z,
		Radius = 6,  -- Smaller than CherryBomb
	})
	
	-- Broadcast entity death
	Network.EntityDied.FireAll({
		EntityId = mineId,
	})
	
	-- Destroy the mine
	world:despawn(mineId)
end

local function SpecialPlantSystem(world)
	local currentTime = os.clock()
	
	-- Process CherryBomb fuses
	for entityId, explodeTime in _cherryBombFuse do
		if currentTime >= explodeTime then
			if world:contains(entityId) then
				local pos = world:get(entityId, PositionComponent)
				if pos then
					explodeCherryBomb(world, entityId, pos)
				end
			end
			_cherryBombFuse[entityId] = nil
		end
	end
	
	-- Process PotatoMine arming and triggering
	for mineId, pos, plant, armed in world:query(PositionComponent, PlantTypeComponent, ArmedComponent) do
		if plant.PlantType ~= "PotatoMine" then
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
				Logger.Debug("SpecialPlant", `PotatoMine {mineId} is now armed!`)
			end
			continue
		end
		
		-- Armed mine - check for zombie contact
		for zombieId, zombiePos, zombie in world:query(PositionComponent, ZombieTypeComponent) do
			-- Must be in same lane
			if zombie.Lane ~= plant.Lane then
				continue
			end
			
			-- Check distance
			local distance = math.abs(zombiePos.X - pos.X)
			if distance <= SpecialConfig.POTATO_TRIGGER_RADIUS then
				-- BOOM!
				explodePotatoMine(world, mineId, pos, zombieId)
				break
			end
		end
	end
	
	-- Cleanup tracking for despawned entities
	for entityId in _cherryBombFuse do
		if not world:contains(entityId) then
			_cherryBombFuse[entityId] = nil
		end
	end
end

return {
	system = SpecialPlantSystem,
	priority = 175,
	API = SpecialPlantAPI,
}
