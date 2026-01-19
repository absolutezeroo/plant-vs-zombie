--!strict
--[[
	MutationService.luau - Manages player mutation cache
	
	Centralized service for player mutation data.
	Used by MutationApplySystem and TeleportDataHandler.
	
	API:
	- LoadPlayerMutations(userId, mutations) - Load mutations from teleport data
	- ClearPlayerMutations(userId) - Clear on leave
	- GetPlayerMutations(userId) - Get all mutations for player
	- GetPlantMutations(userId, plantType) - Get mutations for specific plant
	
	LIFECYCLE:
	- Service is stateful singleton, no special init needed
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.core.Logger)

-- ============================================================
-- SECTION 2: STATE (all mutable data)
-- ============================================================
local State = {
	-- [UserId] -> [PlantType] -> {mutations}
	PlayerMutationsCache = {} :: { [number]: { [string]: { string } } },
}

-- ============================================================
-- SECTION 3: PUBLIC API
-- ============================================================
local MutationService = {}

--[[
	Load player mutations into cache
	Called by TeleportDataHandler when player arrives in arena
	@param userId number
	@param mutations {[string]: {string}} - PlantType -> {MutationIds}
]]
function MutationService.LoadPlayerMutations(userId: number, mutations: { [string]: { string } })
	State.PlayerMutationsCache[userId] = mutations
	Logger.Info("MutationService", `Loaded mutations for user {userId}`)
end

--[[
	Clear player mutations on leave
	@param userId number
]]
function MutationService.ClearPlayerMutations(userId: number)
	State.PlayerMutationsCache[userId] = nil
end

--[[
	Get all mutations for a player (all plants)
	@param userId number
	@return {[string]: {string}} - PlantType -> {MutationIds}
]]
function MutationService.GetPlayerMutations(userId: number): { [string]: { string } }
	return State.PlayerMutationsCache[userId] or {}
end

--[[
	Get mutations for a specific plant
	@param userId number
	@param plantType string
	@return {string} - Array of mutation IDs
]]
function MutationService.GetPlantMutations(userId: number, plantType: string): { string }
	local playerMutations = State.PlayerMutationsCache[userId]
	if not playerMutations then
		return {}
	end
	return playerMutations[plantType] or {}
end

--[[
	Load mutations from player profile (for Studio debug mode)
	@param player Player
	@param profileData table - The player's profile data
]]
function MutationService.LoadMutationsFromProfile(player: Player, profileData: any)
	local equippedMutations = profileData.PlantEquippedMutations or {}
	State.PlayerMutationsCache[player.UserId] = equippedMutations

	local count = 0
	for _ in equippedMutations do
		count = count + 1
	end
	Logger.Info("MutationService", `Loaded {count} plant mutations from profile for {player.Name}`)
end

--[[
	Dispose of service resources
	Called when arena match ends
]]
function MutationService.Dispose()
	table.clear(State.PlayerMutationsCache)
	Logger.Debug("MutationService", "Disposed")
end

-- ============================================================
-- SECTION 4: MODULE EXPORT
-- ============================================================
return MutationService
