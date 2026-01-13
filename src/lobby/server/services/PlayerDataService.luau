--!strict
--[[
	PlayerDataService.luau - Lobby player data management
	
	FACADE PATTERN: This service handles ONLY:
	- ProfileStore session management (Load/Save/Get)
	- Delegation to shared handlers for logic
	- Network event firing
	
	Game logic lives in:
	- shared/handlers/EconomyHandler (Coins/Gems)
	- shared/handlers/ProgressionLogic (XP/Level)
	- shared/handlers/InventoryHandler (Plants/Deck/Stats)
	
	NOTE: Mutation operations remain in this service because they require
	      MutationData validation which is lobby-specific.
	
	Integrated with:
	- shared/data/ProfileTemplate (single source of truth)
	- shared/services/PlayerDataCore (shared utilities)
	- shared/services/TeleportDataHandler (teleport flow)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local ProfileStore = require(Packages:WaitForChild("ProfileStore"))
local Promise = require(Packages:WaitForChild("Promise"))
local Trove = require(Packages:WaitForChild("Trove"))
local Sift = require(Packages:WaitForChild("Sift"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local ProfileTemplate = require(Shared.data.ProfileTemplate) :: any
local PlayerDataCore = require(Shared.services.PlayerDataCore) :: any
local ProgressionData = require(Shared.data.ProgressionData)
local MutationData = require(Shared.data.MutationData)
local PlantData = require(Shared.data.PlantData)

-- Shared handlers (pure logic)
local EconomyHandler = require(Shared.handlers.player.EconomyHandler)
local ProgressionLogic = require(Shared.handlers.player.ProgressionLogic)
local InventoryHandler = require(Shared.handlers.player.InventoryHandler)

-- Network for XP/LevelUp events
local Network = require(Shared.network.generated.server)

-- Use shared profile template (single source of truth)
local PROFILE_TEMPLATE = ProfileTemplate.PROFILE_TEMPLATE

local PlayerDataService = {}

local Store = ProfileStore.New("PlayerData_v1", PROFILE_TEMPLATE)
local Profiles: { [Player]: any } = {}

-- Use shared systems for callbacks and profile waiting
local _dataChangeNotifier = PlayerDataCore.CreateDataChangeNotifier()
local _profileWaiter = PlayerDataCore.CreateProfileWaiter()

-- Trove for connection cleanup
local _trove = Trove.new()

--------------------------------------------------------------------------------
-- INITIALIZATION & PROFILE MANAGEMENT
--------------------------------------------------------------------------------

function PlayerDataService.Initialize()
	Logger.Info("LobbyPlayerData", "Initializing PlayerDataService for Lobby")

	_trove:Connect(Players.PlayerAdded, function(player)
		PlayerDataService.LoadProfile(player)
	end)

	_trove:Connect(Players.PlayerRemoving, function(player)
		PlayerDataService.ReleaseProfile(player)
	end)

	-- Handle existing players
	for _, player in Players:GetPlayers() do
		task.spawn(PlayerDataService.LoadProfile, player)
	end

	-- Ensure profiles are saved on shutdown
	game:BindToClose(function()
		for _, profile in Profiles do
			profile:EndSession()
		end
	end)
end

function PlayerDataService.LoadProfile(player: Player)
	Logger.Info("LobbyPlayerData", `Loading profile for {player.Name}`)

	return Promise.new(function(resolve, reject)
		local profile = Store:StartSessionAsync(`Player_{player.UserId}`, {
			Cancel = function()
				return player.Parent ~= Players
			end,
		})

		if not profile then
			reject(`Failed to load profile for {player.Name}`)
			return
		end

		profile:AddUserId(player.UserId)
		profile:Reconcile()

		profile.OnSessionEnd:Connect(function()
			Profiles[player] = nil
			if player.Parent == Players then
				player:Kick("Profile session ended")
			end
		end)

		if player.Parent ~= Players then
			profile:EndSession()
			reject("Player left during profile load")
			return
		end

		Profiles[player] = profile
		Logger.Info("LobbyPlayerData", `Profile loaded for {player.Name}`)

		-- Notify data change listeners
		_dataChangeNotifier.Notify(player, profile.Data)

		-- Fire profile waiter callbacks (for WaitForProfile)
		_profileWaiter.FireCallbacks(player, profile.Data)

		-- Notify TeleportDataHandler that profile is ready
		local TeleportDataHandler = require(Shared.services.TeleportDataHandler)
		TeleportDataHandler.NotifyProfileLoaded(player, profile.Data)

		resolve(profile.Data)
	end):catch(function(err)
		Logger.Error("LobbyPlayerData", `Profile load failed for {player.Name}: {err}`)
		if player.Parent == Players then
			player:Kick("Failed to load profile")
		end
	end)
end

function PlayerDataService.ReleaseProfile(player: Player)
	local profile = Profiles[player]
	if profile then
		profile:EndSession()
		Profiles[player] = nil
	end
	_profileWaiter.Cleanup(player)
end

function PlayerDataService.GetProfile(player: Player)
	return Profiles[player]
end

function PlayerDataService.GetData(player: Player)
	local profile = Profiles[player]
	return if profile then profile.Data else nil
end

function PlayerDataService.WaitForProfile(player: Player, timeout: number?): any
	local profile = Profiles[player]
	if profile then
		return profile.Data
	end
	if player.Parent ~= Players then
		return nil
	end
	return _profileWaiter.WaitForProfile(player, PlayerDataService.GetData, timeout)
end

function PlayerDataService.OnDataChanged(callback: (player: Player, data: any) -> ()): () -> ()
	return _dataChangeNotifier.Subscribe(callback)
end

--------------------------------------------------------------------------------
-- COINS (delegates to EconomyHandler)
--------------------------------------------------------------------------------

function PlayerDataService.GetCoins(player: Player): number
	local data = PlayerDataService.GetData(player)
	return if data then data.Coins else 0
end

function PlayerDataService.AddCoins(player: Player, amount: number): boolean
	local data = PlayerDataService.GetData(player)
	if not data then
		return false
	end

	local result = EconomyHandler.AddCoins(data, amount)
	if result.Success then
		Logger.Info("LobbyPlayerData", `{player.Name} +{amount} coins (Total: {result.NewAmount})`)
		_dataChangeNotifier.Notify(player, data)
	end

	return result.Success
end

function PlayerDataService.SpendCoins(player: Player, amount: number): boolean
	local data = PlayerDataService.GetData(player)
	if not data then
		return false
	end

	local result = EconomyHandler.SpendCoins(data, amount)
	if result.Success then
		Logger.Debug("LobbyPlayerData", `{player.Name} -{amount} coins (Remaining: {result.NewAmount})`)
		_dataChangeNotifier.Notify(player, data)
	end

	return result.Success
end

--------------------------------------------------------------------------------
-- GEMS (delegates to EconomyHandler)
--------------------------------------------------------------------------------

function PlayerDataService.GetGems(player: Player): number
	local data = PlayerDataService.GetData(player)
	return if data then data.Gems else 0
end

function PlayerDataService.AddGems(player: Player, amount: number): boolean
	local data = PlayerDataService.GetData(player)
	if not data then
		return false
	end

	local result = EconomyHandler.AddGems(data, amount)
	if result.Success then
		Logger.Info("LobbyPlayerData", `{player.Name} +{amount} gems (Total: {result.NewAmount})`)
		_dataChangeNotifier.Notify(player, data)
	end

	return result.Success
end

function PlayerDataService.SpendGems(player: Player, amount: number): boolean
	local data = PlayerDataService.GetData(player)
	if not data then
		return false
	end

	local result = EconomyHandler.SpendGems(data, amount)
	if result.Success then
		Logger.Debug("LobbyPlayerData", `{player.Name} -{amount} gems (Remaining: {result.NewAmount})`)
		_dataChangeNotifier.Notify(player, data)
	end

	return result.Success
end

--------------------------------------------------------------------------------
-- XP / LEVEL (delegates to ProgressionLogic)
--------------------------------------------------------------------------------

function PlayerDataService.GetXP(player: Player): number
	local data = PlayerDataService.GetData(player)
	return if data then data.XP else 0
end

function PlayerDataService.GetLevel(player: Player): number
	local data = PlayerDataService.GetData(player)
	return if data then data.Level else 1
end

function PlayerDataService.GetLevelProgress(player: Player): number
	local data = PlayerDataService.GetData(player)
	if not data then
		return 0
	end
	return ProgressionLogic.GetLevelProgress(data)
end

function PlayerDataService.GetXPForNextLevel(player: Player): number
	local data = PlayerDataService.GetData(player)
	if not data then
		return ProgressionData.GetXPForLevel(2)
	end
	return ProgressionData.GetXPForLevel(data.Level + 1)
end

function PlayerDataService.AddXP(player: Player, amount: number): number
	local data = PlayerDataService.GetData(player)
	if not data then
		return 0
	end

	local result = ProgressionLogic.AddXP(data, amount)

	Logger.Info("LobbyPlayerData", `{player.Name} +{amount} XP (Level {result.NewLevel}, Total: {result.NewXP})`)

	if result.LevelsGained > 0 or amount > 0 then
		_dataChangeNotifier.Notify(player, data)

		-- Fire XPGained event to client
		Network.XPGained.Fire(player, {
			Amount = amount,
			TotalXP = result.NewXP,
			CurrentLevel = result.NewLevel,
			LevelProgress = ProgressionLogic.GetLevelProgress(data),
		})

		-- Fire LevelUp event for each level gained
		if result.LevelsGained > 0 then
			local lastReward = result.Rewards[#result.Rewards]

			Network.LevelUp.Fire(player, {
				NewLevel = result.NewLevel,
				RewardCoins = lastReward and lastReward.Coins,
				RewardGems = lastReward and lastReward.Gems,
				UnlockedPlant = lastReward and lastReward.UnlockPlant,
			})

			Logger.Info("LobbyPlayerData", `🎉 {player.Name} leveled up to {result.NewLevel}!`)

			for _, reward in result.Rewards do
				if reward.UnlockPlant then
					Logger.Info("LobbyPlayerData", `  Unlocked: {reward.UnlockPlant}!`)
				end
			end
		end
	end

	return result.LevelsGained
end

--------------------------------------------------------------------------------
-- PLANTS (delegates to InventoryHandler)
--------------------------------------------------------------------------------

function PlayerDataService.HasPlant(player: Player, plantType: string): boolean
	local data = PlayerDataService.GetData(player)
	if not data then
		return false
	end
	return InventoryHandler.IsPlantUnlocked(data, plantType)
end

function PlayerDataService.GetUnlockedPlants(player: Player): { string }
	local data = PlayerDataService.GetData(player)
	if not data then
		return { "Sunflower", "Peashooter", "WallNut" }
	end
	return InventoryHandler.GetUnlockedPlants(data)
end

function PlayerDataService.UnlockPlant(player: Player, plantType: string): boolean
	local data = PlayerDataService.GetData(player)
	if not data then
		return false
	end

	local result = InventoryHandler.UnlockPlant(data, plantType)
	if result.Success then
		Logger.Info("LobbyPlayerData", `🌱 {player.Name} unlocked {plantType}!`)
		_dataChangeNotifier.Notify(player, data)
	else
		Logger.Warn("LobbyPlayerData", `{player.Name} already has {plantType}`)
	end

	return result.Success
end

function PlayerDataService.PurchasePlant(player: Player, plantType: string, cost: number): (boolean, string?)
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "ProfileNotLoaded"
	end

	-- Check if already owned
	if data.UnlockedPlants[plantType] then
		return false, "AlreadyOwned"
	end

	-- Check and spend coins via EconomyHandler
	local spendResult = EconomyHandler.SpendCoins(data, cost)
	if not spendResult.Success then
		return false, spendResult.Error
	end

	-- Unlock plant
	data.UnlockedPlants[plantType] = true

	Logger.Info("LobbyPlayerData", `💰 {player.Name} purchased {plantType} for {cost} coins (Remaining: {spendResult.NewAmount})`)
	_dataChangeNotifier.Notify(player, data)
	return true, nil
end

--------------------------------------------------------------------------------
-- DECK (delegates to InventoryHandler)
--------------------------------------------------------------------------------

function PlayerDataService.GetDeck(player: Player): { string }?
	local data = PlayerDataService.GetData(player)
	if not data then
		return nil
	end
	return InventoryHandler.GetDeck(data)
end

function PlayerDataService.SetDeck(player: Player, deck: { string }): boolean
	local data = PlayerDataService.GetData(player)
	if not data then
		return false
	end

	data.Deck = deck
	Logger.Info("LobbyPlayerData", `Deck updated for {player.Name}`, { deckSize = #deck })
	return true
end

function PlayerDataService.SaveDeck(player: Player, deck: { string }): (boolean, string?)
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "ProfileNotLoaded"
	end

	local result = InventoryHandler.SaveDeck(data, deck)
	if result.Success then
		Logger.Info("LobbyPlayerData", `{player.Name} saved deck: {table.concat(deck, ", ")}`)
		_dataChangeNotifier.Notify(player, data)
	end

	return result.Success, result.Error
end

--------------------------------------------------------------------------------
-- STATS (delegates to InventoryHandler)
--------------------------------------------------------------------------------

function PlayerDataService.GetStats(
	player: Player
): { GamesPlayed: number, GamesWon: number, ZombiesKilled: number, PlantsPlaced: number }
	local data = PlayerDataService.GetData(player)
	if not data then
		return { GamesPlayed = 0, GamesWon = 0, ZombiesKilled = 0, PlantsPlaced = 0 }
	end
	return data.Stats
end

function PlayerDataService.IncrementStat(player: Player, statName: string, amount: number?)
	local data = PlayerDataService.GetData(player)
	if not data then
		return
	end

	InventoryHandler.IncrementStat(data, statName, amount)
	_dataChangeNotifier.Notify(player, data)
end

--------------------------------------------------------------------------------
-- MUTATION SYSTEM (Lobby-specific, uses MutationData)
--------------------------------------------------------------------------------

-- Get OWNED mutations for a specific plant (purchased)
function PlayerDataService.GetOwnedMutations(player: Player, plantType: string): { string }
	local data = PlayerDataService.GetData(player)
	if not data then
		return {}
	end
	return data.PlantOwnedMutations[plantType] or {}
end

-- Get all OWNED mutations for all plants
function PlayerDataService.GetAllOwnedMutations(player: Player): { [string]: { string } }
	local data = PlayerDataService.GetData(player)
	if not data then
		return {}
	end
	return data.PlantOwnedMutations or {}
end

-- Check if player OWNS a mutation for a plant
function PlayerDataService.OwnsMutation(player: Player, plantType: string, mutationType: string): boolean
	local mutations = PlayerDataService.GetOwnedMutations(player, plantType)
	return table.find(mutations, mutationType) ~= nil
end

-- Get EQUIPPED mutations for a specific plant (active in game)
function PlayerDataService.GetEquippedMutations(player: Player, plantType: string): { string }
	local data = PlayerDataService.GetData(player)
	if not data then
		return {}
	end
	return data.PlantEquippedMutations[plantType] or {}
end

-- Get all EQUIPPED mutations for all plants
function PlayerDataService.GetAllEquippedMutations(player: Player): { [string]: { string } }
	local data = PlayerDataService.GetData(player)
	if not data then
		return {}
	end
	return data.PlantEquippedMutations or {}
end

-- Check if a mutation is EQUIPPED on a plant
function PlayerDataService.HasMutationEquipped(player: Player, plantType: string, mutationType: string): boolean
	local mutations = PlayerDataService.GetEquippedMutations(player, plantType)
	return table.find(mutations, mutationType) ~= nil
end

-- Purchase a mutation for a plant (adds to PlantOwnedMutations)
function PlayerDataService.PurchaseMutation(
	player: Player,
	plantType: string,
	mutationType: string
): (boolean, string?, number?)
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "ProfileNotLoaded", nil
	end

	-- Check if plant is unlocked
	if not data.UnlockedPlants[plantType] then
		return false, "PlantNotUnlocked", nil
	end

	-- Get mutation info
	local mutationInfo = MutationData.Get(mutationType)
	if not mutationInfo then
		return false, "InvalidMutation", nil
	end

	-- Check player level requirement
	if data.Level < mutationInfo.RequiredLevel then
		return false, "LevelTooLow", nil
	end

	-- Check if already OWNS this mutation for this plant
	if PlayerDataService.OwnsMutation(player, plantType, mutationType) then
		return false, "AlreadyHas", nil
	end

	-- Check plant category compatibility
	local plantStats = PlantData[plantType]
	if plantStats then
		local category = plantStats.Category
		if not MutationData.IsCompatibleWith(mutationType, category) then
			return false, "Incompatible", nil
		end
	end

	-- Check and spend coins via EconomyHandler
	local spendResult = EconomyHandler.SpendCoins(data, mutationInfo.Cost)
	if not spendResult.Success then
		return false, spendResult.Error, nil
	end

	-- Add to OWNED mutations
	if not data.PlantOwnedMutations[plantType] then
		data.PlantOwnedMutations[plantType] = {}
	end
	data.PlantOwnedMutations[plantType] = Sift.Array.push(data.PlantOwnedMutations[plantType], mutationType)

	Logger.Info(
		"LobbyPlayerData",
		`🧬 {player.Name} purchased {mutationType} for {plantType} (Cost: {mutationInfo.Cost}, Remaining: {data.Coins})`
	)
	_dataChangeNotifier.Notify(player, data)
	return true, nil, data.Coins
end

-- Equip a mutation on a plant (must be owned first)
function PlayerDataService.EquipMutation(player: Player, plantType: string, mutationType: string): (boolean, string?)
	local data = PlayerDataService.GetData(player)
	if not data then
		return false, "ProfileNotLoaded"
	end

	-- Check if player owns this mutation for this plant
	if not PlayerDataService.OwnsMutation(player, plantType, mutationType) then
		return false, "NotOwned"
	end

	-- Check if already equipped
	if PlayerDataService.HasMutationEquipped(player, plantType, mutationType) then
		return false, "AlreadyEquipped"
	end

	-- Check incompatibility with currently equipped mutations
	local equippedMutations = PlayerDataService.GetEquippedMutations(player, plantType)
	for _, existingMutation in equippedMutations do
		if not MutationData.AreCompatible(mutationType, existingMutation) then
			return false, "Incompatible"
		end
	end

	-- Equip the mutation
	if not data.PlantEquippedMutations[plantType] then
		data.PlantEquippedMutations[plantType] = {}
	end
	data.PlantEquippedMutations[plantType] = Sift.Array.push(data.PlantEquippedMutations[plantType], mutationType)

	Logger.Info("LobbyPlayerData", `🧬 {player.Name} equipped {mutationType} on {plantType}`)
	_dataChangeNotifier.Notify(player, data)
	return true, nil
end

-- Unequip a mutation from a plant (stays in owned)
function PlayerDataService.UnequipMutation(player: Player, plantType: string, mutationType: string): boolean
	local data = PlayerDataService.GetData(player)
	if not data then
		return false
	end

	local mutations = data.PlantEquippedMutations[plantType]
	if not mutations then
		return false
	end

	local index = table.find(mutations, mutationType)
	if index then
		data.PlantEquippedMutations[plantType] = Sift.Array.removeIndex(mutations, index)
		Logger.Info("LobbyPlayerData", `🧬 {player.Name} unequipped {mutationType} from {plantType}`)
		_dataChangeNotifier.Notify(player, data)
		return true
	end

	return false
end

--------------------------------------------------------------------------------
-- SYNC TO CLIENT
--------------------------------------------------------------------------------

function PlayerDataService.SyncToClient(player: Player)
	local data = PlayerDataService.GetData(player)
	if not data then
		return
	end

	local unlockedPlants = {}
	for plantType, _ in pairs(data.UnlockedPlants or {}) do
		table.insert(unlockedPlants, plantType)
	end

	Network.FullPlayerDataSync.Fire(player, {
		Coins = data.Coins or 0,
		Gems = data.Gems or 0,
		Level = data.Level or 1,
		XP = data.XP or 0,
		TotalXPForNextLevel = ProgressionData.GetXPForLevel((data.Level or 1) + 1),
		GamesPlayed = data.Stats.GamesPlayed or 0,
		GamesWon = data.Stats.GamesWon or 0,
		ZombiesKilled = data.Stats.ZombiesKilled or 0,
		PlantsPlaced = data.Stats.PlantsPlaced or 0,
		UnlockedPlants = unlockedPlants,
		Deck = data.Deck or { "Sunflower", "Peashooter", "WallNut" },
	})

	Logger.Debug("LobbyPlayerData", `Synced data to {player.Name}`)
end

--------------------------------------------------------------------------------
-- DEBUG / ADMIN UTILITIES (for Cmdr commands)
--------------------------------------------------------------------------------

--[[
	Reset player data to defaults.
	Used by admin commands for testing.
]]
function PlayerDataService.ResetProfile(player: Player): boolean
	local data = PlayerDataService.GetData(player)
	if not data then
		return false
	end

	-- Reset currencies
	data.Coins = 500
	data.TotalCoinsEarned = 500
	data.Gems = 50
	data.TotalGemsEarned = 50

	-- Reset progression
	data.Level = 1
	data.XP = 0

	-- Reset stats
	data.Stats.GamesPlayed = 0
	data.Stats.GamesWon = 0
	data.Stats.ZombiesKilled = 0
	data.Stats.PlantsPlaced = 0

	-- Reset inventory to starters only
	data.UnlockedPlants = {
		Sunflower = true,
		Peashooter = true,
		WallNut = true,
	}
	data.Deck = { "Sunflower", "Peashooter", "WallNut" }
	data.PlantOwnedMutations = {}
	data.PlantEquippedMutations = {}
	data.PlantMastery = {}

	Logger.Info("LobbyPlayerData", `🔄 Reset all data for {player.Name}`)
	_dataChangeNotifier.Notify(player, data)
	return true
end

--[[
	Max out all resources for testing.
	Used by admin commands.
]]
function PlayerDataService.MaxResources(player: Player): boolean
	local data = PlayerDataService.GetData(player)
	if not data then
		return false
	end

	data.Coins = 999999
	data.TotalCoinsEarned = 999999
	data.Gems = 9999
	data.TotalGemsEarned = 9999
	data.Level = ProgressionData.MAX_LEVEL
	data.XP = 0

	-- Unlock all plants
	for plantType, _ in ProgressionData.PlantUnlocks do
		data.UnlockedPlants[plantType] = true
	end

	Logger.Info("LobbyPlayerData", `💎 Maxed resources for {player.Name}`)
	_dataChangeNotifier.Notify(player, data)
	return true
end

--[[
	Set player level directly (for testing).
	Resets XP to 0 at new level.
]]
function PlayerDataService.SetLevel(player: Player, level: number): boolean
	local data = PlayerDataService.GetData(player)
	if not data then
		return false
	end

	level = math.clamp(level, 1, ProgressionData.MAX_LEVEL)
	data.Level = level
	data.XP = ProgressionData.GetTotalXPForLevel(level)

	Logger.Info("LobbyPlayerData", `📊 Set {player.Name} to level {level}`)
	_dataChangeNotifier.Notify(player, data)
	return true
end

--[[
	Set coins directly (for testing).
]]
function PlayerDataService.SetCoins(player: Player, amount: number): boolean
	local data = PlayerDataService.GetData(player)
	if not data then
		return false
	end

	data.Coins = math.max(0, amount)
	Logger.Info("LobbyPlayerData", `💰 Set {player.Name} coins to {amount}`)
	_dataChangeNotifier.Notify(player, data)
	return true
end

--[[
	Set gems directly (for testing).
]]
function PlayerDataService.SetGems(player: Player, amount: number): boolean
	local data = PlayerDataService.GetData(player)
	if not data then
		return false
	end

	data.Gems = math.max(0, amount)
	Logger.Info("LobbyPlayerData", `💎 Set {player.Name} gems to {amount}`)
	_dataChangeNotifier.Notify(player, data)
	return true
end

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------

function PlayerDataService.Dispose()
	Logger.Info("LobbyPlayerData", "Disposing PlayerDataService...")
	_trove:Clean()
end

return PlayerDataService
