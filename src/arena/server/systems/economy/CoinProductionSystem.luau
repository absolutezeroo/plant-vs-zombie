--!strict
--[[
	CoinProductionSystem.luau - Server-side Marigold coin production
	
	SYSTEM V3 ARCHITECTURE (Matter Hooks)
	
	Priority: 306 (Economy phase - after sunflower production)
	
	Marigold produces coins every ~24 seconds.
	Coins are awarded directly to the plant owner.
]]

-- 1. IMPORTS
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Hooks = require(Packages:WaitForChild("MatterHooks"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local GameConstants = require(Shared.config.GameConstants)
local PlantData = require(Shared.data.PlantData)

-- Network
local Network = require(Shared.network.generated.server)

-- Server modules (lazy-loaded)
local Server = script.Parent.Parent.Parent

-- 2. CONFIGURATION (referencing GameConstants.Coin)
local CONFIG = table.freeze({
	DEFAULT_PRODUCTION_INTERVAL = GameConstants.Coin.PRODUCTION_INTERVAL,
	DEFAULT_FIRST_PRODUCTION_DELAY = GameConstants.Coin.FIRST_PRODUCTION_DELAY,
	DEFAULT_COIN_VALUE = GameConstants.Coin.SILVER_VALUE,
	GOLD_COIN_VALUE = GameConstants.Coin.GOLD_VALUE,
	GOLD_COIN_CHANCE = GameConstants.Coin.GOLD_CHANCE,
})

-- 3. SYSTEM FUNCTION
local function CoinProductionSystem(world)
	local currentTime = os.clock()

	-- State managed via Hooks.useMap (persistent across frames)
	-- Note: useMap returns { value: T }, so access via .value
	local stateWrapper = Hooks.useMap("CoinProductionState", {
		ProductionTimers = {} :: { [number]: number }, -- entityId -> nextProductionTime
	})
	local state = stateWrapper.value

	-- Lazy load services via useMemo (empty deps = once)
	local PlayerDataService, StatsService, WaveService = Hooks.useMemo(function()
		return require(Server.services.PlayerDataService),
			require(Server.services.StatsService),
			require(Server.services.WaveService)
	end, {})

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
		if not state.ProductionTimers[id] then
			state.ProductionTimers[id] = currentTime + firstDelay
		end

		-- Check if it's time to produce
		if currentTime >= state.ProductionTimers[id] then
			-- Get plant owner
			local owner = world:get(id, Components.OwnerComponent)
			if not owner then
				-- No owner = skip (shouldn't happen)
				state.ProductionTimers[id] = currentTime + productionInterval
				continue
			end

			-- Find player by ID
			local player = Players:GetPlayerByUserId(owner.PlayerId)
			if not player then
				-- Player left, skip
				state.ProductionTimers[id] = currentTime + productionInterval
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
			state.ProductionTimers[id] = currentTime + productionInterval
		end
	end

	-- Cleanup timers for despawned plants
	for id in state.ProductionTimers do
		if not world:contains(id) then
			state.ProductionTimers[id] = nil
		end
	end
end

-- 4. EXPORT (V3 - priority + system only)
return {
	priority = 306,
	system = CoinProductionSystem,
}
