--!strict
--[[
	InventoryHandler.luau - Pure logic for plant/deck inventory operations
	
	Location: src/shared/handlers/player/
	
	Handles:
	- Plant ownership checks
	- Plant unlocking (free unlock)
	- Plant purchasing (with coin cost)
	- Deck validation and saving
	
	This is a STATELESS module. It operates on ProfileData passed to it.
	Services (PlayerDataService) call these functions and handle persistence/networking.
	
	NOTE: Mutation operations are handled separately in MutationHandler 
	      (lobby only, more complex logic with MutationData).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProfileTemplate = require(Shared.data.ProfileTemplate)
local ProgressionData = require(Shared.data.ProgressionData)

export type ProfileData = ProfileTemplate.ProfileData

-- Default starter plants
local STARTER_PLANTS = { "Sunflower", "Peashooter", "WallNut" }
local MAX_DECK_SIZE = 6

-- Result types
export type UnlockResult = {
	Success: boolean,
	Error: string?,
}

export type PurchaseResult = {
	Success: boolean,
	Error: string?,
	NewCoins: number?,
}

export type DeckResult = {
	Success: boolean,
	Error: string?,
}

local InventoryHandler = {}

--------------------------------------------------------------------------------
-- PLANT OWNERSHIP
--------------------------------------------------------------------------------

--[[
	Check if a plant is unlocked.
	@param data ProfileData - The player's profile data
	@param plantType string - Plant type to check
	@return boolean
]]
function InventoryHandler.IsPlantUnlocked(data: ProfileData, plantType: string): boolean
	return data.UnlockedPlants[plantType] == true
end

--[[
	Get list of all unlocked plants.
	@param data ProfileData - The player's profile data
	@return {string} - List of unlocked plant types
]]
function InventoryHandler.GetUnlockedPlants(data: ProfileData): { string }
	local plants = {}
	for plantType, isUnlocked in data.UnlockedPlants do
		if isUnlocked then
			table.insert(plants, plantType)
		end
	end
	return plants
end

--[[
	Unlock a plant for free (e.g., from level reward).
	@param data ProfileData - The player's profile data (will be mutated)
	@param plantType string - Plant type to unlock
	@return UnlockResult
]]
function InventoryHandler.UnlockPlant(data: ProfileData, plantType: string): UnlockResult
	-- Already unlocked?
	if data.UnlockedPlants[plantType] then
		return {
			Success = false,
			Error = "AlreadyUnlocked",
		}
	end

	-- Unlock it
	data.UnlockedPlants[plantType] = true

	return {
		Success = true,
	}
end

--[[
	Purchase a plant with coins.
	Uses cost from ProgressionData.PlantUnlocks.
	
	@param data ProfileData - The player's profile data (will be mutated)
	@param plantType string - Plant type to purchase
	@return PurchaseResult
]]
function InventoryHandler.PurchasePlant(data: ProfileData, plantType: string): PurchaseResult
	-- Already unlocked?
	if data.UnlockedPlants[plantType] then
		return {
			Success = false,
			Error = "AlreadyUnlocked",
		}
	end

	-- Get unlock info
	local unlockInfo = ProgressionData.PlantUnlocks[plantType]
	if not unlockInfo then
		return {
			Success = false,
			Error = "UnknownPlantType",
		}
	end

	-- Check cost
	local cost = unlockInfo.Cost
	if data.Coins < cost then
		return {
			Success = false,
			Error = "NotEnoughCoins",
		}
	end

	-- Deduct and unlock
	data.Coins -= cost
	data.UnlockedPlants[plantType] = true

	return {
		Success = true,
		NewCoins = data.Coins,
	}
end

--------------------------------------------------------------------------------
-- DECK MANAGEMENT
--------------------------------------------------------------------------------

--[[
	Get the player's current deck.
	@param data ProfileData - The player's profile data
	@return {string} - List of plant types in deck
]]
function InventoryHandler.GetDeck(data: ProfileData): { string }
	if data.Deck and #data.Deck > 0 then
		return data.Deck
	end
	-- Return default starters if no deck set
	return STARTER_PLANTS
end

--[[
	Validate a deck (checks ownership, size, duplicates).
	@param data ProfileData - The player's profile data
	@param deck {string} - Proposed deck
	@return DeckResult
]]
function InventoryHandler.ValidateDeck(data: ProfileData, deck: { string }): DeckResult
	-- Check size
	if #deck < 1 then
		return {
			Success = false,
			Error = "DeckTooSmall",
		}
	end

	if #deck > MAX_DECK_SIZE then
		return {
			Success = false,
			Error = "DeckTooLarge",
		}
	end

	-- Check for duplicates and ownership
	local seen: { [string]: boolean } = {}
	for _, plantType in deck do
		-- Duplicate check
		if seen[plantType] then
			return {
				Success = false,
				Error = `DuplicatePlant:{plantType}`,
			}
		end
		seen[plantType] = true

		-- Ownership check
		if not data.UnlockedPlants[plantType] then
			return {
				Success = false,
				Error = `PlantNotUnlocked:{plantType}`,
			}
		end
	end

	return {
		Success = true,
	}
end

--[[
	Save a deck after validation.
	@param data ProfileData - The player's profile data (will be mutated)
	@param deck {string} - Deck to save
	@return DeckResult
]]
function InventoryHandler.SaveDeck(data: ProfileData, deck: { string }): DeckResult
	-- Validate first
	local validation = InventoryHandler.ValidateDeck(data, deck)
	if not validation.Success then
		return validation
	end

	-- Save
	data.Deck = deck

	return {
		Success = true,
	}
end

--------------------------------------------------------------------------------
-- STATS
--------------------------------------------------------------------------------

--[[
	Increment a stat by amount.
	@param data ProfileData - The player's profile data (will be mutated)
	@param statName string - Stat key to increment
	@param amount number? - Amount to add (default 1)
]]
function InventoryHandler.IncrementStat(data: ProfileData, statName: string, amount: number?)
	local stats = data.Stats :: { [string]: number }
	local current = stats[statName] or 0
	stats[statName] = current + (amount or 1)
end

return InventoryHandler
