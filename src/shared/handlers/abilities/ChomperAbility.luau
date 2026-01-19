--!strict
--[[
	ChomperAbility.luau - Chomper instant-kill + chewing behavior
	
	Chomper eats a zombie instantly, then spends time chewing.
	While chewing, cannot eat another zombie.
	
	BEHAVIOR:
	1. Wait for zombie in range (in front only)
	2. Chomp! Instant kill
	3. Enter chewing state for ChewDuration seconds
	4. Ready to chomp again
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlantData = require(Shared.data.PlantData)
local GameConstants = require(Shared.config.GameConstants)
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
	DEFAULT_CHEW_DURATION = GameConstants.ChomperDefaults.CHEW_DURATION,
	DEFAULT_CHOMP_RANGE = GameConstants.ChomperDefaults.CHOMP_RANGE,
})

-- ============================================
-- STATE STRUCTURE
-- ============================================

export type ChomperState = {
	IsChewing: boolean,
	ChewEndTime: number,
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

local ChomperAbility: PlantAbilityRegistry.PlantAbilityHandler = {
	Id = "Chomper",
	Name = "Chomp",
	Description = "Instantly eats a zombie, then chews for a duration",
	AppliesTo = { "Chomper" },
	Priority = 50,
	
	--[[
		Initialize state when Chomper spawns
	]]
	InitState = function(entityId: number): { [string]: any }
		return {
			IsChewing = false,
			ChewEndTime = 0,
		} :: ChomperState
	end,
	
	--[[
		Main tick logic - look for targets or finish chewing
	]]
	OnTick = function(ctx: AbilityContext): AbilityResult?
		local state = ctx.State :: ChomperState?
		if not state then
			return nil
		end
		
		local currentTime = ctx.CurrentTime
		
		-- If chewing, check if done
		if state.IsChewing then
			if currentTime >= state.ChewEndTime then
				state.IsChewing = false
				state.ChewEndTime = 0
				
				-- Remove ChewingComponent from ECS
				if ctx.World:get(ctx.EntityId, Components.ChewingComponent) then
					ctx.World:remove(ctx.EntityId, Components.ChewingComponent)
				end
				
				return {
					Handled = true,
					Message = `Chomper {ctx.EntityId} finished chewing`,
				}
			end
			
			-- Still chewing, do nothing
			return { Handled = true }
		end
		
		-- Not chewing - look for target
		local stats = PlantData[ctx.PlantType]
		if not stats then
			return nil
		end
		
		local chompRange = stats.Range or CONFIG.DEFAULT_CHOMP_RANGE
		local zombieId, zombiePos = findNearestZombieInFront(
			ctx.World,
			ctx.Position.X,
			ctx.Lane,
			chompRange
		)
		
		if zombieId and zombiePos then
			-- CHOMP! Instant kill
			ECSUtils.KillEntity(ctx.World, zombieId, Components)
			NetworkUtils.BroadcastEntityDied(zombieId)
			
			-- Start chewing
			local chewDuration = stats.ChewDuration or CONFIG.DEFAULT_CHEW_DURATION
			state.IsChewing = true
			state.ChewEndTime = currentTime + chewDuration
			
			-- Add ChewingComponent for visual sync
			ctx.World:insert(
				ctx.EntityId,
				Components.ChewingComponent({
					ChewDuration = chewDuration,
					ChewStartTime = currentTime,
				})
			)
			
			return {
				Handled = true,
				Message = `Chomper {ctx.EntityId} ate zombie {zombieId}, chewing for {chewDuration}s`,
			}
		end
		
		return nil -- No action taken
	end,
	
	--[[
		Cleanup when Chomper is destroyed
	]]
	CleanupState = function(entityId: number)
		-- Nothing special needed, state will be cleared by registry
	end,
}

-- ============================================
-- AUTO-REGISTER
-- ============================================

PlantAbilityRegistry.Register(ChomperAbility)

return ChomperAbility
