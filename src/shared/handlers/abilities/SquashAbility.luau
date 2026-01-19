--!strict
--[[
	SquashAbility.luau - Squash jump-and-squash behavior
	
	Squash jumps onto a zombie, squashing it instantly, then dies.
	
	BEHAVIOR:
	1. Wait for zombie in range
	2. Jump towards zombie (arc motion over JUMP_DURATION)
	3. Land and kill zombie(s) at landing spot
	4. Squash dies after landing
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlantData = require(Shared.data.PlantData)
local GridConfig = require(Shared.config.GridConfig)
local LaneCache = require(Shared.utils.LaneCache)
local ECSUtils = require(Shared.utils.ECSUtils)
local NetworkUtils = require(Shared.utils.NetworkUtils)
local Components = require(Shared.components)

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
	JUMP_DURATION = 0.5, -- Seconds for jump arc
	DEFAULT_SQUASH_RANGE = 6, -- Detection range
	LANDING_KILL_RADIUS = 3, -- Radius to kill zombies at landing
	ARC_HEIGHT = 5, -- Maximum height of jump arc
	BASE_Y = 2.5, -- Ground level Y
})

-- ============================================
-- STATE STRUCTURE
-- ============================================

export type SquashState = {
	IsJumping: boolean,
	JumpStartTime: number,
	StartX: number,
	StartZ: number,
	TargetX: number,
	TargetZ: number,
}

-- ============================================
-- PRIVATE HELPERS
-- ============================================

local function findNearestZombieInFront(
	world: any,
	posX: number,
	lane: number,
	range: number
): (number?, any?)
	local nearestId = nil
	local nearestPos = nil
	local nearestDist = range + 1
	
	local zombiesInLane = LaneCache.GetEntitiesInLane(lane)
	
	for _, zombieId in zombiesInLane do
		if not world:contains(zombieId) then
			continue
		end
		
		local zombiePos = world:get(zombieId, Components.PositionComponent)
		if not zombiePos then
			continue
		end
		
		-- Only zombies in front (positive X direction from plant)
		local distance = zombiePos.X - posX
		if distance > 0 and distance <= range and distance < nearestDist then
			nearestId = zombieId
			nearestPos = zombiePos
			nearestDist = distance
		end
	end
	
	return nearestId, nearestPos
end

-- ============================================
-- HANDLER DEFINITION
-- ============================================

local SquashAbility: PlantAbilityRegistry.PlantAbilityHandler = {
	Id = "Squash",
	Name = "Jump & Squash",
	Description = "Jumps onto a zombie, squashing it, then dies",
	AppliesTo = { "Squash" },
	Priority = 51,
	
	--[[
		Initialize state when Squash spawns
	]]
	InitState = function(entityId: number): { [string]: any }
		return {
			IsJumping = false,
			JumpStartTime = 0,
			StartX = 0,
			StartZ = 0,
			TargetX = 0,
			TargetZ = 0,
		} :: SquashState
	end,
	
	--[[
		Main tick logic - jump motion or look for targets
	]]
	OnTick = function(ctx: AbilityContext): AbilityResult?
		local state = ctx.State :: SquashState?
		if not state then
			return nil
		end
		
		local currentTime = ctx.CurrentTime
		local world = ctx.World
		
		-- If jumping, process jump motion
		if state.IsJumping then
			local jumpProgress = (currentTime - state.JumpStartTime) / CONFIG.JUMP_DURATION
			
			if jumpProgress >= 1 then
				-- Landed! Kill zombies at target location
				local zombiesInLane = LaneCache.GetEntitiesInLane(ctx.Lane)
				local killCount = 0
				
				for _, zombieId in zombiesInLane do
					if not world:contains(zombieId) then
						continue
					end
					
					local zombiePos = world:get(zombieId, Components.PositionComponent)
					if not zombiePos then
						continue
					end
					
					local dx = math.abs(zombiePos.X - state.TargetX)
					local dz = math.abs(zombiePos.Z - state.TargetZ)
					
					if dx < CONFIG.LANDING_KILL_RADIUS and dz < CONFIG.LANDING_KILL_RADIUS then
						if ECSUtils.KillEntity(world, zombieId, Components) then
							NetworkUtils.BroadcastEntityDied(zombieId)
							killCount += 1
						end
						break -- Usually only kills one
					end
				end
				
				-- Squash dies after landing
				NetworkUtils.BroadcastEntityDied(ctx.EntityId)
				
				return {
					Handled = true,
					Despawn = true,
					ClearGrid = true,
					Message = `Squash {ctx.EntityId} squashed {killCount} zombie(s)`,
				}
			else
				-- Update position during jump (arc motion)
				local arcHeight = math.sin(jumpProgress * math.pi) * CONFIG.ARC_HEIGHT
				local newX = state.StartX + (state.TargetX - state.StartX) * jumpProgress
				local newZ = state.StartZ + (state.TargetZ - state.StartZ) * jumpProgress
				
				world:insert(
					ctx.EntityId,
					Components.PositionComponent({
						X = newX,
						Y = CONFIG.BASE_Y + arcHeight,
						Z = newZ,
					})
				)
				
				return { Handled = true }
			end
		end
		
		-- Not jumping - look for target
		local stats = PlantData[ctx.PlantType]
		if not stats then
			return nil
		end
		
		local squashRange = stats.Range or CONFIG.DEFAULT_SQUASH_RANGE
		local zombieId, zombiePos = findNearestZombieInFront(
			world,
			ctx.Position.X,
			ctx.Lane,
			squashRange
		)
		
		if zombieId and zombiePos then
			-- Start jump!
			state.IsJumping = true
			state.JumpStartTime = currentTime
			state.StartX = ctx.Position.X
			state.StartZ = ctx.Position.Z
			state.TargetX = zombiePos.X
			state.TargetZ = zombiePos.Z
			
			return {
				Handled = true,
				Message = `Squash {ctx.EntityId} jumping to zombie {zombieId}`,
			}
		end
		
		return nil -- No action taken
	end,
	
	--[[
		Cleanup when Squash is destroyed
	]]
	CleanupState = function(entityId: number)
		-- Nothing special needed
	end,
}

-- ============================================
-- AUTO-REGISTER
-- ============================================

PlantAbilityRegistry.Register(SquashAbility)

return SquashAbility
