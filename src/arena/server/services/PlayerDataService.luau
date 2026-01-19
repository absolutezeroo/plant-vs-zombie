--!strict
--[[
	PlayerDataService.luau - Persistent player data management (Arena)
	
	FACADE PATTERN: This service handles ONLY:
	- ProfileStore session management (Load/Save/Get)
	- Delegation to shared handlers for logic
	- Network event firing
	
	Game logic lives in:
	- shared/handlers/EconomyHandler (Coins/Gems)
	- shared/handlers/ProgressionLogic (XP/Level)
	- shared/handlers/InventoryHandler (Plants/Deck/Stats)
	
	Integrated with:
	- shared/data/ProfileTemplate (single source of truth)
	- shared/services/PlayerDataCore (shared utilities)
	- shared/services/TeleportDataHandler (teleport flow)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local ProfileStore = require(Packages:WaitForChild("ProfileStore"))
local Promise = require(Packages:WaitForChild("Promise"))
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.core.Logger)
local ProfileTemplate = require(Shared.data.ProfileTemplate) :: any
local PlayerDataCore = require(Shared.services.PlayerDataCore) :: any

-- Shared handlers (pure logic)
local EconomyHandler = require(Shared.handlers.player.EconomyHandler)
local ProgressionLogic = require(Shared.handlers.player.ProgressionLogic)
local InventoryHandler = require(Shared.handlers.player.InventoryHandler)

-- Network for XP/LevelUp events
local Network = require(Shared.network.generated.server)

-- Use shared profile template (single source of truth)
local PROFILE_TEMPLATE = ProfileTemplate.PROFILE_TEMPLATE

-- ProfileStore setup
local STORE_NAME = "PlayerData_v1"
local PlayerStore = ProfileStore.New(STORE_NAME, PROFILE_TEMPLATE)

-- Active profiles cache
local _profiles: { [Player]: any } = {}

-- Trove for cleanup
local _trove = Trove.new()

-- Player data change callbacks (using shared notifier)
local _dataChangeNotifier = PlayerDataCore.CreateDataChangeNotifier()

-- Profile waiter for WaitForProfile functionality
local _profileWaiter = PlayerDataCore.CreateProfileWaiter()

local PlayerDataService = {}

--------------------------------------------------------------------------------
-- PROFILE MANAGEMENT
--------------------------------------------------------------------------------

-- Get a player's profile data (or nil if not loaded)
function PlayerDataService.GetProfile(player: Player): typeof(PROFILE_TEMPLATE)?
	local profile = _profiles[player]
	if profile then
		return profile.Data
	end
	return nil
end

--[[
	Wait for a player's profile to load.
	Uses signal-based waiting (no polling).
	
	@param player The player to wait for
	@param timeout Maximum seconds to wait (default 10)
	@return ProfileData or nil if timeout/player left
]]
function PlayerDataService.WaitForProfile(player: Player, timeout: number?): any
	return _profileWaiter.WaitForProfile(player, PlayerDataService.GetProfile, timeout)
end

-- Register callback for data changes (returns unsubscribe function)
function PlayerDataService.OnDataChanged(callback: (player: Player, data: any) -> ()): () -> ()
	return _dataChangeNotifier.Subscribe(callback)
end

-- Notify all callbacks of data change
function PlayerDataService._notifyDataChanged(player: Player)
	local data = PlayerDataService.GetProfile(player)
	if data then
		_dataChangeNotifier.Notify(player, data)
	end
end

--------------------------------------------------------------------------------
-- COINS (delegates to EconomyHandler)
--------------------------------------------------------------------------------

function PlayerDataService.GetCoins(player: Player): number
	local data = PlayerDataService.GetProfile(player)
	return if data then data.Coins else 0
end

function PlayerDataService.AddCoins(player: Player, amount: number): boolean
	local data = PlayerDataService.GetProfile(player)
	if not data then
		return false
	end

	local result = EconomyHandler.AddCoins(data, amount)
	if result.Success then
		Logger.Debug("PlayerData", `{player.Name} +{amount} coins (Total: {result.NewAmount})`)
		PlayerDataService._notifyDataChanged(player)
	end

	return result.Success
end

function PlayerDataService.SpendCoins(player: Player, amount: number): boolean
	local data = PlayerDataService.GetProfile(player)
	if not data then
		return false
	end

	local result = EconomyHandler.SpendCoins(data, amount)
	if result.Success then
		Logger.Debug("PlayerData", `{player.Name} -{amount} coins (Remaining: {result.NewAmount})`)
		PlayerDataService._notifyDataChanged(player)
	end

	return result.Success
end

--------------------------------------------------------------------------------
-- GEMS (delegates to EconomyHandler)
--------------------------------------------------------------------------------

function PlayerDataService.GetGems(player: Player): number
	local data = PlayerDataService.GetProfile(player)
	return if data then data.Gems else 0
end

function PlayerDataService.AddGems(player: Player, amount: number): boolean
	local data = PlayerDataService.GetProfile(player)
	if not data then
		return false
	end

	local result = EconomyHandler.AddGems(data, amount)
	if result.Success then
		Logger.Info("PlayerData", `{player.Name} +{amount} gems (Total: {result.NewAmount})`)
		PlayerDataService._notifyDataChanged(player)
	end

	return result.Success
end

function PlayerDataService.SpendGems(player: Player, amount: number): boolean
	local data = PlayerDataService.GetProfile(player)
	if not data then
		return false
	end

	local result = EconomyHandler.SpendGems(data, amount)
	if result.Success then
		Logger.Debug("PlayerData", `{player.Name} -{amount} gems (Remaining: {result.NewAmount})`)
		PlayerDataService._notifyDataChanged(player)
	end

	return result.Success
end

--------------------------------------------------------------------------------
-- XP / LEVEL (delegates to ProgressionLogic)
--------------------------------------------------------------------------------

function PlayerDataService.GetXP(player: Player): number
	local data = PlayerDataService.GetProfile(player)
	return if data then data.XP else 0
end

function PlayerDataService.GetLevel(player: Player): number
	local data = PlayerDataService.GetProfile(player)
	return if data then data.Level else 1
end

function PlayerDataService.GetLevelProgress(player: Player): number
	local data = PlayerDataService.GetProfile(player)
	if not data then
		return 0
	end
	return ProgressionLogic.GetLevelProgress(data)
end

-- Add XP and handle level ups (returns levels gained)
function PlayerDataService.AddXP(player: Player, amount: number): number
	local data = PlayerDataService.GetProfile(player)
	if not data then
		return 0
	end

	local result = ProgressionLogic.AddXP(data, amount)

	if result.LevelsGained > 0 or amount > 0 then
		Logger.Debug("PlayerData", `{player.Name} +{amount} XP (Level {result.NewLevel}, Total: {result.NewXP})`)
		PlayerDataService._notifyDataChanged(player)

		-- Fire XPGained event to client
		Network.XPGained.Fire(player, {
			Amount = amount,
			TotalXP = result.NewXP,
			CurrentLevel = result.NewLevel,
			LevelProgress = ProgressionLogic.GetLevelProgress(data),
		})

		-- Fire LevelUp event for each level gained
		if result.LevelsGained > 0 then
			-- Get the last reward (for the final level reached)
			local lastReward = result.Rewards[#result.Rewards]

			Network.LevelUp.Fire(player, {
				NewLevel = result.NewLevel,
				RewardCoins = lastReward and lastReward.Coins,
				RewardGems = lastReward and lastReward.Gems,
				UnlockedPlant = lastReward and lastReward.UnlockPlant,
			})

			Logger.Info("PlayerData", `🎉 {player.Name} leveled up to {result.NewLevel}!`)

			-- Log all rewards
			for _, reward in result.Rewards do
				if reward.Coins then
					Logger.Info("PlayerData", `  Bonus: +{reward.Coins} coins`)
				end
				if reward.UnlockPlant then
					Logger.Info("PlayerData", `  Unlocked: {reward.UnlockPlant}!`)
				end
			end
		end
	end

	return result.LevelsGained
end

--------------------------------------------------------------------------------
-- PLANTS (delegates to InventoryHandler)
--------------------------------------------------------------------------------

function PlayerDataService.IsPlantUnlocked(player: Player, plantType: string): boolean
	local data = PlayerDataService.GetProfile(player)
	if not data then
		return false
	end
	return InventoryHandler.IsPlantUnlocked(data, plantType)
end

function PlayerDataService.GetUnlockedPlants(player: Player): { string }
	local data = PlayerDataService.GetProfile(player)
	if not data then
		return { "Sunflower", "Peashooter", "WallNut" }
	end
	return InventoryHandler.GetUnlockedPlants(data)
end

function PlayerDataService.UnlockPlant(player: Player, plantType: string): (boolean, string?)
	local data = PlayerDataService.GetProfile(player)
	if not data then
		return false, "Profile not loaded"
	end

	local result = InventoryHandler.PurchasePlant(data, plantType)
	if result.Success then
		Logger.Info("PlayerData", `{player.Name} unlocked {plantType}`)
		PlayerDataService._notifyDataChanged(player)
	end

	return result.Success, result.Error
end

--------------------------------------------------------------------------------
-- DECK (delegates to InventoryHandler)
--------------------------------------------------------------------------------

function PlayerDataService.GetDeck(player: Player): { string }
	local data = PlayerDataService.GetProfile(player)
	if not data then
		return { "Sunflower", "Peashooter", "WallNut" }
	end
	return InventoryHandler.GetDeck(data)
end

function PlayerDataService.SaveDeck(player: Player, deck: { string }): (boolean, string?)
	local data = PlayerDataService.GetProfile(player)
	if not data then
		return false, "Profile not loaded"
	end

	local result = InventoryHandler.SaveDeck(data, deck)
	if result.Success then
		Logger.Info("PlayerData", `{player.Name} saved deck: {table.concat(deck, ", ")}`)
		PlayerDataService._notifyDataChanged(player)
	end

	return result.Success, result.Error
end

--------------------------------------------------------------------------------
-- STATS (delegates to InventoryHandler)
--------------------------------------------------------------------------------

function PlayerDataService.IncrementStat(player: Player, statName: string, amount: number?)
	local data = PlayerDataService.GetProfile(player)
	if not data then
		return
	end

	InventoryHandler.IncrementStat(data, statName, amount)
end

--------------------------------------------------------------------------------
-- PROFILE LOADING (ProfileStore)
--------------------------------------------------------------------------------

--[[
	Load player profile with Promise-based async handling.
	Returns Promise<ProfileData> that resolves when profile is ready.
]]
local function loadProfile(player: Player)
	Logger.Info("PlayerData", `Loading profile for {player.Name}...`)

	return Promise.new(function(resolve, reject)
		local profile = PlayerStore:StartSessionAsync(`Player_{player.UserId}`, {
			Cancel = function()
				return player.Parent ~= Players
			end,
		})

		if not profile then
			reject(`Failed to load profile for {player.Name}`)
			return
		end

		profile:AddUserId(player.UserId)
		profile:Reconcile() -- Fill in missing fields from template

		profile.OnSessionEnd:Connect(function()
			_profiles[player] = nil
			if player.Parent == Players then
				player:Kick("Profile session ended. Please rejoin.")
			end
		end)

		if player.Parent ~= Players then
			profile:EndSession()
			reject("Player left during profile load")
			return
		end

		_profiles[player] = profile
		Logger.Info("PlayerData", `Profile loaded for {player.Name}: {profile.Data.Coins} coins`)

		-- Fire profile waiter callbacks (for WaitForProfile)
		_profileWaiter.FireCallbacks(player, profile.Data)

		-- Notify TeleportDataHandler that profile is ready
		local TeleportDataHandler = require(Shared.services.TeleportDataHandler)
		TeleportDataHandler.NotifyProfileLoaded(player, profile.Data)

		resolve(profile.Data)
	end):catch(function(err)
		Logger.Warn("PlayerData", `Profile load failed for {player.Name}: {err}`)
	end)
end

-- Unload player profile
local function unloadProfile(player: Player)
	local profile = _profiles[player]
	if profile then
		profile:EndSession()
		_profiles[player] = nil
		Logger.Info("PlayerData", `Profile saved for {player.Name}`)
	end

	-- Cleanup profile waiter
	_profileWaiter.Cleanup(player)
end

-- Initialize service
function PlayerDataService.Initialize()
	-- Handle existing players (for Studio hot-reload)
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end

	-- Handle new players
	_trove:Connect(Players.PlayerAdded, loadProfile)
	_trove:Connect(Players.PlayerRemoving, unloadProfile)

	-- Ensure profiles are saved on shutdown
	game:BindToClose(function()
		_trove:Destroy()
		for _, profile in _profiles do
			profile:EndSession()
		end
	end)

	Logger.Info("PlayerData", "PlayerDataService initialized")
end

return PlayerDataService
