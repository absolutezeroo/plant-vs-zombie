--!strict
--[[
	MushroomSystem.luau - Server-side mushroom plant behaviors
	
	Priority: 155 (Simulation phase - before shooting)
	
	Handles:
	- Mushrooms sleeping during day (SleepsDuringDay)
	- Coffee Bean waking mushrooms (WakesMushrooms)
	- Scaredy-shroom hiding when zombies near (HidesWhenNear)
	- Sun-shroom growing over time (GrowsOverTime)
	
	V2.0 Architecture:
	- Init(world): No init needed
	- Dispose(): Clear tracking state
	- OnStep(world): Process mushroom behaviors
]]

-- 1. IMPORTS
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GameConstants = require(Shared.config.GameConstants)
local PlantData = require(Shared.data.PlantData)
local Logger = require(Shared.utils.core.Logger)
local LaneCache = require(Shared.utils.ecs.LaneCache)

-- Server modules
local Server = script.Parent.Parent.Parent

-- 2. CONFIGURATION
local CONFIG = table.freeze({
	DEFAULT_HIDE_RADIUS = GameConstants.MushroomDefaults.HIDE_RADIUS,
	SUN_SHROOM_GROW_TIME = GameConstants.MushroomDefaults.SUN_SHROOM_GROW_TIME,
	SUN_SHROOM_SMALL_VALUE = GameConstants.MushroomDefaults.SUN_SHROOM_SMALL_VALUE,
	SUN_SHROOM_LARGE_VALUE = GameConstants.MushroomDefaults.SUN_SHROOM_LARGE_VALUE,
})

-- 3. STATE
local State = {
	IsInitialized = false,
	SunShroomPlanted = {} :: { [number]: number }, -- entityId -> plantTime
	WaveService = nil :: any,
}

-- 4. PRIVATE HELPERS

-- Lazy-load WaveService to avoid circular dependencies
local function getWaveService()
	if not State.WaveService then
		State.WaveService = require(Server.services.WaveService)
	end
	return State.WaveService
end

-- Check if it's currently day based on WorldData.IsNight
local function isDay(): boolean
	local waveService = getWaveService()
	return waveService.IsDay()
end

-- Get current SunShroom sun value (grows over time)
local function getSunShroomValue(entityId: number): number
	local plantTime = State.SunShroomPlanted[entityId]
	if not plantTime then
		return CONFIG.SUN_SHROOM_LARGE_VALUE
	end

	local elapsed = os.clock() - plantTime
	if elapsed >= CONFIG.SUN_SHROOM_GROW_TIME then
		return CONFIG.SUN_SHROOM_LARGE_VALUE
	else
		-- Linear interpolation from small to large
		local progress = elapsed / CONFIG.SUN_SHROOM_GROW_TIME
		local value = CONFIG.SUN_SHROOM_SMALL_VALUE
			+ (CONFIG.SUN_SHROOM_LARGE_VALUE - CONFIG.SUN_SHROOM_SMALL_VALUE) * progress
		return math.floor(value)
	end
end

-- Initialize a newly spawned mushroom
local function initializeMushroom(world, entityId: number, plantType: string)
	local stats = PlantData[plantType]
	if not stats or not stats.IsMushroom then
		return
	end

	-- Check if mushroom sleeps during day
	if stats.SleepsDuringDay and isDay() then
		world:insert(
			entityId,
			Components.SleepingComponent({
				IsSleeping = true,
				WokeAt = nil,
			})
		)
		Logger.Debug("Mushroom", `{plantType} {entityId} is sleeping (day time)`)
	end

	-- Track SunShroom growth
	if stats.GrowsOverTime then
		State.SunShroomPlanted[entityId] = os.clock()
		Logger.Debug("Mushroom", `SunShroom {entityId} planted, will grow over time`)
	end

	-- Initialize Scaredy-shroom hiding component
	if stats.HidesWhenNear then
		local hideRadius = stats.HideRadius or CONFIG.DEFAULT_HIDE_RADIUS
		world:insert(
			entityId,
			Components.HidingComponent({
				IsHiding = false,
				HideRadius = hideRadius,
			})
		)
	end
end

-- Wake a sleeping mushroom
local function wakeMushroom(world, entityId: number)
	local sleeping = world:get(entityId, Components.SleepingComponent)
	if sleeping and sleeping.IsSleeping then
		world:insert(
			entityId,
			Components.SleepingComponent({
				IsSleeping = false,
				WokeAt = os.clock(),
			})
		)
		Logger.Info("Mushroom", `Mushroom {entityId} woke up!`)
	end
end

-- 5. LIFECYCLE: INIT
local function Init(_world)
	if State.IsInitialized then
		return
	end
	State.IsInitialized = true
end

-- 6. LIFECYCLE: DISPOSE
local function Dispose()
	table.clear(State.SunShroomPlanted)
	State.WaveService = nil
	State.IsInitialized = false
end

-- 7. MAIN LOOP
local function OnStep(world)
	-- React to SpawnEvent for new mushroom plants
	for _, event in world:query(Components.SpawnEvent) do
		if event.EntityType ~= "Plant" then
			continue
		end

		local entityId = event.Target
		if not world:contains(entityId) then
			continue
		end

		local plant = world:get(entityId, Components.PlantTypeComponent)
		if not plant then
			continue
		end

		initializeMushroom(world, entityId, plant.PlantType)
	end

	-- React to PlantActionEvent for Coffee Bean waking mushrooms
	for _, actionEvent in world:query(Components.PlantActionEvent) do
		if actionEvent.ActionType ~= "WakeMushroom" then
			continue
		end

		local targetId = actionEvent.TargetEntity
		if not world:contains(targetId) then
			continue
		end

		wakeMushroom(world, targetId)
	end

	-- Process Scaredy-shroom hiding behavior
	for plantId, hiding in world:query(Components.HidingComponent) do
		local plant = world:get(plantId, Components.PlantTypeComponent)
		if not plant then
			continue
		end

		local stats = PlantData[plant.PlantType]
		if not stats or not stats.HidesWhenNear then
			continue
		end

		-- Skip if sleeping
		local sleeping = world:get(plantId, Components.SleepingComponent)
		if sleeping and sleeping.IsSleeping then
			continue
		end

		local pos = world:get(plantId, Components.PositionComponent)
		if not pos then
			continue
		end

		-- Check for zombies within hide radius
		local shouldHide = false

		-- O(1) lane lookup instead of O(N) world:query
		local zombiesInLane = LaneCache.GetEntitiesInLane(plant.Lane)

		for _, zombieId in zombiesInLane do
			local zombiePos = LaneCache.GetPosition(zombieId)
			if not zombiePos then
				continue
			end

			local distance = math.abs(zombiePos.X - pos.X)
			if distance <= hiding.HideRadius then
				shouldHide = true
				break
			end
		end

		-- Update hiding state
		if shouldHide ~= hiding.IsHiding then
			world:insert(
				plantId,
				Components.HidingComponent({
					IsHiding = shouldHide,
					HideRadius = hiding.HideRadius,
				})
			)

			if shouldHide then
				Logger.Debug("Mushroom", `ScaredyShroom {plantId} is hiding!`)
			else
				Logger.Debug("Mushroom", `ScaredyShroom {plantId} came out of hiding`)
			end
		end
	end

	-- Cleanup for despawned entities
	for entityId in State.SunShroomPlanted do
		if not world:contains(entityId) then
			State.SunShroomPlanted[entityId] = nil
		end
	end
end

-- 8. EXPORT
return {
	priority = 155,
	Init = Init,
	Dispose = Dispose,
	system = OnStep,
}
