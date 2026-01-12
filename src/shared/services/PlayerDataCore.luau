--!strict
--[[
    PlayerDataCore.luau - Shared utilities for PlayerDataService
    
    Contains:
    - Profile waiting system (callback-based)
    - Data change notification system
    - Common validation functions
    - Deck validation
    
    Used by both Lobby and Arena PlayerDataService implementations.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProfileTemplate = require(Shared.data.ProfileTemplate) :: any

local PlayerDataCore = {}

-- Re-export profile template for convenience
PlayerDataCore.PROFILE_TEMPLATE = ProfileTemplate.PROFILE_TEMPLATE
PlayerDataCore.ProfileTemplate = ProfileTemplate

-- Define ProfileData type inline (mirrors ProfileTemplate.ProfileData)
export type ProfileData = {
	Coins: number,
	TotalCoinsEarned: number,
	Gems: number,
	TotalGemsEarned: number,
	XP: number,
	Level: number,
	UnlockedPlants: { [string]: boolean },
	PlantOwnedMutations: { [string]: { string } },
	PlantEquippedMutations: { [string]: { string } },
	PlantMastery: { [string]: { Rank: number, XP: number } },
	Stats: {
		GamesPlayed: number,
		GamesWon: number,
		ZombiesKilled: number,
		PlantsPlaced: number,
	},
	Settings: {
		MusicVolume: number,
		SFXVolume: number,
	},
	Deck: { string },
}

--------------------------------------------------------------------------------
-- Profile Waiter System (Signal-based, no polling)
--------------------------------------------------------------------------------

export type ProfileWaiter = {
	RegisterCallback: (player: Player, callback: (ProfileData) -> ()) -> (),
	FireCallbacks: (player: Player, profile: ProfileData) -> (),
	Cleanup: (player: Player) -> (),
	WaitForProfile: (player: Player, getProfileFn: (Player) -> ProfileData?, timeout: number?) -> ProfileData?,
}

--[[
    Creates a new profile waiter instance.
    Each PlayerDataService should create its own waiter.
    
    Usage:
    ```lua
    local waiter = PlayerDataCore.CreateProfileWaiter()
    
    -- In LoadProfile, after profile loads:
    waiter:FireCallbacks(player, profile.Data)
    
    -- To wait for a profile:
    local data = waiter:WaitForProfile(player, PlayerDataService.GetProfile, 10)
    ```
]]
function PlayerDataCore.CreateProfileWaiter(): ProfileWaiter
	local callbacks: { [Player]: { (ProfileData) -> () } } = {}

	local waiter = {} :: ProfileWaiter

	-- Register a callback to be called when profile loads
	function waiter.RegisterCallback(player: Player, callback: (ProfileData) -> ())
		if not callbacks[player] then
			callbacks[player] = {}
		end
		table.insert(callbacks[player], callback)
	end

	-- Fire all callbacks for a player (called when profile loads)
	function waiter.FireCallbacks(player: Player, profile: ProfileData)
		local cbs = callbacks[player]
		if cbs then
			for _, cb in cbs do
				task.spawn(cb, profile)
			end
			callbacks[player] = nil
		end
	end

	-- Cleanup when player leaves
	function waiter.Cleanup(player: Player)
		callbacks[player] = nil
	end

	-- Wait for profile with timeout (returns profile data or nil)
	function waiter.WaitForProfile(
		player: Player,
		getProfileFn: (Player) -> ProfileData?,
		timeout: number?
	): ProfileData?
		-- Check if already loaded
		local existing = getProfileFn(player)
		if existing then
			return existing
		end

		local maxWait = timeout or 10
		local result: ProfileData? = nil
		local waiting = true

		-- Register callback
		waiter.RegisterCallback(player, function(profile)
			result = profile
			waiting = false
		end)

		-- Wait with timeout
		local elapsed = 0
		local Players = game:GetService("Players")

		while waiting and elapsed < maxWait and player.Parent == Players do
			task.wait(0.1)
			elapsed += 0.1

			-- Also check if profile loaded between callback and wait
			local check = getProfileFn(player)
			if check then
				result = check
				break
			end
		end

		return result
	end

	return waiter
end

--------------------------------------------------------------------------------
-- Data Change Notification System
--------------------------------------------------------------------------------

export type DataChangeNotifier = {
	Subscribe: (callback: (player: Player, data: ProfileData) -> ()) -> () -> (),
	Notify: (player: Player, data: ProfileData) -> (),
}

--[[
    Creates a data change notifier instance.
    
    Usage:
    ```lua
    local notifier = PlayerDataCore.CreateDataChangeNotifier()
    
    -- Subscribe to changes:
    local unsubscribe = notifier:Subscribe(function(player, data)
        print(player.Name, "data changed")
    end)
    
    -- Notify changes:
    notifier:Notify(player, profile.Data)
    
    -- Unsubscribe:
    unsubscribe()
    ```
]]
function PlayerDataCore.CreateDataChangeNotifier(): DataChangeNotifier
	local callbacks: { (player: Player, data: ProfileData) -> () } = {}

	local notifier = {} :: DataChangeNotifier

	-- Subscribe to data changes, returns unsubscribe function
	function notifier.Subscribe(callback: (player: Player, data: ProfileData) -> ()): () -> ()
		table.insert(callbacks, callback)

		return function()
			local index = table.find(callbacks, callback)
			if index then
				table.remove(callbacks, index)
			end
		end
	end

	-- Notify all subscribers of a data change
	function notifier.Notify(player: Player, data: ProfileData)
		for _, cb in callbacks do
			task.spawn(cb, player, data)
		end
	end

	return notifier
end

--------------------------------------------------------------------------------
-- Validation Functions
--------------------------------------------------------------------------------

--[[
    Validates a deck array against unlocked plants.
    Returns (isValid, cleanedDeck, errorMessage?)
]]
function PlayerDataCore.ValidateDeck(
	deck: { string },
	unlockedPlants: { [string]: boolean }
): (boolean, { string }, string?)
	if type(deck) ~= "table" then
		return false, {}, "Deck must be a table"
	end

	if #deck > ProfileTemplate.MAX_DECK_SIZE then
		return false, {}, `Deck cannot exceed {ProfileTemplate.MAX_DECK_SIZE} plants`
	end

	local cleanedDeck: { string } = {}
	local seen: { [string]: boolean } = {}

	for _, plantType in deck do
		if type(plantType) ~= "string" then
			return false, {}, "Deck entries must be strings"
		end

		if not unlockedPlants[plantType] then
			return false, {}, `Plant '{plantType}' is not unlocked`
		end

		if seen[plantType] then
			return false, {}, `Duplicate plant '{plantType}' in deck`
		end

		seen[plantType] = true
		table.insert(cleanedDeck, plantType)
	end

	return true, cleanedDeck, nil
end

--[[
    Validates mutations for a plant.
    Returns (isValid, errorMessage?)
]]
function PlayerDataCore.ValidateMutations(mutations: { string }, ownedMutations: { string }?): (boolean, string?)
	if type(mutations) ~= "table" then
		return false, "Mutations must be a table"
	end

	if #mutations > ProfileTemplate.MAX_MUTATIONS_PER_PLANT then
		return false, `Cannot equip more than {ProfileTemplate.MAX_MUTATIONS_PER_PLANT} mutations per plant`
	end

	if ownedMutations then
		for _, mutation in mutations do
			if not table.find(ownedMutations, mutation) then
				return false, `Mutation '{mutation}' is not owned`
			end
		end
	end

	return true, nil
end

--[[
    Checks if a plant type is a starter plant.
]]
function PlayerDataCore.IsStarterPlant(plantType: string): boolean
	return table.find(ProfileTemplate.STARTER_PLANTS, plantType) ~= nil
end

--[[
    Gets default stats object.
]]
function PlayerDataCore.GetDefaultStats()
	return {
		GamesPlayed = 0,
		GamesWon = 0,
		ZombiesKilled = 0,
		PlantsPlaced = 0,
	}
end

return PlayerDataCore
