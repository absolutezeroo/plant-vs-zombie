--!strict
--[[
	CobCannonAbility.luau - CobCannon manual targeting behavior
	
	CobCannon requires manual targeting by the player.
	When fired, launches a corn cob that explodes at target location.
	
	BEHAVIOR:
	1. Wait for player to target a cell
	2. Launch corn cob (takes FLIGHT_TIME to reach target)
	3. Explode at target, dealing massive area damage
	4. Enter cooldown for COB_COOLDOWN seconds
	
	NOTE: This ability is special because it requires player input.
	The CobCannonFireRequest network event triggers the fire.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlantData = require(Shared.data.PlantData)
local GridConfig = require(Shared.config.GridConfig)
local MapConfig = require(Shared.config.MapConfig)
local LaneCache = require(Shared.utils.ecs.LaneCache)
local ECSUtils = require(Shared.utils.ecs.ECSUtils)
local Components = require(Shared.components)
local Logger = require(Shared.utils.core.Logger)

-- Network (lazy load to avoid issues)
local Network: any = nil
local function getNetwork()
	if not Network then
		Network = require(Shared.network.generated.server)
	end
	return Network
end

-- ============================================
-- TYPE IMPORTS
-- ============================================

local PlantAbilityRegistry = require(script.Parent.PlantAbilityRegistry)
type AbilityContext = PlantAbilityRegistry.AbilityContext
type AbilityResult = PlantAbilityRegistry.AbilityResult

-- ============================================
-- CONFIG
-- ============================================

local CONFIG = table.freeze({
	COB_COOLDOWN = 30, -- Seconds between shots
	COB_FLIGHT_TIME = 1.5, -- Time for corn cob to reach target
	DEFAULT_DAMAGE = 1800, -- Massive damage
	DEFAULT_SPLASH_RADIUS = 8, -- Large explosion
})

-- ============================================
-- STATE STRUCTURE
-- ============================================

export type PendingExplosion = {
	ImpactTime: number,
	TargetX: number,
	TargetZ: number,
	Damage: number,
	SplashRadius: number,
}

export type CobCannonState = {
	CooldownEndTime: number,
	PendingExplosion: PendingExplosion?,
}

-- ============================================
-- MODULE STATE (for pending explosions)
-- ============================================

-- Track all pending explosions globally (processed in OnTick)
local _pendingExplosions: { [number]: PendingExplosion } = {}
local _explosionIdCounter = 0

-- ============================================
-- PUBLIC API (called by network handler)
-- ============================================

local CobCannonAbilityModule = {}

--[[
	Fire the CobCannon at a target location
	Called from SpecialPlantSystem's network handler
]]
function CobCannonAbilityModule.Fire(
	world: any,
	plantId: number,
	targetColumn: number,
	targetLane: number,
	currentTime: number
): (boolean, string?)
	-- Get plant state
	local state = PlantAbilityRegistry.GetState(plantId) :: CobCannonState?
	if not state then
		return false, "CobCannon state not found"
	end
	
	-- Check cooldown
	if currentTime < state.CooldownEndTime then
		local remaining = math.ceil(state.CooldownEndTime - currentTime)
		return false, `CobCannon on cooldown ({remaining}s remaining)`
	end
	
	-- Get plant data
	local plant = world:get(plantId, Components.PlantTypeComponent)
	if not plant then
		return false, "Plant not found"
	end
	
	local stats = PlantData[plant.PlantType]
	if not stats then
		return false, "Plant stats not found"
	end
	
	-- Calculate target world position
	local targetPos = MapConfig.GridToWorld(targetColumn, targetLane)
	
	-- Set cooldown
	state.CooldownEndTime = currentTime + CONFIG.COB_COOLDOWN
	PlantAbilityRegistry.SetState(plantId, state)
	
	-- Create pending explosion
	_explosionIdCounter += 1
	local explosionId = _explosionIdCounter
	
	local damage = stats.Damage or CONFIG.DEFAULT_DAMAGE
	local splashRadius = stats.SplashRadius or CONFIG.DEFAULT_SPLASH_RADIUS
	
	_pendingExplosions[explosionId] = {
		ImpactTime = currentTime + CONFIG.COB_FLIGHT_TIME,
		TargetX = targetPos.X,
		TargetZ = targetPos.Z,
		Damage = damage,
		SplashRadius = splashRadius,
	}
	
	-- Broadcast launch VFX
	local pos = world:get(plantId, Components.PositionComponent)
	if pos then
		getNetwork().CobCannonFired.FireAll({
			PlantEntityId = plantId,
			TargetLane = targetLane,
			TargetColumn = targetColumn,
			LaunchX = pos.X,
			LaunchY = pos.Y + 3,
			LaunchZ = pos.Z,
			TargetX = targetPos.X,
			TargetZ = targetPos.Z,
			FlightTime = CONFIG.COB_FLIGHT_TIME,
		})
	end
	
	Logger.Info("CobCannon", `CobCannon {plantId} fired at ({targetColumn}, {targetLane})`)
	
	return true, nil
end

--[[
	Get remaining cooldown for a CobCannon
]]
function CobCannonAbilityModule.GetCooldownRemaining(plantId: number, currentTime: number): number
	local state = PlantAbilityRegistry.GetState(plantId) :: CobCannonState?
	if not state then
		return 0
	end
	
	return math.max(0, state.CooldownEndTime - currentTime)
end

--[[
	Check if CobCannon is ready to fire
]]
function CobCannonAbilityModule.IsReady(plantId: number, currentTime: number): boolean
	return CobCannonAbilityModule.GetCooldownRemaining(plantId, currentTime) <= 0
end

-- ============================================
-- PRIVATE HELPERS
-- ============================================

local function processExplosion(world: any, explosion: PendingExplosion?)
	if not explosion then
		return 0
	end
	
	local killCount = 0
	local targetX = explosion.TargetX
	local targetZ = explosion.TargetZ
	local damage = explosion.Damage
	local splashRadius = explosion.SplashRadius
	
	-- Find center lane for optimized lookup
	local targetLane = math.floor((targetZ / GridConfig.CELL_SIZE) + 0.5)
	targetLane = math.clamp(targetLane, 1, GridConfig.GRID_LANES)
	local laneRadius = math.ceil(splashRadius / GridConfig.CELL_SIZE)
	
	local zombiesInRange = LaneCache.GetEntitiesInLaneRange(targetLane, laneRadius)
	
	for _, zombieId in zombiesInRange do
		if not world:contains(zombieId) then
			continue
		end
		
		local zombiePos = world:get(zombieId, Components.PositionComponent)
		if not zombiePos then
			continue
		end
		
		local dx = zombiePos.X - targetX
		local dz = zombiePos.Z - targetZ
		local distance = math.sqrt(dx * dx + dz * dz)
		
		if distance <= splashRadius then
			local _, isDead = ECSUtils.DamageEntity(world, zombieId, damage, Components)
			if isDead then
				killCount += 1
			end
		end
	end
	
	-- Broadcast explosion VFX
	getNetwork().ExplosionVFX.FireAll({
		PositionX = targetX,
		PositionY = 1,
		PositionZ = targetZ,
		Radius = splashRadius,
	})
	
	Logger.Info("CobCannon", `CobCannon explosion at ({targetX}, {targetZ}) killed {killCount} zombies`)
	
	return killCount
end

-- ============================================
-- HANDLER DEFINITION
-- ============================================

local CobCannonAbility: PlantAbilityRegistry.PlantAbilityHandler = {
	Id = "CobCannon",
	Name = "Corn Cob Missile",
	Description = "Launches a devastating corn cob at a targeted location",
	AppliesTo = { "CobCannon" },
	Priority = 52,
	
	--[[
		Initialize state when CobCannon spawns
	]]
	InitState = function(entityId: number): { [string]: any }
		return {
			CooldownEndTime = 0, -- Ready immediately
			PendingExplosion = nil,
		} :: CobCannonState
	end,
	
	--[[
		Main tick logic - process pending explosions
	]]
	OnTick = function(ctx: AbilityContext): AbilityResult?
		local currentTime = ctx.CurrentTime
		local world = ctx.World
		
		-- Process all pending explosions (global, not per-entity)
		-- This is done once per tick by checking if we're the "first" CobCannon
		local firstCob = false
		for id in world:query(Components.PlantTypeComponent) do
			local plant = world:get(id, Components.PlantTypeComponent)
			if plant and plant.PlantType == "CobCannon" then
				if id == ctx.EntityId then
					firstCob = true
				end
				break
			end
		end
		
		if firstCob then
			-- Process pending explosions
			for explosionId, explosion in _pendingExplosions do
				if currentTime >= explosion.ImpactTime then
					processExplosion(world, explosion)
					_pendingExplosions[explosionId] = nil
				end
			end
		end
		
		return nil -- CobCannon doesn't do anything automatically
	end,
	
	--[[
		Cleanup when CobCannon is destroyed
	]]
	CleanupState = function(entityId: number)
		-- Note: Pending explosions still complete even if CobCannon is destroyed
	end,
}

-- ============================================
-- AUTO-REGISTER
-- ============================================

PlantAbilityRegistry.Register(CobCannonAbility)

-- Export both the handler and the module API
return {
	Handler = CobCannonAbility,
	Fire = CobCannonAbilityModule.Fire,
	GetCooldownRemaining = CobCannonAbilityModule.GetCooldownRemaining,
	IsReady = CobCannonAbilityModule.IsReady,
}
