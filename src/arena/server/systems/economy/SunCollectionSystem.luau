--!strict
--[[
	SunCollectionSystem.luau - Server-side sun collection processing
	
	Priority: 310 (After sun spawning)
	
	Handles sun collection requests from clients via Zap.
	Validates the sun entity exists and is collectible.
	Awards sun to player via SunService and despawns entity.
	
	V3 Architecture: Matter Hooks pattern
]]

-- ============================================================
-- SECTION 1: IMPORTS
-- ============================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Hooks = require(Packages.MatterHooks)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local Logger = require(Shared.utils.core.Logger)
local EntityPool = require(Shared.utils.ecs.EntityPool)

-- Network
local Network = require(Shared.network.generated.server)

-- Server services
local Server = script.Parent.Parent.Parent
local SunService = require(Server.services.SunService)
local ServerEventBus = require(Server.services.ServerEventBus)

-- ============================================================
-- SECTION 2: CONFIG (immutable settings)
-- ============================================================
local CONFIG = table.freeze({
	PRIORITY = 310,
})

-- ============================================================
-- SECTION 3: TYPES
-- ============================================================
type CollectionRequest = { Player: Player, EntityId: number, RequestId: number }
type CollectionState = {
	CollectionQueue: { CollectionRequest },
}

-- ============================================================
-- SECTION 4: PRIVATE HELPERS
-- ============================================================

-- Queue a collection request (called by network handler)
local function queueCollection(state: { value: CollectionState }, player: Player, entityId: number, requestId: number)
	table.insert(state.value.CollectionQueue, {
		Player = player,
		EntityId = entityId,
		RequestId = requestId,
	})
end

-- Validate collection and return sun value if valid
local function processCollection(world: any, player: Player, entityId: number): number?
	-- Check entity exists
	if not world:contains(entityId) then
		Logger.Warn("SunCollection", `Entity {entityId} does not exist`)
		return nil
	end

	-- Check entity has SunComponent
	local sun = world:get(entityId, Components.SunComponent)
	if not sun then
		Logger.Warn("SunCollection", `Entity {entityId} is not a sun`)
		return nil
	end

	-- Check ownership: if sun has an owner, only that player can collect it
	if sun.OwnerId and sun.OwnerId ~= player.UserId then
		Logger.Debug("SunCollection", `{player.Name} cannot collect sun {entityId} - belongs to another player`)
		return nil
	end

	local value = sun.Value

	-- Release sun back to pool
	EntityPool.SafeDespawn(entityId, world)

	Logger.Debug("SunCollection", `{player.Name} collected sun {entityId} worth {value}`)

	return value
end

-- ============================================================
-- SECTION 5: SYSTEM FUNCTION
-- ============================================================
local function SunCollectionSystem(world)
	-- State managed via Hooks.useMap
	local state = Hooks.useMap("SunCollectionState", {
		CollectionQueue = {} :: { CollectionRequest },
	})

	-- Set up network handler once via useMemo
	Hooks.useMemo(function()
		Network.CollectSunRequest.SetCallback(function(player: Player, data)
			queueCollection(state, player, data.SunEntityId, data.RequestId)
		end)
		Logger.Debug("SunCollectionSystem", "Network handler initialized")
		return true
	end, {})

	-- Process collection queue
	for _, request in state.value.CollectionQueue do
		local value = processCollection(world, request.Player, request.EntityId)

		if value then
			-- Add sun via SunService
			SunService.AddSun(request.Player, value)
			local newTotal = SunService.GetSun(request.Player)

			-- Broadcast SunCollected to all clients
			Network.SunCollected.FireAll({
				SunEntityId = request.EntityId,
				CollectorId = request.Player.UserId,
				NewTotal = newTotal,
			})

			-- Fire ServerEventBus event for analytics/achievements
			ServerEventBus.FireSunCollected({
				Player = request.Player,
				Amount = value,
				SourceType = "Unknown", -- TODO: Determine source from SunComponent
				Total = newTotal,
			})

			-- Send success response
			Network.RequestResponse.Fire(request.Player, {
				RequestId = request.RequestId,
				Success = true,
				ErrorCode = nil,
			})
		else
			-- Send failure response
			Network.RequestResponse.Fire(request.Player, {
				RequestId = request.RequestId,
				Success = false,
				ErrorCode = 0, -- Generic error
			})
		end
	end

	-- Clear queue
	table.clear(state.value.CollectionQueue)
end

-- ============================================================
-- SECTION 6: MODULE EXPORT
-- ============================================================
return {
	priority = CONFIG.PRIORITY,
	system = SunCollectionSystem,
}
