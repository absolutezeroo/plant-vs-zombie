--!strict
--[[
    PlayerDataService.luau - Lobby player data management
    
    Uses ProfileStore for cross-session persistence.
    Manages: Coins, Gems, XP, Level, Plants, Mutations, Deck
    
    Server-side only. Clients receive replicated data via events.
    
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
		for player, profile in Profiles do
			profile:EndSession()
		end
	end)
end

--[[
    Load player profile with Promise-based async handling.
    Returns Promise<ProfileData> that resolves when profile is ready.
]]
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

	-- Clean up profile waiter
	_profileWaiter.Cleanup(player)
end

function PlayerDataService.GetProfile(player: Player)
	return Profiles[player]
end

--[[
    Wait for a player's profile to be loaded.
    Uses signal-based waiting (no polling).
    Returns the profile data once loaded, or nil if timeout/player left.
]]
function PlayerDataService.WaitForProfile(player: Player, timeout: number?): any
	-- Already loaded?
	local profile = Profiles[player]
	if profile then
		return profile.Data
	end

	-- Player already left?
	if player.Parent ~= Players then
		return nil
	end

	return _profileWaiter.WaitForProfile(player, PlayerDataService.GetData, timeout)
end

-- Register callback for data changes (returns unsubscribe function)
function PlayerDataService.OnDataChanged(callback: (player: Player, data: any) -> ()): () -> ()
	return _dataChangeNotifier.Subscribe(callback)
end

function PlayerDataService.GetData(player: Player)
	local profile = Profiles[player]
	return if profile then profile.Data else nil
end

-- Set player's current deck (saved for reuse)
function PlayerDataService.SetDeck(player: Player, deck: { string }): boolean
	local profile = Profiles[player]
	if not profile then
		return false
	end

	profile.Data.Deck = deck
	Logger.Info("LobbyPlayerData", `Deck updated for {player.Name}`, { deckSize = #deck })
	return true
end

-- Get player's current deck
function PlayerDataService.GetDeck(player: Player): { string }?
	local profile = Profiles[player]
	if not profile then
		return nil
	end
	return profile.Data.Deck
end

-- ============================================
-- COINS SYSTEM
-- ============================================

-- Get coins for a player
function PlayerDataService.GetCoins(player: Player): number
	local profile = Profiles[player]
	return if profile then profile.Data.Coins else 0
end

-- Add coins to a player
function PlayerDataService.AddCoins(player: Player, amount: number): boolean
	local profile = Profiles[player]
	if not profile then
		return false
	end

	profile.Data.Coins += amount
	profile.Data.TotalCoinsEarned += amount

	Logger.Info("LobbyPlayerData", `{player.Name} +{amount} coins (Total: {profile.Data.Coins})`)
	_dataChangeNotifier.Notify(player, profile.Data)
	return true
end

-- Spend coins (returns false if not enough)
function PlayerDataService.SpendCoins(player: Player, amount: number): boolean
	local profile = Profiles[player]
	if not profile then
		return false
	end

	if profile.Data.Coins < amount then
		return false
	end

	profile.Data.Coins -= amount
	Logger.Debug("LobbyPlayerData", `{player.Name} -{amount} coins (Remaining: {profile.Data.Coins})`)
	_dataChangeNotifier.Notify(player, profile.Data)
	return true
end

-- Add gems to a player
function PlayerDataService.AddGems(player: Player, amount: number): boolean
	local profile = Profiles[player]
	if not profile then
		return false
	end

	profile.Data.Gems += amount
	profile.Data.TotalGemsEarned += amount

	Logger.Info("LobbyPlayerData", `{player.Name} +{amount} gems (Total: {profile.Data.Gems})`)
	_dataChangeNotifier.Notify(player, profile.Data)
	return true
end

-- Spend gems (returns false if not enough)
function PlayerDataService.SpendGems(player: Player, amount: number): boolean
	local profile = Profiles[player]
	if not profile then
		return false
	end

	if profile.Data.Gems < amount then
		return false
	end

	profile.Data.Gems -= amount
	Logger.Debug("LobbyPlayerData", `{player.Name} -{amount} gems (Remaining: {profile.Data.Gems})`)
	_dataChangeNotifier.Notify(player, profile.Data)
	return true
end

-- Get XP progress to next level (0.0 - 1.0)
function PlayerDataService.GetLevelProgress(player: Player): number
	local profile = Profiles[player]
	if not profile then
		return 0
	end

	if profile.Data.Level >= ProgressionData.MAX_LEVEL then
		return 1.0
	end

	local currentLevelTotalXP = ProgressionData.GetTotalXPForLevel(profile.Data.Level)
	local nextLevelTotalXP = ProgressionData.GetTotalXPForLevel(profile.Data.Level + 1)
	local xpInCurrentLevel = profile.Data.XP - currentLevelTotalXP
	local xpNeededForLevel = nextLevelTotalXP - currentLevelTotalXP

	return math.clamp(xpInCurrentLevel / xpNeededForLevel, 0, 1)
end

-- Increment a stat
function PlayerDataService.IncrementStat(player: Player, statName: string, amount: number?)
	local profile = Profiles[player]
	if not profile then
		return
	end

	local currentValue = profile.Data.Stats[statName] or 0
	profile.Data.Stats[statName] = currentValue + (amount or 1)
	_dataChangeNotifier.Notify(player, profile.Data)
end

-- ============================================
-- XP / LEVEL SYSTEM
-- ============================================

-- Add XP to a player (uses ProgressionData for proper level calculation)
function PlayerDataService.AddXP(player: Player, amount: number): number
	local profile = Profiles[player]
	if not profile then
		return 0
	end

	local oldLevel = profile.Data.Level
	profile.Data.XP += amount

	-- Check for level ups using ProgressionData
	local levelsGained = 0
	while profile.Data.Level < ProgressionData.MAX_LEVEL do
		local xpNeeded = ProgressionData.GetXPForLevel(profile.Data.Level + 1)
		local currentLevelXP = profile.Data.XP - ProgressionData.GetTotalXPForLevel(profile.Data.Level)

		if currentLevelXP >= xpNeeded then
			profile.Data.Level += 1
			levelsGained += 1

			Logger.Info("LobbyPlayerData", `🎉 {player.Name} leveled up to {profile.Data.Level}!`)

			-- Award level-up gems
			profile.Data.Gems += ProgressionData.GEMS_PER_LEVEL_UP
			profile.Data.TotalGemsEarned += ProgressionData.GEMS_PER_LEVEL_UP

			-- Check for milestone rewards
			local reward = ProgressionData.LevelRewards[profile.Data.Level]
			if reward then
				if reward.Coins then
					profile.Data.Coins += reward.Coins
					profile.Data.TotalCoinsEarned += reward.Coins
				end
				if reward.Gems then
					profile.Data.Gems += reward.Gems
					profile.Data.TotalGemsEarned += reward.Gems
				end
				if reward.UnlockPlant then
					profile.Data.UnlockedPlants[reward.UnlockPlant] = true
					Logger.Info("LobbyPlayerData", `  Unlocked: {reward.UnlockPlant}!`)
				end
			end
		else
			break
		end
	end

	Logger.Info("LobbyPlayerData", `{player.Name} +{amount} XP (Level {profile.Data.Level}, Total: {profile.Data.XP})`)

	if levelsGained > 0 or amount > 0 then
		_dataChangeNotifier.Notify(player, profile.Data)

		-- Fire XPGained event to client
		local levelProgress = PlayerDataService.GetLevelProgress(player)
		Network.XPGained.Fire(player, {
			Amount = amount,
			TotalXP = profile.Data.XP,
			CurrentLevel = profile.Data.Level,
			LevelProgress = levelProgress,
		})

		-- Fire LevelUp event for each level gained
		if levelsGained > 0 then
			local reward = ProgressionData.LevelRewards[profile.Data.Level]
			local rewardCoins = if reward and reward.Coins then reward.Coins else nil
			local rewardGems = if reward and reward.Gems then reward.Gems else ProgressionData.GEMS_PER_LEVEL_UP
			local unlockedPlant = if reward and reward.UnlockPlant then reward.UnlockPlant else nil

			Network.LevelUp.Fire(player, {
				NewLevel = profile.Data.Level,
				RewardCoins = rewardCoins,
				RewardGems = rewardGems,
				UnlockedPlant = unlockedPlant,
			})

			Logger.Info("LobbyPlayerData", `📣 Sent LevelUp event to {player.Name}: Level {profile.Data.Level}`)
		end
	end

	return levelsGained
end

-- Get current level
function PlayerDataService.GetLevel(player: Player): number
	local profile = Profiles[player]
	return if profile then profile.Data.Level else 1
end

-- Get current XP
function PlayerDataService.GetXP(player: Player): number
	local profile = Profiles[player]
	return if profile then profile.Data.XP else 0
end

-- ============================================
-- PLANT UNLOCK SYSTEM
-- ============================================

-- Check if player has unlocked a specific plant
function PlayerDataService.HasPlant(player: Player, plantType: string): boolean
	local profile = Profiles[player]
	if not profile then
		return false
	end
	return profile.Data.UnlockedPlants[plantType] == true
end

-- Get all unlocked plants for a player
function PlayerDataService.GetUnlockedPlants(player: Player): { string }
	local profile = Profiles[player]
	if not profile then
		return { "Sunflower", "Peashooter", "WallNut" }
	end

	local plants = {}
	for plantType, isUnlocked in pairs(profile.Data.UnlockedPlants) do
		if isUnlocked then
			plants = Sift.Array.push(plants, plantType)
		end
	end
	return plants
end

-- Unlock a plant for a player (free unlock, e.g., from level reward)
function PlayerDataService.UnlockPlant(player: Player, plantType: string): boolean
	local profile = Profiles[player]
	if not profile then
		return false
	end

	if profile.Data.UnlockedPlants[plantType] then
		Logger.Warn("LobbyPlayerData", `{player.Name} already has {plantType}`)
		return false
	end

	profile.Data.UnlockedPlants[plantType] = true
	Logger.Info("LobbyPlayerData", `🌱 {player.Name} unlocked {plantType}!`)
	return true
end

-- Purchase a plant with coins
function PlayerDataService.PurchasePlant(player: Player, plantType: string, cost: number): (boolean, string?)
	local profile = Profiles[player]
	if not profile then
		return false, "ProfileNotLoaded"
	end

	-- Check if already owned
	if profile.Data.UnlockedPlants[plantType] then
		return false, "AlreadyOwned"
	end

	-- Check if enough coins
	if profile.Data.Coins < cost then
		return false, "NotEnoughCoins"
	end

	-- Deduct coins and unlock
	profile.Data.Coins -= cost
	profile.Data.UnlockedPlants[plantType] = true

	Logger.Info(
		"LobbyPlayerData",
		`💰 {player.Name} purchased {plantType} for {cost} coins (Remaining: {profile.Data.Coins})`
	)
	return true, nil
end

-- ============================================
-- STATS SYSTEM
-- ============================================

-- Get player stats
function PlayerDataService.GetStats(
	player: Player
): { GamesPlayed: number, GamesWon: number, ZombiesKilled: number, PlantsPlaced: number }
	local profile = Profiles[player]
	if not profile then
		return { GamesPlayed = 0, GamesWon = 0, ZombiesKilled = 0, PlantsPlaced = 0 }
	end
	return profile.Data.Stats
end

-- Get gems
function PlayerDataService.GetGems(player: Player): number
	local profile = Profiles[player]
	return if profile then profile.Data.Gems else 0
end

-- Get total XP needed for next level
function PlayerDataService.GetXPForNextLevel(player: Player): number
	local profile = Profiles[player]
	if not profile then
		return ProgressionData.GetXPForLevel(2)
	end
	local level = profile.Data.Level
	return ProgressionData.GetXPForLevel(level + 1)
end

-- ============================================
-- MUTATION SYSTEM
-- ============================================

local MutationData = require(Shared.data.MutationData)
local PlantData = require(Shared.data.PlantData)

-- ============================================
-- MUTATION SYSTEM (Owned vs Equipped)
-- ============================================

-- Get OWNED mutations for a specific plant (purchased)
function PlayerDataService.GetOwnedMutations(player: Player, plantType: string): { string }
	local profile = Profiles[player]
	if not profile then
		return {}
	end
	return profile.Data.PlantOwnedMutations[plantType] or {}
end

-- Get all OWNED mutations for all plants
function PlayerDataService.GetAllOwnedMutations(player: Player): { [string]: { string } }
	local profile = Profiles[player]
	if not profile then
		return {}
	end
	return profile.Data.PlantOwnedMutations or {}
end

-- Check if player OWNS a mutation for a plant
function PlayerDataService.OwnsMutation(player: Player, plantType: string, mutationType: string): boolean
	local mutations = PlayerDataService.GetOwnedMutations(player, plantType)
	return table.find(mutations, mutationType) ~= nil
end

-- Get EQUIPPED mutations for a specific plant (active in game)
function PlayerDataService.GetEquippedMutations(player: Player, plantType: string): { string }
	local profile = Profiles[player]
	if not profile then
		return {}
	end
	return profile.Data.PlantEquippedMutations[plantType] or {}
end

-- Get all EQUIPPED mutations for all plants
function PlayerDataService.GetAllEquippedMutations(player: Player): { [string]: { string } }
	local profile = Profiles[player]
	if not profile then
		return {}
	end
	return profile.Data.PlantEquippedMutations or {}
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
	local profile = Profiles[player]
	if not profile then
		return false, "ProfileNotLoaded", nil
	end

	-- Check if plant is unlocked
	if not profile.Data.UnlockedPlants[plantType] then
		return false, "PlantNotUnlocked", nil
	end

	-- Get mutation info
	local mutationInfo = MutationData.Get(mutationType)
	if not mutationInfo then
		return false, "InvalidMutation", nil
	end

	-- Check player level requirement
	if profile.Data.Level < mutationInfo.RequiredLevel then
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

	-- Check if enough coins
	if profile.Data.Coins < mutationInfo.Cost then
		return false, "NotEnoughCoins", nil
	end

	-- Deduct coins
	profile.Data.Coins -= mutationInfo.Cost

	-- Add to OWNED mutations
	if not profile.Data.PlantOwnedMutations[plantType] then
		profile.Data.PlantOwnedMutations[plantType] = {}
	end
	profile.Data.PlantOwnedMutations[plantType] =
		Sift.Array.push(profile.Data.PlantOwnedMutations[plantType], mutationType)

	Logger.Info(
		"LobbyPlayerData",
		`🧬 {player.Name} purchased {mutationType} for {plantType} (Cost: {mutationInfo.Cost}, Remaining: {profile.Data.Coins})`
	)
	return true, nil, profile.Data.Coins
end

-- Equip a mutation on a plant (must be owned first)
function PlayerDataService.EquipMutation(player: Player, plantType: string, mutationType: string): (boolean, string?)
	local profile = Profiles[player]
	if not profile then
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
	if not profile.Data.PlantEquippedMutations[plantType] then
		profile.Data.PlantEquippedMutations[plantType] = {}
	end
	profile.Data.PlantEquippedMutations[plantType] =
		Sift.Array.push(profile.Data.PlantEquippedMutations[plantType], mutationType)

	Logger.Info("LobbyPlayerData", `🧬 {player.Name} equipped {mutationType} on {plantType}`)
	return true, nil
end

-- Unequip a mutation from a plant (stays in owned)
function PlayerDataService.UnequipMutation(player: Player, plantType: string, mutationType: string): boolean
	local profile = Profiles[player]
	if not profile then
		return false
	end

	local mutations = profile.Data.PlantEquippedMutations[plantType]
	if not mutations then
		return false
	end

	local index = table.find(mutations, mutationType)
	if index then
		profile.Data.PlantEquippedMutations[plantType] = Sift.Array.removeIndex(mutations, index)
		Logger.Info("LobbyPlayerData", `🧬 {player.Name} unequipped {mutationType} from {plantType}`)
		return true
	end

	return false
end

-- Sync all player data to the client
function PlayerDataService.SyncToClient(player: Player)
	local profile = Profiles[player]
	if not profile then
		return
	end

	local coins = profile.Data.Coins or 0
	local gems = profile.Data.Gems or 0
	local level = profile.Data.Level or 1
	local xp = profile.Data.XP or 0
	local xpForNext = profile.Data.TotalXPForNextLevel or 100
	local stats = {
		GamesPlayed = profile.Data.GamesPlayed or 0,
		GamesWon = profile.Data.GamesWon or 0,
		ZombiesKilled = profile.Data.ZombiesKilled or 0,
		PlantsPlaced = profile.Data.PlantsPlaced or 0,
	}
	local unlockedPlants = {}
	for plantType, _ in pairs(profile.Data.UnlockedPlants or {}) do
		table.insert(unlockedPlants, plantType)
	end
	local deck = profile.Data.Deck or { "Sunflower", "Peashooter", "WallNut" }

	Network.FullPlayerDataSync.Fire(player, {
		Coins = coins,
		Gems = gems,
		Level = level,
		XP = xp,
		TotalXPForNextLevel = xpForNext,
		GamesPlayed = stats.GamesPlayed,
		GamesWon = stats.GamesWon,
		ZombiesKilled = stats.ZombiesKilled,
		PlantsPlaced = stats.PlantsPlaced,
		UnlockedPlants = unlockedPlants,
		Deck = deck,
	})

	Logger.Debug("LobbyPlayerData", `Synced data to {player.Name}`)
end

-- Dispose: Clean up connections (called on server shutdown)
function PlayerDataService.Dispose()
	Logger.Info("LobbyPlayerData", "Disposing PlayerDataService...")
	_trove:Clean()
end

return PlayerDataService
