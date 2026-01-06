--!strict
--[[
	PlayerDataService.luau - Persistent player data management
	
	Uses ProfileStore for cross-session persistence.
	Manages: Coins, UnlockedPlants, Upgrades, Stats
	
	Server-side only. Clients receive replicated data via events.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local ProfileStore = require(Packages:WaitForChild("ProfileStore"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionData = require(Shared.data.ProgressionData)
local Logger = require(Shared.utils.Logger)

-- Profile template (default data for new players)
local PROFILE_TEMPLATE = {
	Coins = 0,
	TotalCoinsEarned = 0,
	Gems = 0,
	TotalGemsEarned = 0,
	
	-- XP and Level system
	XP = 0,
	Level = 1,
	
	-- Unlocked plants (starter plants are unlocked by default)
	UnlockedPlants = {
		Sunflower = true,
		Peashooter = true,
		WallNut = true,
	},
	
	-- Upgrade levels per plant (0 = no upgrade)
	PlantUpgrades = {
		-- [PlantType] = { Damage = 0, Health = 0, Cooldown = 0 }
	},
	
	-- Statistics
	Stats = {
		GamesPlayed = 0,
		GamesWon = 0,
		ZombiesKilled = 0,
		PlantsPlaced = 0,
	},
	
	-- Settings (for future use)
	Settings = {
		MusicVolume = 1.0,
		SFXVolume = 1.0,
	},
	
	-- Deck loadout (6 plant slots)
	Deck = {
		"Sunflower",
		"Peashooter",
		"WallNut",
		-- Slots 4-6 empty by default
	},
}

-- ProfileStore setup
local STORE_NAME = "PlayerData_v1"
local PlayerStore = ProfileStore.New(STORE_NAME, PROFILE_TEMPLATE)

-- Active profiles cache
local _profiles: {[Player]: any} = {}

-- Player data change callbacks
type DataChangeCallback = (player: Player, data: typeof(PROFILE_TEMPLATE)) -> ()
local _onDataChangedCallbacks: {DataChangeCallback} = {}

local PlayerDataService = {}

-- Get a player's profile (or nil if not loaded)
function PlayerDataService.GetProfile(player: Player): typeof(PROFILE_TEMPLATE)?
	local profile = _profiles[player]
	if profile then
		return profile.Data
	end
	return nil
end

-- Get coins for a player
function PlayerDataService.GetCoins(player: Player): number
	local data = PlayerDataService.GetProfile(player)
	return if data then data.Coins else 0
end

-- Add coins to a player
function PlayerDataService.AddCoins(player: Player, amount: number): boolean
	local profile = _profiles[player]
	if not profile then
		return false
	end
	
	profile.Data.Coins += amount
	profile.Data.TotalCoinsEarned += amount
	
	Logger.Debug("PlayerData", `{player.Name} +{amount} coins (Total: {profile.Data.Coins})`)
	PlayerDataService._notifyDataChanged(player)
	
	return true
end

-- Spend coins (returns false if not enough)
function PlayerDataService.SpendCoins(player: Player, amount: number): boolean
	local profile = _profiles[player]
	if not profile then
		return false
	end
	
	if profile.Data.Coins < amount then
		return false
	end
	
	profile.Data.Coins -= amount
	Logger.Debug("PlayerData", `{player.Name} -{amount} coins (Remaining: {profile.Data.Coins})`)
	PlayerDataService._notifyDataChanged(player)
	
	return true
end

-- ============================================
-- GEMS SYSTEM
-- ============================================

-- Get gems for a player
function PlayerDataService.GetGems(player: Player): number
	local data = PlayerDataService.GetProfile(player)
	return if data then data.Gems else 0
end

-- Add gems to a player
function PlayerDataService.AddGems(player: Player, amount: number): boolean
	local profile = _profiles[player]
	if not profile then
		return false
	end
	
	profile.Data.Gems += amount
	profile.Data.TotalGemsEarned += amount
	
	Logger.Info("PlayerData", `{player.Name} +{amount} gems (Total: {profile.Data.Gems})`)
	PlayerDataService._notifyDataChanged(player)
	
	return true
end

-- Spend gems (returns false if not enough)
function PlayerDataService.SpendGems(player: Player, amount: number): boolean
	local profile = _profiles[player]
	if not profile then
		return false
	end
	
	if profile.Data.Gems < amount then
		return false
	end
	
	profile.Data.Gems -= amount
	Logger.Debug("PlayerData", `{player.Name} -{amount} gems (Remaining: {profile.Data.Gems})`)
	PlayerDataService._notifyDataChanged(player)
	
	return true
end

-- ============================================
-- XP / LEVEL SYSTEM
-- ============================================

-- Get current XP and level
function PlayerDataService.GetXP(player: Player): number
	local data = PlayerDataService.GetProfile(player)
	return if data then data.XP else 0
end

function PlayerDataService.GetLevel(player: Player): number
	local data = PlayerDataService.GetProfile(player)
	return if data then data.Level else 1
end

-- Add XP and handle level ups (returns levels gained)
function PlayerDataService.AddXP(player: Player, amount: number): number
	local profile = _profiles[player]
	if not profile then
		return 0
	end
	
	local oldLevel = profile.Data.Level
	profile.Data.XP += amount
	
	-- Check for level ups
	local levelsGained = 0
	while profile.Data.Level < ProgressionData.MAX_LEVEL do
		local xpNeeded = ProgressionData.GetXPForLevel(profile.Data.Level + 1)
		local currentLevelXP = profile.Data.XP - ProgressionData.GetTotalXPForLevel(profile.Data.Level)
		
		if currentLevelXP >= xpNeeded then
			profile.Data.Level += 1
			levelsGained += 1
			
			Logger.Info("PlayerData", `🎉 {player.Name} leveled up to {profile.Data.Level}!`)
			
			-- Award level-up gems
			profile.Data.Gems += ProgressionData.GEMS_PER_LEVEL_UP
			profile.Data.TotalGemsEarned += ProgressionData.GEMS_PER_LEVEL_UP
			
			-- Check for milestone rewards
			local reward = ProgressionData.LevelRewards[profile.Data.Level]
			if reward then
				if reward.Coins then
					profile.Data.Coins += reward.Coins
					profile.Data.TotalCoinsEarned += reward.Coins
					Logger.Info("PlayerData", `  Bonus: +{reward.Coins} coins`)
				end
				if reward.Gems then
					profile.Data.Gems += reward.Gems
					profile.Data.TotalGemsEarned += reward.Gems
					Logger.Info("PlayerData", `  Bonus: +{reward.Gems} gems`)
				end
				if reward.UnlockPlant then
					profile.Data.UnlockedPlants[reward.UnlockPlant] = true
					Logger.Info("PlayerData", `  Unlocked: {reward.UnlockPlant}!`)
				end
			end
		else
			break
		end
	end
	
	if levelsGained > 0 or amount > 0 then
		Logger.Debug("PlayerData", `{player.Name} +{amount} XP (Level {profile.Data.Level}, Total: {profile.Data.XP})`)
		PlayerDataService._notifyDataChanged(player)
	end
	
	return levelsGained
end

-- Get XP progress to next level (0.0 - 1.0)
function PlayerDataService.GetLevelProgress(player: Player): number
	local data = PlayerDataService.GetProfile(player)
	if not data then
		return 0
	end
	
	if data.Level >= ProgressionData.MAX_LEVEL then
		return 1.0
	end
	
	local currentLevelTotalXP = ProgressionData.GetTotalXPForLevel(data.Level)
	local nextLevelTotalXP = ProgressionData.GetTotalXPForLevel(data.Level + 1)
	local xpInCurrentLevel = data.XP - currentLevelTotalXP
	local xpNeededForLevel = nextLevelTotalXP - currentLevelTotalXP
	
	return math.clamp(xpInCurrentLevel / xpNeededForLevel, 0, 1)
end

-- Check if plant is unlocked
function PlayerDataService.IsPlantUnlocked(player: Player, plantType: string): boolean
	local data = PlayerDataService.GetProfile(player)
	if not data then
		return false
	end
	return data.UnlockedPlants[plantType] == true
end

-- Get all unlocked plants
function PlayerDataService.GetUnlockedPlants(player: Player): {string}
	local data = PlayerDataService.GetProfile(player)
	if not data then
		return {"Sunflower", "Peashooter", "WallNut"} -- Default starters
	end
	
	local unlocked = {}
	for plantType, isUnlocked in data.UnlockedPlants do
		if isUnlocked then
			table.insert(unlocked, plantType)
		end
	end
	return unlocked
end

-- Unlock a plant (spend coins)
function PlayerDataService.UnlockPlant(player: Player, plantType: string): (boolean, string?)
	local profile = _profiles[player]
	if not profile then
		return false, "Profile not loaded"
	end
	
	-- Already unlocked?
	if profile.Data.UnlockedPlants[plantType] then
		return false, "Already unlocked"
	end
	
	-- Get cost
	local unlockInfo = ProgressionData.PlantUnlocks[plantType]
	if not unlockInfo then
		return false, "Unknown plant type"
	end
	
	-- Check coins
	if profile.Data.Coins < unlockInfo.Cost then
		return false, "Not enough coins"
	end
	
	-- Spend and unlock
	profile.Data.Coins -= unlockInfo.Cost
	profile.Data.UnlockedPlants[plantType] = true
	
	Logger.Info("PlayerData", `{player.Name} unlocked {plantType} for {unlockInfo.Cost} coins`)
	PlayerDataService._notifyDataChanged(player)
	
	return true, nil
end

-- Get upgrade level for a plant
function PlayerDataService.GetUpgradeLevel(player: Player, plantType: string, upgradeType: string): number
	local data = PlayerDataService.GetProfile(player)
	if not data then
		return 0
	end
	
	local plantUpgrades = data.PlantUpgrades[plantType]
	if not plantUpgrades then
		return 0
	end
	
	return plantUpgrades[upgradeType] or 0
end

-- Get all upgrade levels for a plant
function PlayerDataService.GetPlantUpgrades(player: Player, plantType: string): {Damage: number, Health: number, Cooldown: number}
	local data = PlayerDataService.GetProfile(player)
	local default = {Damage = 0, Health = 0, Cooldown = 0}
	
	if not data then
		return default
	end
	
	local plantUpgrades = data.PlantUpgrades[plantType]
	if not plantUpgrades then
		return default
	end
	
	return {
		Damage = plantUpgrades.Damage or 0,
		Health = plantUpgrades.Health or 0,
		Cooldown = plantUpgrades.Cooldown or 0,
	}
end

-- Purchase an upgrade
function PlayerDataService.PurchaseUpgrade(player: Player, plantType: string, upgradeType: string): (boolean, string?)
	local profile = _profiles[player]
	if not profile then
		return false, "Profile not loaded"
	end
	
	-- Plant must be unlocked
	if not profile.Data.UnlockedPlants[plantType] then
		return false, "Plant not unlocked"
	end
	
	-- Get upgrade info
	local upgradeInfo = ProgressionData.Upgrades[upgradeType]
	if not upgradeInfo then
		return false, "Unknown upgrade type"
	end
	
	-- Initialize plant upgrades if needed
	if not profile.Data.PlantUpgrades[plantType] then
		profile.Data.PlantUpgrades[plantType] = {Damage = 0, Health = 0, Cooldown = 0}
	end
	
	local currentLevel = profile.Data.PlantUpgrades[plantType][upgradeType] or 0
	
	-- Already max?
	if currentLevel >= upgradeInfo.MaxLevel then
		return false, "Already max level"
	end
	
	-- Get cost for next level
	local cost = upgradeInfo.CostPerLevel[currentLevel + 1]
	if not cost then
		return false, "Invalid upgrade level"
	end
	
	-- Check coins
	if profile.Data.Coins < cost then
		return false, "Not enough coins"
	end
	
	-- Purchase
	profile.Data.Coins -= cost
	profile.Data.PlantUpgrades[plantType][upgradeType] = currentLevel + 1
	
	Logger.Info("PlayerData", `{player.Name} upgraded {plantType} {upgradeType} to level {currentLevel + 1} for {cost} coins`)
	PlayerDataService._notifyDataChanged(player)
	
	return true, nil
end

-- ============================================
-- DECK SYSTEM
-- ============================================

-- Get player's current deck
function PlayerDataService.GetDeck(player: Player): {string}
	local data = PlayerDataService.GetProfile(player)
	if not data then
		return {"Sunflower", "Peashooter", "WallNut"} -- Default starters
	end
	return data.Deck or {"Sunflower", "Peashooter", "WallNut"}
end

-- Save player's deck (validates plants are unlocked)
function PlayerDataService.SaveDeck(player: Player, deck: {string}): (boolean, string?)
	local profile = _profiles[player]
	if not profile then
		return false, "Profile not loaded"
	end
	
	-- Validate deck size
	if #deck < 1 then
		return false, "Deck must have at least 1 plant"
	end
	
	if #deck > 6 then
		return false, "Deck cannot have more than 6 plants"
	end
	
	-- Validate all plants are unlocked
	for _, plantType in deck do
		if not profile.Data.UnlockedPlants[plantType] then
			return false, `Plant {plantType} is not unlocked`
		end
	end
	
	-- Check for duplicates
	local seen = {}
	for _, plantType in deck do
		if seen[plantType] then
			return false, `Duplicate plant: {plantType}`
		end
		seen[plantType] = true
	end
	
	-- Save deck
	profile.Data.Deck = deck
	Logger.Info("PlayerData", `{player.Name} saved deck: {table.concat(deck, ", ")}`)
	PlayerDataService._notifyDataChanged(player)
	
	return true, nil
end

-- ============================================
-- STATS
-- ============================================

-- Increment a stat
function PlayerDataService.IncrementStat(player: Player, statName: string, amount: number?)
	local profile = _profiles[player]
	if not profile then
		return
	end
	
	local currentValue = profile.Data.Stats[statName] or 0
	profile.Data.Stats[statName] = currentValue + (amount or 1)
end

-- Register callback for data changes
function PlayerDataService.OnDataChanged(callback: DataChangeCallback)
	table.insert(_onDataChangedCallbacks, callback)
end

-- Notify all callbacks of data change
function PlayerDataService._notifyDataChanged(player: Player)
	local data = PlayerDataService.GetProfile(player)
	if data then
		for _, callback in _onDataChangedCallbacks do
			task.spawn(callback, player, data)
		end
	end
end

-- Load player profile
local function loadProfile(player: Player)
	Logger.Info("PlayerData", `Loading profile for {player.Name}...`)
	
	local profile = PlayerStore:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	
	if profile then
		profile:AddUserId(player.UserId)
		profile:Reconcile() -- Fill in missing fields from template
		
		profile.OnSessionEnd:Connect(function()
			_profiles[player] = nil
			if player.Parent == Players then
				-- Kicked for session conflict
				player:Kick("Profile session ended. Please rejoin.")
			end
		end)
		
		if player.Parent == Players then
			_profiles[player] = profile
			Logger.Info("PlayerData", `Profile loaded for {player.Name}: {profile.Data.Coins} coins`)
			PlayerDataService._notifyDataChanged(player)
		else
			profile:EndSession()
		end
	else
		Logger.Warn("PlayerData", `Failed to load profile for {player.Name}`)
		-- In production, you might want to kick the player here
	end
end

-- Unload player profile
local function unloadProfile(player: Player)
	local profile = _profiles[player]
	if profile then
		profile:EndSession()
		_profiles[player] = nil
		Logger.Info("PlayerData", `Profile saved for {player.Name}`)
	end
end

-- Initialize service
function PlayerDataService.Initialize()
	-- Handle existing players (for Studio hot-reload)
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end
	
	-- Handle new players
	Players.PlayerAdded:Connect(loadProfile)
	Players.PlayerRemoving:Connect(unloadProfile)
	
	-- Ensure profiles are saved on shutdown
	game:BindToClose(function()
		for player, profile in _profiles do
			profile:EndSession()
		end
	end)
	
	Logger.Info("PlayerData", "PlayerDataService initialized")
end

return PlayerDataService
