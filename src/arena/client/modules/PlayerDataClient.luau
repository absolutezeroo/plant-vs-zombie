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

local Client = script.Parent.Parent
local Network = require(Client.network.generated)

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
	-- Upgrades: [PlantType] = { Damage = level, Health = level, Cooldown = level }
	PlantUpgrades = Value(_scope, {} :: {[string]: {Damage: number, Health: number, Cooldown: number}}),
	-- Current deck (up to 6 plants)
	Deck = Value(_scope, {"Sunflower", "Peashooter", "WallNut"} :: {string}),
	
	-- Stage progression
	CurrentStage = Value(_scope, "1-1"),
	TotalStars = Value(_scope, 0),
	CompletedStages = Value(_scope, {} :: {[string]: number}), -- StageId -> Stars
	
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

-- Check if a plant is unlocked
function PlayerDataClient.IsPlantUnlocked(plantType: string): boolean
	local unlocked = Fusion.peek(PlayerData.UnlockedPlants)
	return table.find(unlocked, plantType) ~= nil
end

-- Get upgrade level for a plant
function PlayerDataClient.GetUpgradeLevel(plantType: string, upgradeType: string): number
	local upgrades = Fusion.peek(PlayerData.PlantUpgrades)
	local plantUpgrades = upgrades[plantType]
	if not plantUpgrades then
		return 0
	end
	return (plantUpgrades :: any)[upgradeType] or 0
end

-- Get all upgrades for a plant
function PlayerDataClient.GetPlantUpgrades(plantType: string): {Damage: number, Health: number, Cooldown: number}
	local upgrades = Fusion.peek(PlayerData.PlantUpgrades)
	return upgrades[plantType] or {Damage = 0, Health = 0, Cooldown = 0}
end

-- Calculate modified plant stats based on upgrades
function PlayerDataClient.GetModifiedPlantStats(plantType: string, baseStats: {
	Damage: number,
	Health: number,
	Cooldown: number,
}): {Damage: number, Health: number, Cooldown: number}
	local upgrades = PlayerDataClient.GetPlantUpgrades(plantType)
	local upgradeData = ProgressionData.Upgrades
	
	return {
		Damage = baseStats.Damage * (1 + upgrades.Damage * upgradeData.Damage.Bonus),
		Health = baseStats.Health * (1 + upgrades.Health * upgradeData.Health.Bonus),
		Cooldown = baseStats.Cooldown * (1 - upgrades.Cooldown * upgradeData.Cooldown.Bonus),
	}
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

-- Send upgrade request to server
function PlayerDataClient.RequestPurchaseUpgrade(plantType: string, upgradeType: string)
	Logger.Debug("PlayerData", `Requesting {upgradeType} upgrade for {plantType}`)
	Network.PurchaseUpgradeRequest.Fire({
		RequestId = 0,
		PlantType = plantType :: any,
		UpgradeType = upgradeType :: any,
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

-- ============================================
-- STAGE SYSTEM
-- ============================================

-- Get current stage (reactive Value)
function PlayerDataClient.GetCurrentStageValue()
	return PlayerData.CurrentStage
end

-- Get current stage
function PlayerDataClient.GetCurrentStage(): string
	return Fusion.peek(PlayerData.CurrentStage)
end

-- Get total stars (reactive Value)
function PlayerDataClient.GetTotalStarsValue()
	return PlayerData.TotalStars
end

-- Get completed stages (reactive Value)
function PlayerDataClient.GetCompletedStagesValue()
	return PlayerData.CompletedStages
end

-- Get stars for a specific stage
function PlayerDataClient.GetStageStars(stageId: string): number
	local completed = Fusion.peek(PlayerData.CompletedStages)
	return completed[stageId] or 0
end

-- Check if stage is completed
function PlayerDataClient.IsStageCompleted(stageId: string): boolean
	return PlayerDataClient.GetStageStars(stageId) > 0
end

-- Request to start a stage
function PlayerDataClient.RequestStartStage(stageId: string)
	Logger.Debug("PlayerData", `Requesting start stage: {stageId}`)
	Network.StartStageRequest.Fire({
		StageId = stageId,
	})
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
		
		-- Update unlocked plants
		local unlockedList = {}
		for _, plantType in data.UnlockedPlants do
			table.insert(unlockedList, tostring(plantType))
		end
		PlayerData.UnlockedPlants:set(unlockedList)
		
		-- Update upgrades
		local upgrades: {[string]: {Damage: number, Health: number, Cooldown: number}} = {}
		for i, plantType in data.UpgradePlantTypes do
			upgrades[tostring(plantType)] = {
				Damage = data.UpgradeDamage[i] or 0,
				Health = data.UpgradeHealth[i] or 0,
				Cooldown = data.UpgradeCooldown[i] or 0,
			}
		end
		PlayerData.PlantUpgrades:set(upgrades)
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
		local deck = {}
		if data.Slot1 then table.insert(deck, tostring(data.Slot1)) end
		if data.Slot2 then table.insert(deck, tostring(data.Slot2)) end
		if data.Slot3 then table.insert(deck, tostring(data.Slot3)) end
		if data.Slot4 then table.insert(deck, tostring(data.Slot4)) end
		if data.Slot5 then table.insert(deck, tostring(data.Slot5)) end
		if data.Slot6 then table.insert(deck, tostring(data.Slot6)) end
		
		PlayerData.Deck:set(deck)
		Logger.Info("PlayerData", `Received deck: {table.concat(deck, ", ")}`)
	end)
	
	-- Handle deck save response
	Network.DeckSaved.SetCallback(function(data)
		if data.Success then
			Logger.Info("PlayerData", "Deck saved successfully")
		else
			Logger.Warn("PlayerData", `Failed to save deck: {data.Error or "unknown error"}`)
		end
	end)
	
	-- Handle stage progress sync from server
	Network.StageProgressSync.SetCallback(function(data)
		PlayerData.CurrentStage:set(data.CurrentStage)
		PlayerData.TotalStars:set(data.TotalStars)
		
		-- Build completed stages map from parallel arrays
		local completed: {[string]: number} = {}
		for i, stageId in data.CompletedStageIds do
			completed[stageId] = data.CompletedStageStars[i] or 0
		end
		PlayerData.CompletedStages:set(completed)
		
		Logger.Info("PlayerData", `Received stage progress: {data.CurrentStage}, {data.TotalStars} total stars`)
	end)
	
	-- Handle stage started event
	Network.StageStarted.On(function(data)
		PlayerData.CurrentStage:set(data.StageId)
		Logger.Info("PlayerData", `Stage started: {data.StageName} ({data.WaveCount} waves)`)
	end)
	
	-- Handle stage complete event
	Network.StageComplete.SetCallback(function(data)
		if data.Victory then
			-- Update completed stages
			local completed = Fusion.peek(PlayerData.CompletedStages)
			local newCompleted = table.clone(completed)
			if data.Stars > (newCompleted[data.StageId] or 0) then
				newCompleted[data.StageId] = data.Stars
				PlayerData.CompletedStages:set(newCompleted)
			end
			
			-- Update total stars
			local totalStars = 0
			for _, stars in newCompleted do
				totalStars += stars
			end
			PlayerData.TotalStars:set(totalStars)
		end
		
		Logger.Info("PlayerData", `Stage complete: {data.StageId} - {if data.Victory then "Victory" else "Defeat"} ({data.Stars} stars)`)
	end)
	
	Logger.Info("PlayerData", "PlayerDataClient initialized")
end

return PlayerDataClient
