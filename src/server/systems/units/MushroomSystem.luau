--!strict
--[[
	MushroomSystem.luau - Server-side mushroom plant behaviors
	
	Priority: 155 (Simulation phase - before shooting)
	
	Handles:
	- Mushrooms sleeping during day (SleepsDuringDay)
	- Coffee Bean waking mushrooms (WakesMushrooms)
	- Scaredy-shroom hiding when zombies near (HidesWhenNear)
	- Sun-shroom growing over time (GrowsOverTime)
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
local Server = script.Parent.Parent.Parent
local Network = require(Server.network.generated)
local GridState = require(Server.modules.GridState)

-- Components
local PositionComponent = Components.PositionComponent
local PlantTypeComponent = Components.PlantTypeComponent
local ZombieTypeComponent = Components.ZombieTypeComponent
local SleepingComponent = Components.SleepingComponent
local HidingComponent = Components.HidingComponent

-- Config
local MushroomConfig = {
	DEFAULT_HIDE_RADIUS = 6,      -- Studs
	SUN_SHROOM_GROW_TIME = 120,   -- Seconds to grow to full size
	SUN_SHROOM_SMALL_VALUE = 15,  -- Small sun value
	SUN_SHROOM_LARGE_VALUE = 25,  -- Full sun value
}

-- Track SunShroom growth timers
local _sunShroomPlanted: {[number]: number} = {} -- entityId -> plantTime

-- API for other systems
local MushroomAPI = {}

-- Check if it's currently day or night (for now always day - can be expanded later)
function MushroomAPI.IsDay(): boolean
	-- TODO: Implement day/night cycle from WaveManager or GameState
	-- For now, return true (always day) - mushrooms need Coffee Bean
	return true
end

-- Called when a mushroom is placed
function MushroomAPI.OnMushroomPlaced(world: any, entityId: number, plantType: string)
	local stats = PlantData[plantType]
	if not stats or not stats.IsMushroom then return end
	
	-- Check if mushroom sleeps during day
	if stats.SleepsDuringDay and MushroomAPI.IsDay() then
		world:insert(entityId, SleepingComponent({
			IsSleeping = true,
			WokeAt = nil,
		}))
		Logger.Debug("Mushroom", `{plantType} {entityId} is sleeping (day time)`)
	end
	
	-- Track SunShroom growth
	if stats.GrowsOverTime then
		_sunShroomPlanted[entityId] = os.clock()
		Logger.Debug("Mushroom", `SunShroom {entityId} planted, will grow over time`)
	end
	
	-- Initialize Scaredy-shroom hiding component
	if stats.HidesWhenNear then
		local hideRadius = stats.HideRadius or MushroomConfig.DEFAULT_HIDE_RADIUS
		world:insert(entityId, HidingComponent({
			IsHiding = false,
			HideRadius = hideRadius,
		}))
	end
end

-- Wake a sleeping mushroom (called by Coffee Bean placement)
function MushroomAPI.WakeMushroom(world: any, entityId: number)
	local sleeping = world:get(entityId, SleepingComponent)
	if sleeping and sleeping.IsSleeping then
		world:insert(entityId, SleepingComponent({
			IsSleeping = false,
			WokeAt = os.clock(),
		}))
		Logger.Info("Mushroom", `Mushroom {entityId} woke up!`)
		return true
	end
	return false
end

-- Get current SunShroom sun value (grows over time)
function MushroomAPI.GetSunShroomValue(entityId: number): number
	local plantTime = _sunShroomPlanted[entityId]
	if not plantTime then
		return MushroomConfig.SUN_SHROOM_LARGE_VALUE
	end
	
	local elapsed = os.clock() - plantTime
	if elapsed >= MushroomConfig.SUN_SHROOM_GROW_TIME then
		return MushroomConfig.SUN_SHROOM_LARGE_VALUE
	else
		-- Linear interpolation from small to large
		local progress = elapsed / MushroomConfig.SUN_SHROOM_GROW_TIME
		local value = MushroomConfig.SUN_SHROOM_SMALL_VALUE + 
			(MushroomConfig.SUN_SHROOM_LARGE_VALUE - MushroomConfig.SUN_SHROOM_SMALL_VALUE) * progress
		return math.floor(value)
	end
end

local function MushroomSystem(world)
	local currentTime = os.clock()
	
	-- Process Scaredy-shroom hiding behavior
	for plantId, pos, plant, hiding in world:query(PositionComponent, PlantTypeComponent, HidingComponent) do
		local stats = PlantData[plant.PlantType]
		if not stats or not stats.HidesWhenNear then continue end
		
		-- Skip if sleeping
		local sleeping = world:get(plantId, SleepingComponent)
		if sleeping and sleeping.IsSleeping then continue end
		
		-- Check for zombies within hide radius
		local shouldHide = false
		for zombieId, zombiePos, zombie in world:query(PositionComponent, ZombieTypeComponent) do
			if zombie.Lane ~= plant.Lane then continue end
			
			local distance = math.abs(zombiePos.X - pos.X)
			if distance <= hiding.HideRadius then
				shouldHide = true
				break
			end
		end
		
		-- Update hiding state
		if shouldHide ~= hiding.IsHiding then
			world:insert(plantId, HidingComponent({
				IsHiding = shouldHide,
				HideRadius = hiding.HideRadius,
			}))
			
			if shouldHide then
				Logger.Debug("Mushroom", `ScaredyShroom {plantId} is hiding!`)
			else
				Logger.Debug("Mushroom", `ScaredyShroom {plantId} came out of hiding`)
			end
		end
	end
	
	-- Cleanup for despawned entities
	for entityId in _sunShroomPlanted do
		if not world:contains(entityId) then
			_sunShroomPlanted[entityId] = nil
		end
	end
end

return {
	system = MushroomSystem,
	priority = 155,
	API = MushroomAPI,
}
