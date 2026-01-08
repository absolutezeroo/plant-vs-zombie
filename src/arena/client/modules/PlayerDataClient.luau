--!strict
--[[
	PlayerDataClient.luau - Client-side player data management
	
	Receives player data from server and provides reactive state for UI.
	Uses Fusion Values for automatic UI updates.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages:WaitForChild("Fusion"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local ProgressionData = require(Shared.data.ProgressionData)

local Network = require(Shared.network.generated.client)

-- Fusion reactive state
local _scope = Fusion.scoped({})
local Value = Fusion.Value

-- Player data state (reactive)
local PlayerData = {
	Coins = Value(_scope, 0),
	Gems = Value(_scope, 0),
	XP = Value(_scope, 0),
	Level = Value(_scope, 1),
	LevelProgress = Value(_scope, 0),  -- 0.0 to 1.0
	UnlockedPlants = Value(_scope, {"Sunflower", "Peashooter", "WallNut"} :: {string}),
	-- Plant mutations (replaces old upgrade system)
	PlantMutations = Value(_scope, {} :: {[string]: {string}}),
	-- Current deck (up to 6 plants)
	Deck = Value(_scope, {"Sunflower", "Peashooter", "WallNut"} :: {string}),
	
	-- Session stats (reset per game)
	SessionCoinsEarned = Value(_scope, 0),
	SessionZombiesKilled = Value(_scope, 0),
}

-- For floating coin VFX
type CoinGainEvent = {
	Amount: number,
	PositionX: number?,
	PositionZ: number?,
}
local _coinGainCallbacks: {(CoinGainEvent) -> ()} = {}

local PlayerDataClient = {}

-- Get the Fusion scope for UI components
function PlayerDataClient.GetScope()
	return _scope
end

-- Get coins (reactive Value)
function PlayerDataClient.GetCoinsValue()
	return PlayerData.Coins
end

-- Get coins (current value)
function PlayerDataClient.GetCoins(): number
	return Fusion.peek(PlayerData.Coins)
end

-- Get gems (reactive Value)
function PlayerDataClient.GetGemsValue()
	return PlayerData.Gems
end

-- Get gems (current value)
function PlayerDataClient.GetGems(): number
	return Fusion.peek(PlayerData.Gems)
end

-- Get XP (reactive Value)
function PlayerDataClient.GetXPValue()
	return PlayerData.XP
end

-- Get Level (reactive Value)
function PlayerDataClient.GetLevelValue()
	return PlayerData.Level
end

-- Get Level Progress (reactive Value, 0.0 to 1.0)
function PlayerDataClient.GetLevelProgressValue()
	return PlayerData.LevelProgress
end

-- Get current level
function PlayerDataClient.GetLevel(): number
	return Fusion.peek(PlayerData.Level)
end

-- Get unlocked plants (reactive Value)
function PlayerDataClient.GetUnlockedPlantsValue()
	return PlayerData.UnlockedPlants
end

-- Get unlocked plants (current list)
function PlayerDataClient.GetUnlockedPlants(): {string}
	return Fusion.peek(PlayerData.UnlockedPlants)
end

-- Get plant mutations (reactive Value)
function PlayerDataClient.GetMutationsValue()
	return PlayerData.PlantMutations
end

-- Check if a plant is unlocked
function PlayerDataClient.IsPlantUnlocked(plantType: string): boolean
	local unlocked = Fusion.peek(PlayerData.UnlockedPlants)
	return table.find(unlocked, plantType) ~= nil
end

-- Get mutations for a plant
function PlayerDataClient.GetPlantMutations(plantType: string): {string}
	local mutations = Fusion.peek(PlayerData.PlantMutations)
	return mutations[plantType] or {}
end

-- Check if plant has a specific mutation
function PlayerDataClient.HasMutation(plantType: string, mutationType: string): boolean
	local mutations = PlayerDataClient.GetPlantMutations(plantType)
	return table.find(mutations, mutationType) ~= nil
end

-- Register callback for coin gain events (for VFX)
function PlayerDataClient.OnCoinGained(callback: (CoinGainEvent) -> ())
	table.insert(_coinGainCallbacks, callback)
end

-- Send unlock request to server
function PlayerDataClient.RequestUnlockPlant(plantType: string)
	Logger.Debug("PlayerData", `Requesting unlock for {plantType}`)
	Network.UnlockPlantRequest.Fire({
		RequestId = 0, -- Will be properly set by network layer
		PlantType = plantType :: any,
	})
end

-- Get session stats values (reactive)
function PlayerDataClient.GetSessionStats()
	return {
		CoinsEarned = PlayerData.SessionCoinsEarned,
		ZombiesKilled = PlayerData.SessionZombiesKilled,
	}
end

-- Reset session stats (call at game start)
function PlayerDataClient.ResetSessionStats()
	PlayerData.SessionCoinsEarned:set(0)
	PlayerData.SessionZombiesKilled:set(0)
end

-- ============================================
-- DECK SYSTEM
-- ============================================

-- Get deck (reactive Value)
function PlayerDataClient.GetDeckValue()
	return PlayerData.Deck
end

-- Get deck (current list)
function PlayerDataClient.GetDeck(): {string}
	return Fusion.peek(PlayerData.Deck)
end

-- Check if a plant is in the deck
function PlayerDataClient.IsInDeck(plantType: string): boolean
	local deck = Fusion.peek(PlayerData.Deck)
	return table.find(deck, plantType) ~= nil
end

-- Save deck to server
function PlayerDataClient.RequestSaveDeck(deck: {string})
	Logger.Debug("PlayerData", `Requesting save deck: {table.concat(deck, ", ")}`)
	
	-- Build request with slots
	Network.SaveDeckRequest.Fire({
		Slot1 = deck[1] :: any,
		Slot2 = deck[2] :: any,
		Slot3 = deck[3] :: any,
		Slot4 = deck[4] :: any,
		Slot5 = deck[5] :: any,
		Slot6 = deck[6] :: any,
	})
end

-- Optimistic deck update (update UI immediately, will sync from server)
function PlayerDataClient.SetDeckLocal(deck: {string})
	PlayerData.Deck:set(deck)
end

-- Initialize and connect to server events
function PlayerDataClient.Initialize()
	-- Handle full data sync from server (SingleAsync = SetCallback)
	Network.PlayerDataSync.SetCallback(function(data)
		Logger.Info("PlayerData", `Received player data: {data.Coins} coins, {data.Gems} gems, Lv{data.Level}`)
		
		-- Update currencies
		PlayerData.Coins:set(data.Coins)
		PlayerData.Gems:set(data.Gems or 0)
		
		-- Update XP/Level
		PlayerData.XP:set(data.XP or 0)
		PlayerData.Level:set(data.Level or 1)
		PlayerData.LevelProgress:set(data.LevelProgress or 0)
		
		-- Update equipped mutations
		if data.EquippedMutations then
			-- Convert array format from Zap to dictionary
			local mutationsDict = {}
			for _, entry in data.EquippedMutations do
				mutationsDict[tostring(entry.PlantType)] = {}
				for _, mutation in entry.Mutations do
					table.insert(mutationsDict[tostring(entry.PlantType)], tostring(mutation))
				end
			end
			PlayerData.PlantMutations:set(mutationsDict)
			
			local mutationCount = 0
			for _, mutations in mutationsDict do
				mutationCount = mutationCount + #mutations
			end
			Logger.Info("PlayerData", `Received {mutationCount} equipped mutations`)
		end
		
		-- Update unlocked plants
		local unlockedList = {}
		for _, plantType in data.UnlockedPlants do
			table.insert(unlockedList, tostring(plantType))
		end
		PlayerData.UnlockedPlants:set(unlockedList)
	end)
	
	-- Handle coin gain events
	Network.CoinGained.On(function(data)
		-- Update total coins
		PlayerData.Coins:set(data.TotalCoins)
		
		-- Update session stats
		local currentSession = Fusion.peek(PlayerData.SessionCoinsEarned)
		PlayerData.SessionCoinsEarned:set(currentSession + data.Amount)
		
		local currentKills = Fusion.peek(PlayerData.SessionZombiesKilled)
		PlayerData.SessionZombiesKilled:set(currentKills + 1)
		
		-- Notify VFX callbacks
		local event: CoinGainEvent = {
			Amount = data.Amount,
			PositionX = data.SourceX,
			PositionZ = data.SourceZ,
		}
		for _, callback in _coinGainCallbacks do
			task.spawn(callback, event)
		end
		
		Logger.Debug("PlayerData", `+{data.Amount} coins (Total: {data.TotalCoins})`)
	end)
	
	-- Handle deck sync from server
	Network.DeckSync.SetCallback(function(data)
		Logger.Info("PlayerData", `DeckSync received:`, data)
		local deck = {}
		if data.Slot1 then table.insert(deck, tostring(data.Slot1)) end
		if data.Slot2 then table.insert(deck, tostring(data.Slot2)) end
		if data.Slot3 then table.insert(deck, tostring(data.Slot3)) end
		if data.Slot4 then table.insert(deck, tostring(data.Slot4)) end
		if data.Slot5 then table.insert(deck, tostring(data.Slot5)) end
		if data.Slot6 then table.insert(deck, tostring(data.Slot6)) end
		
		PlayerData.Deck:set(deck)
		Logger.Info("PlayerData", `Deck updated ({#deck} plants): {table.concat(deck, ", ")}`)
	end)
	
	-- Handle deck save response
	Network.DeckSaved.SetCallback(function(data)
		if data.Success then
			Logger.Info("PlayerData", "Deck saved successfully")
		else
			Logger.Warn("PlayerData", `Failed to save deck: {data.Error or "unknown error"}`)
		end
	end)
	
	Logger.Info("PlayerData", "PlayerDataClient initialized")
end

return PlayerDataClient
