--!strict
--[[
	ProgressionHandler.luau - Server-side progression event handlers
	
	Handles:
	- Player data sync on join
	- UnlockPlant requests
	- Deck management
	
	Note: Upgrades replaced by Mutations system (see MutationHandler)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

-- Network
local Network = require(Shared.network.generated.server)

-- Server modules
local Server = script.Parent.Parent
local PlayerDataService = require(Server.services.PlayerDataService)
local MutationService = require(Server.services.MutationService)

local ProgressionHandler = {}

-- Send full player data to a client
local function syncPlayerData(player: Player)
	local data = PlayerDataService.GetProfile(player)
	if not data then
		Logger.Warn("Progression", `Cannot sync data for {player.Name} - profile not loaded`)
		return
	end

	-- Build unlocked plants list
	local unlockedPlants: { any } = {}
	for plantType, isUnlocked in data.UnlockedPlants do
		if isUnlocked then
			table.insert(unlockedPlants, plantType)
		end
	end

	Network.PlayerDataSync.Fire(player, {
		Coins = data.Coins,
		Gems = data.Gems or 0,
		XP = data.XP or 0,
		Level = data.Level or 1,
		LevelProgress = PlayerDataService.GetLevelProgress(player),
		UnlockedPlants = unlockedPlants,
	})

	-- Sync mutations via dedicated event (AllMutationsSync)
	local equippedMutationsDict = MutationService.GetPlayerMutations(player.UserId)
	local ownedMutationsDict = MutationService.GetOwnedMutations and MutationService.GetOwnedMutations(player.UserId)
		or {}

	-- Convert to array format for Zap
	local equippedMutationsArray = {}
	local ownedMutationsArray = {}

	for plantType, mutations in equippedMutationsDict do
		table.insert(equippedMutationsArray, {
			PlantType = plantType,
			Mutations = mutations,
		})
	end

	for plantType, mutations in ownedMutationsDict do
		table.insert(ownedMutationsArray, {
			PlantType = plantType,
			Mutations = mutations,
		})
	end

	Network.AllMutationsSync.Fire(player, {
		OwnedMutations = ownedMutationsArray,
		EquippedMutations = equippedMutationsArray,
	})

	Logger.Debug("Progression", `Synced player data to {player.Name}`)
end

-- Handle unlock plant request
local function handleUnlockPlant(player: Player, data: { RequestId: number, PlantType: any })
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
local function handleSaveDeck(
	player: Player,
	data: { Slot1: any?, Slot2: any?, Slot3: any?, Slot4: any?, Slot5: any?, Slot6: any? }
)
	-- Build deck from slots
	local deck = {}
	if data.Slot1 then
		table.insert(deck, tostring(data.Slot1))
	end
	if data.Slot2 then
		table.insert(deck, tostring(data.Slot2))
	end
	if data.Slot3 then
		table.insert(deck, tostring(data.Slot3))
	end
	if data.Slot4 then
		table.insert(deck, tostring(data.Slot4))
	end
	if data.Slot5 then
		table.insert(deck, tostring(data.Slot5))
	end
	if data.Slot6 then
		table.insert(deck, tostring(data.Slot6))
	end

	local success, reason = PlayerDataService.SaveDeck(player, deck)

	-- Send response
	Network.DeckSaveResponse.Fire(player, {
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

	-- NOTE: Player join handling is now centralized in TeleportDataHandler
	-- TeleportDataHandler.OnPlayerReady fires AFTER:
	--   1. Profile is loaded
	--   2. Teleport data is validated
	--   3. Deck is saved to profile
	--   4. Mutations are loaded into cache
	-- Then init.server.luau calls SyncPlayerData and SyncDeck

	-- Register network handlers
	Network.UnlockPlantRequest.SetCallback(handleUnlockPlant)
	Network.SaveDeckRequest.SetCallback(handleSaveDeck)

	Logger.Info("Progression", "ProgressionHandler initialized")
end

-- Expose syncDeck for external use (e.g., after teleport deck save)
function ProgressionHandler.SyncDeck(player: Player)
	syncDeck(player)
end

-- Expose syncPlayerData for external use (e.g., after mutations loaded)
function ProgressionHandler.SyncPlayerData(player: Player)
	syncPlayerData(player)
end

return ProgressionHandler
