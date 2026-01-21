--!strict
--[[
	MushroomSystem.luau - Server-side mushroom plant behaviors
	
	Priority: 155 (Simulation phase - before shooting)
	
	Handles:
	- Mushrooms sleeping during day (SleepsDuringDay)
	- Coffee Bean waking mushrooms (WakesMushrooms)
	- Scaredy-shroom hiding when zombies near (HidesWhenNear)
	- Sun-shroom growing over time (GrowsOverTime)
	
	HOOKS ARCHITECTURE:
	- Uses per-entity useMap for SunShroom growth tracking (auto-cleanup)
]]

-- 1. IMPORTS
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local MatterHooks = require(Packages.MatterHooks)
local useMap = MatterHooks.useMap
local useMemo = MatterHooks.useMemo

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

-- 3. PRIVATE HELPERS

-- Check if it's currently day based on WorldData.IsNight
local function isDay(WaveService): boolean
	return WaveService.IsDay()
end

-- Get current SunShroom sun value (grows over time)
local function getSunShroomValue(plantTime: number, currentTime: number): number
	local elapsed = currentTime - plantTime
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
local function initializeMushroom(world, entityId: number, plantType: string, WaveService, currentTime: number)
	local stats = PlantData[plantType]
	if not stats or not stats.IsMushroom then
		return
	end

	-- Check if mushroom sleeps during day
	if stats.SleepsDuringDay and isDay(WaveService) then
		world:insert(
			entityId,
			Components.SleepingComponent({
				IsSleeping = true,
				WokeAt = nil,
			})
		)
		Logger.Debug("Mushroom", `{plantType} {entityId} is sleeping (day time)`)
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

-- 4. MAIN LOOP
local function OnStep(world)
	local currentTime = os.clock()

	-- Lazy-load WaveService once per system lifecycle
	local WaveService = useMemo(function()
		return require(Server.services.WaveService)
	end, {})

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

		initializeMushroom(world, entityId, plant.PlantType, WaveService, currentTime)
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
end

-- 5. EXPORT
return {
	priority = 155,
	system = OnStep,
}
