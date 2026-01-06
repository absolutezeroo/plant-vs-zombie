--!strict
--[[
	ProgressionHandler.luau - Server-side progression event handlers
	
	Handles:
	- Player data sync on join
	- UnlockPlant requests
	- PurchaseUpgrade requests
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

local Server = script.Parent.Parent
local Network = require(Server.network.generated)
local PlayerDataService = require(Server.services.PlayerDataService)

local ProgressionHandler = {}

-- Send full player data to a client
local function syncPlayerData(player: Player)
	local data = PlayerDataService.GetProfile(player)
	if not data then
		Logger.Warn("Progression", `Cannot sync data for {player.Name} - profile not loaded`)
		return
	end
	
	-- Build unlocked plants list
	local unlockedPlants: {any} = {}
	for plantType, isUnlocked in data.UnlockedPlants do
		if isUnlocked then
			table.insert(unlockedPlants, plantType)
		end
	end
	
	-- Build upgrade arrays (parallel arrays for Zap)
	local upgradePlantTypes: {any} = {}
	local upgradeDamage: {number} = {}
	local upgradeHealth: {number} = {}
	local upgradeCooldown: {number} = {}
	
	for plantType, upgrades in data.PlantUpgrades do
		table.insert(upgradePlantTypes, plantType)
		table.insert(upgradeDamage, upgrades.Damage or 0)
		table.insert(upgradeHealth, upgrades.Health or 0)
		table.insert(upgradeCooldown, upgrades.Cooldown or 0)
	end
	
	Network.PlayerDataSync.Fire(player, {
		Coins = data.Coins,
		Gems = data.Gems or 0,
		XP = data.XP or 0,
		Level = data.Level or 1,
		LevelProgress = PlayerDataService.GetLevelProgress(player),
		UnlockedPlants = unlockedPlants,
		UpgradePlantTypes = upgradePlantTypes,
		UpgradeDamage = upgradeDamage,
		UpgradeHealth = upgradeHealth,
		UpgradeCooldown = upgradeCooldown,
	})
	
	Logger.Debug("Progression", `Synced player data to {player.Name}`)
end

-- Handle unlock plant request
local function handleUnlockPlant(player: Player, data: {RequestId: number, PlantType: any})
	local plantType = tostring(data.PlantType)
	
	local success, reason = PlayerDataService.UnlockPlant(player, plantType)
	
	-- Send response
	Network.RequestResponse.Fire(player, {
		RequestId = data.RequestId,
		Success = success,
		ErrorCode = if success then nil else 5, -- 5 = unlock failed
	})
	
	if success then
		-- Sync updated data
		syncPlayerData(player)
		Logger.Info("Progression", `{player.Name} unlocked {plantType}`)
	else
		Logger.Debug("Progression", `{player.Name} failed to unlock {plantType}: {reason}`)
	end
end

-- Handle purchase upgrade request
local function handlePurchaseUpgrade(player: Player, data: {RequestId: number, PlantType: any, UpgradeType: any})
	local plantType = tostring(data.PlantType)
	local upgradeType = tostring(data.UpgradeType)
	
	local success, reason = PlayerDataService.PurchaseUpgrade(player, plantType, upgradeType)
	
	-- Send response
	Network.RequestResponse.Fire(player, {
		RequestId = data.RequestId,
		Success = success,
		ErrorCode = if success then nil else 6, -- 6 = upgrade failed
	})
	
	if success then
		-- Sync updated data
		syncPlayerData(player)
		Logger.Info("Progression", `{player.Name} upgraded {plantType} {upgradeType}`)
	else
		Logger.Debug("Progression", `{player.Name} failed to upgrade {plantType} {upgradeType}: {reason}`)
	end
end

-- Sync deck to client
local function syncDeck(player: Player)
	local deck = PlayerDataService.GetDeck(player)
	
	-- Build deck data (up to 6 slots)
	local deckData = {
		Slot1 = deck[1],
		Slot2 = deck[2],
		Slot3 = deck[3],
		Slot4 = deck[4],
		Slot5 = deck[5],
		Slot6 = deck[6],
	}
	
	Network.DeckSync.Fire(player, deckData)
	Logger.Debug("Progression", `Synced deck to {player.Name}: {table.concat(deck, ", ")}`)
end

-- Handle save deck request
local function handleSaveDeck(player: Player, data: {Slot1: any?, Slot2: any?, Slot3: any?, Slot4: any?, Slot5: any?, Slot6: any?})
	-- Build deck from slots
	local deck = {}
	if data.Slot1 then table.insert(deck, tostring(data.Slot1)) end
	if data.Slot2 then table.insert(deck, tostring(data.Slot2)) end
	if data.Slot3 then table.insert(deck, tostring(data.Slot3)) end
	if data.Slot4 then table.insert(deck, tostring(data.Slot4)) end
	if data.Slot5 then table.insert(deck, tostring(data.Slot5)) end
	if data.Slot6 then table.insert(deck, tostring(data.Slot6)) end
	
	local success, reason = PlayerDataService.SaveDeck(player, deck)
	
	-- Send response
	Network.DeckSaved.Fire(player, {
		Success = success,
		Error = reason,
	})
	
	if success then
		Logger.Info("Progression", `{player.Name} saved deck: {table.concat(deck, ", ")}`)
	else
		Logger.Debug("Progression", `{player.Name} failed to save deck: {reason}`)
	end
end

-- Initialize handlers
function ProgressionHandler.Initialize()
	-- Register data change callback to sync on any change
	PlayerDataService.OnDataChanged(function(player, _data)
		syncPlayerData(player)
	end)
	
	-- Handle player joins - send initial data with delay to ensure profile is loaded
	Players.PlayerAdded:Connect(function(player)
		-- Wait for profile to load
		task.wait(1)
		
		-- Check if profile loaded
		local attempts = 0
		while not PlayerDataService.GetProfile(player) and attempts < 10 do
			task.wait(0.5)
			attempts += 1
		end
		
		syncPlayerData(player)
		syncDeck(player)
	end)
	
	-- Handle existing players (for Studio hot-reload)
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			task.wait(0.5)
			syncPlayerData(player)
			syncDeck(player)
		end)
	end
	
	-- Register network handlers
	Network.UnlockPlantRequest.SetCallback(handleUnlockPlant)
	Network.PurchaseUpgradeRequest.SetCallback(handlePurchaseUpgrade)
	Network.SaveDeckRequest.SetCallback(handleSaveDeck)
	
	Logger.Info("Progression", "ProgressionHandler initialized")
end

return ProgressionHandler
