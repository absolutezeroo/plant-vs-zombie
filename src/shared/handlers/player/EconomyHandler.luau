--!strict
--[[
	EconomyHandler.luau - Pure logic for currency operations
	
	Location: src/shared/handlers/player/
	
	Handles:
	- Adding/Spending Coins
	- Adding/Spending Gems
	- Affordability checks
	
	This is a STATELESS module. It operates on ProfileData passed to it.
	Services (PlayerDataService) call these functions and handle persistence/networking.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProfileTemplate = require(Shared.data.ProfileTemplate)

export type ProfileData = ProfileTemplate.ProfileData

-- Result types for operations
export type CurrencyResult = {
	Success: boolean,
	NewAmount: number,
	Error: string?,
}

local EconomyHandler = {}

--------------------------------------------------------------------------------
-- COINS
--------------------------------------------------------------------------------

--[[
	Add coins to profile data.
	@param data ProfileData - The player's profile data (will be mutated)
	@param amount number - Amount to add (must be positive)
	@return CurrencyResult
]]
function EconomyHandler.AddCoins(data: ProfileData, amount: number): CurrencyResult
	if amount <= 0 then
		return {
			Success = false,
			NewAmount = data.Coins,
			Error = "AmountMustBePositive",
		}
	end

	data.Coins += amount
	data.TotalCoinsEarned += amount

	return {
		Success = true,
		NewAmount = data.Coins,
	}
end

--[[
	Spend coins from profile data.
	@param data ProfileData - The player's profile data (will be mutated)
	@param amount number - Amount to spend (must be positive)
	@return CurrencyResult
]]
function EconomyHandler.SpendCoins(data: ProfileData, amount: number): CurrencyResult
	if amount <= 0 then
		return {
			Success = false,
			NewAmount = data.Coins,
			Error = "AmountMustBePositive",
		}
	end

	if data.Coins < amount then
		return {
			Success = false,
			NewAmount = data.Coins,
			Error = "NotEnoughCoins",
		}
	end

	data.Coins -= amount

	return {
		Success = true,
		NewAmount = data.Coins,
	}
end

--[[
	Check if player can afford a coin cost.
	@param data ProfileData - The player's profile data
	@param amount number - Cost to check
	@return boolean
]]
function EconomyHandler.CanAffordCoins(data: ProfileData, amount: number): boolean
	return data.Coins >= amount
end

--------------------------------------------------------------------------------
-- GEMS
--------------------------------------------------------------------------------

--[[
	Add gems to profile data.
	@param data ProfileData - The player's profile data (will be mutated)
	@param amount number - Amount to add (must be positive)
	@return CurrencyResult
]]
function EconomyHandler.AddGems(data: ProfileData, amount: number): CurrencyResult
	if amount <= 0 then
		return {
			Success = false,
			NewAmount = data.Gems,
			Error = "AmountMustBePositive",
		}
	end

	data.Gems += amount
	data.TotalGemsEarned += amount

	return {
		Success = true,
		NewAmount = data.Gems,
	}
end

--[[
	Spend gems from profile data.
	@param data ProfileData - The player's profile data (will be mutated)
	@param amount number - Amount to spend (must be positive)
	@return CurrencyResult
]]
function EconomyHandler.SpendGems(data: ProfileData, amount: number): CurrencyResult
	if amount <= 0 then
		return {
			Success = false,
			NewAmount = data.Gems,
			Error = "AmountMustBePositive",
		}
	end

	if data.Gems < amount then
		return {
			Success = false,
			NewAmount = data.Gems,
			Error = "NotEnoughGems",
		}
	end

	data.Gems -= amount

	return {
		Success = true,
		NewAmount = data.Gems,
	}
end

--[[
	Check if player can afford a gem cost.
	@param data ProfileData - The player's profile data
	@param amount number - Cost to check
	@return boolean
]]
function EconomyHandler.CanAffordGems(data: ProfileData, amount: number): boolean
	return data.Gems >= amount
end

return EconomyHandler
