--!strict
--[[
	ProgressionLogic.luau - Pure logic for XP and Level progression
	
	Location: src/shared/handlers/player/
	
	Handles:
	- Adding XP
	- Level up calculations
	- Level progress percentage
	- Level rewards application
	
	This is a STATELESS module. It operates on ProfileData passed to it.
	Services (PlayerDataService) call these functions and handle persistence/networking.
	
	NOTE: Named "ProgressionLogic" to avoid confusion with 
	      arena/handlers/NetworkSyncHandler (which handles networking).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProfileTemplate = require(Shared.data.ProfileTemplate)
local ProgressionData = require(Shared.data.ProgressionData)

export type ProfileData = ProfileTemplate.ProfileData

-- Level reward that was applied
export type AppliedReward = {
	Level: number,
	Coins: number?,
	Gems: number?,
	UnlockPlant: string?,
}

-- Result of adding XP
export type XPResult = {
	LevelsGained: number,
	OldLevel: number,
	NewLevel: number,
	NewXP: number,
	Rewards: { AppliedReward },
}

local ProgressionLogic = {}

--------------------------------------------------------------------------------
-- XP / LEVEL CALCULATIONS
--------------------------------------------------------------------------------

--[[
	Calculate XP progress toward next level (0.0 - 1.0).
	@param data ProfileData - The player's profile data
	@return number - Progress percentage (0-1)
]]
function ProgressionLogic.GetLevelProgress(data: ProfileData): number
	if data.Level >= ProgressionData.MAX_LEVEL then
		return 1.0
	end

	local currentLevelTotalXP = ProgressionData.GetTotalXPForLevel(data.Level)
	local nextLevelTotalXP = ProgressionData.GetTotalXPForLevel(data.Level + 1)
	local xpInCurrentLevel = data.XP - currentLevelTotalXP
	local xpNeededForLevel = nextLevelTotalXP - currentLevelTotalXP

	if xpNeededForLevel <= 0 then
		return 1.0
	end

	return math.clamp(xpInCurrentLevel / xpNeededForLevel, 0, 1)
end

--[[
	Get XP required for a specific level.
	@param level number - Target level
	@return number - XP required
]]
function ProgressionLogic.GetXPForLevel(level: number): number
	return ProgressionData.GetXPForLevel(level)
end

--[[
	Get total cumulative XP to reach a level.
	@param level number - Target level
	@return number - Total XP
]]
function ProgressionLogic.GetTotalXPForLevel(level: number): number
	return ProgressionData.GetTotalXPForLevel(level)
end

--[[
	Get XP needed for next level from current level.
	@param currentLevel number - Current level
	@return number - XP needed
]]
function ProgressionLogic.GetXPForNextLevel(currentLevel: number): number
	return ProgressionData.GetXPForLevel(currentLevel + 1)
end

--------------------------------------------------------------------------------
-- XP ADDITION WITH LEVEL UP
--------------------------------------------------------------------------------

--[[
	Add XP to profile and process any level ups.
	Mutates the ProfileData directly.
	
	@param data ProfileData - The player's profile data (will be mutated)
	@param amount number - XP to add
	@return XPResult - Details about XP gain and level ups
]]
function ProgressionLogic.AddXP(data: ProfileData, amount: number): XPResult
	local oldLevel = data.Level
	local rewards: { AppliedReward } = {}

	-- Add XP
	data.XP += amount

	-- Check for level ups
	local levelsGained = 0
	while data.Level < ProgressionData.MAX_LEVEL do
		local xpNeeded = ProgressionData.GetXPForLevel(data.Level + 1)
		local currentLevelXP = data.XP - ProgressionData.GetTotalXPForLevel(data.Level)

		if currentLevelXP >= xpNeeded then
			data.Level += 1
			levelsGained += 1

			-- Apply level-up gems (always)
			data.Gems += ProgressionData.GEMS_PER_LEVEL_UP
			data.TotalGemsEarned += ProgressionData.GEMS_PER_LEVEL_UP

			-- Build reward entry
			local appliedReward: AppliedReward = {
				Level = data.Level,
				Gems = ProgressionData.GEMS_PER_LEVEL_UP,
			}

			-- Check for milestone rewards
			local milestone = ProgressionData.LevelRewards[data.Level]
			if milestone then
				if milestone.Coins then
					data.Coins += milestone.Coins
					data.TotalCoinsEarned += milestone.Coins
					appliedReward.Coins = milestone.Coins
				end
				if milestone.Gems then
					-- Additional gems on top of base level-up gems
					data.Gems += milestone.Gems
					data.TotalGemsEarned += milestone.Gems
					appliedReward.Gems = (appliedReward.Gems or 0) + milestone.Gems
				end
				if milestone.UnlockPlant then
					data.UnlockedPlants[milestone.UnlockPlant] = true
					appliedReward.UnlockPlant = milestone.UnlockPlant
				end
			end

			table.insert(rewards, appliedReward)
		else
			break
		end
	end

	return {
		LevelsGained = levelsGained,
		OldLevel = oldLevel,
		NewLevel = data.Level,
		NewXP = data.XP,
		Rewards = rewards,
	}
end

return ProgressionLogic
