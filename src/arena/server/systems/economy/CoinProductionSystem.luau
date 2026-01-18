--!strict
--[[
	CoinProductionSystem.luau - Server-side Marigold coin production
	
	Priority: 306 (Economy phase - after sunflower production)
	
	Marigold produces coins every ~24 seconds.
	Coins are awarded directly to the plant owner.
]]

-- 1. IMPORTS
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GameConstants = require(Shared.config.GameConstants)
local PlantData = require(Shared.data.PlantData)

-- Network
local Network = require(Shared.network.generated.server)

-- Server modules (lazy-loaded)
local Server = script.Parent.Parent.Parent

-- 2. CONFIGURATION
local CONFIG = table.freeze({
	DEFAULT_PRODUCTION_INTERVAL = 24, -- Seconds between coin production
	DEFAULT_FIRST_PRODUCTION_DELAY = 7, -- Seconds before first coin
	DEFAULT_COIN_VALUE = 5, -- Coins per production (silver coin)
	GOLD_COIN_VALUE = 10, -- Gold coin value (rare drop)
	GOLD_COIN_CHANCE = 0.15, -- 15% chance for gold coin
})

-- 3. STATE
local State = {
	IsInitialized = false,
	ProductionTimers = {} :: { [number]: number }, -- entityId -> nextProductionTime
	PlayerDataService = nil :: any, -- Lazy-loaded reference
	StatsService = nil :: any, -- Lazy-loaded reference
	WaveService = nil :: any, -- Lazy-loaded reference
}

-- Helper: Get services (lazy loading to avoid circular deps)
local function getServices()
	if not State.PlayerDataService then
		State.PlayerDataService = require(Server.services.PlayerDataService)
	end
	if not State.StatsService then
		State.StatsService = require(Server.services.StatsService)
	end
	if not State.WaveService then
		State.WaveService = require(Server.services.WaveService)
	end
	return State.PlayerDataService, State.StatsService, State.WaveService
end

-- 4. INIT
local function Init(_world)
	if State.IsInitialized then
		return
	end
	State.IsInitialized = true
end

-- 5. DISPOSE
local function Dispose()
	State.IsInitialized = false
	table.clear(State.ProductionTimers)
	State.PlayerDataService = nil
	State.StatsService = nil
	State.WaveService = nil
end

-- 6. MAIN LOOP
local function OnStep(world)
	local currentTime = os.clock()
	
	-- Get services
	local PlayerDataService, StatsService, WaveService = getServices()
	
	-- Only produce coins during "Playing" state (not Preparation)
	local gameState = WaveService.GetGameState()
	if gameState ~= "Playing" then
		return
	end
	
	-- Find all plants with ProducesCoins flag
	for id, plant, pos in world:query(Components.PlantTypeComponent, Components.PositionComponent) do
		local stats = PlantData[plant.PlantType]
		if not stats or not stats.ProducesCoins then
			continue
		end
		
		-- Read production values from PlantData (with defaults)
		local productionInterval = stats.CoinProductionInterval or CONFIG.DEFAULT_PRODUCTION_INTERVAL
		local firstDelay = stats.FirstCoinDelay or CONFIG.DEFAULT_FIRST_PRODUCTION_DELAY
		
		-- Initialize timer for new coin-producing plants
		if not State.ProductionTimers[id] then
			State.ProductionTimers[id] = currentTime + firstDelay
		end
		
		-- Check if it's time to produce
		if currentTime >= State.ProductionTimers[id] then
			-- Get plant owner
			local owner = world:get(id, Components.OwnerComponent)
			if not owner then
				-- No owner = skip (shouldn't happen)
				State.ProductionTimers[id] = currentTime + productionInterval
				continue
			end
			
			-- Find player by ID
			local player = Players:GetPlayerByUserId(owner.PlayerId)
			if not player then
				-- Player left, skip
				State.ProductionTimers[id] = currentTime + productionInterval
				continue
			end
			
			-- Determine coin value (silver or gold)
			local coinValue = CONFIG.DEFAULT_COIN_VALUE
			local isGold = math.random() < CONFIG.GOLD_COIN_CHANCE
			if isGold then
				coinValue = CONFIG.GOLD_COIN_VALUE
			end
			
			-- Award coins to player via PlayerDataService
			local success = PlayerDataService.AddCoins(player, coinValue)
			
			if success then
				-- Track stats
				StatsService.AddCoinsEarned(player, coinValue)
				
				-- Get new total for UI
				local newTotal = PlayerDataService.GetCoins(player)
				
				-- Broadcast coin gain to player
				Network.CoinGained.Fire(player, {
					Amount = coinValue,
					TotalCoins = newTotal,
				})
				
				-- Spawn ephemeral event for VFX systems
				world:spawn(Components.CoinDropEvent({
					Amount = coinValue,
					PositionX = pos.X,
					PositionY = pos.Y + 3, -- Above plant
					PositionZ = pos.Z,
					SourceEntityId = id,
				}))
			end
			
			-- Reset timer for next production
			State.ProductionTimers[id] = currentTime + productionInterval
		end
	end
	
	-- Cleanup timers for despawned plants
	for id in State.ProductionTimers do
		if not world:contains(id) then
			State.ProductionTimers[id] = nil
		end
	end
end

-- 7. EXPORT
return {
	priority = 306,
	Init = Init,
	Dispose = Dispose,
	system = OnStep,
}
