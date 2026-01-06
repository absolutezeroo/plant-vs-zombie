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
	UnlockedPlants = Value(_scope, {"Sunflower", "Peashooter", "WallNut"} :: {string}),
	-- Upgrades: [PlantType] = { Damage = level, Health = level, Cooldown = level }
	PlantUpgrades = Value(_scope, {} :: {[string]: {Damage: number, Health: number, Cooldown: number}}),
	
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

-- Initialize and connect to server events
function PlayerDataClient.Initialize()
	-- Handle full data sync from server (SingleAsync = SetCallback)
	Network.PlayerDataSync.SetCallback(function(data)
		Logger.Info("PlayerData", `Received player data: {data.Coins} coins, {#data.UnlockedPlants} plants`)
		
		-- Update coins
		PlayerData.Coins:set(data.Coins)
		
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
	
	Logger.Info("PlayerData", "PlayerDataClient initialized")
end

return PlayerDataClient
