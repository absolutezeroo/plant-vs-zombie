--!strict
--[[
	SunCollectionSystem.luau - Server-side sun collection processing
	
	Priority: 310 (After sun spawning)
	
	Handles sun collection requests from clients via Zap.
	Validates the sun entity exists and is collectible.
	Awards sun to player and despawns entity.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Components = require(Shared.components)
local Logger = require(Shared.utils.Logger)

-- Network (script.Parent.Parent.Parent = server root, since we're in systems/economy/)
local Server = script.Parent.Parent.Parent
local Network = require(Server.network.generated)

-- Components (via index module)
local PositionComponent = Components.PositionComponent
local SunComponent = Components.SunComponent

-- Collection queue (populated by network handler)
local _collectionQueue: {{Player: Player, EntityId: number, RequestId: number}} = {}

-- World reference (set during first system call)
local _world: any = nil

-- Lazy-load PlacementSystem to avoid circular dependency
local _placementAPI: any = nil
local function getPlacementAPI()
	if not _placementAPI then
		-- PlacementSystem is in systems/units/
		local Systems = script.Parent.Parent
		local PlacementSystem = require(Systems.units.PlacementSystem)
		_placementAPI = PlacementSystem.API
	end
	return _placementAPI
end

-- API
local SunCollectionAPI = {}

function SunCollectionAPI.QueueCollection(player: Player, entityId: number, requestId: number)
	table.insert(_collectionQueue, {
		Player = player,
		EntityId = entityId,
		RequestId = requestId
	})
end

-- Set up network handler
Network.CollectSunRequest.SetCallback(function(player: Player, data)
	SunCollectionAPI.QueueCollection(player, data.SunEntityId, data.RequestId)
end)

-- Validate collection and return sun value if valid
local function processCollection(world: any, player: Player, entityId: number): number?
	-- Check entity exists
	if not world:contains(entityId) then
		Logger.Warn("SunCollection", `Entity {entityId} does not exist`)
		return nil
	end
	
	-- Check entity has SunComponent
	local sun = world:get(entityId, SunComponent)
	if not sun then
		Logger.Warn("SunCollection", `Entity {entityId} is not a sun`)
		return nil
	end
	
	local value = sun.Value
	
	-- Despawn the sun
	world:despawn(entityId)
	
	Logger.Debug("SunCollection", `{player.Name} collected sun {entityId} worth {value}`)
	
	return value
end

local function SunCollectionSystem(world)
	_world = world
	
	-- Process collection queue
	for _, request in _collectionQueue do
		local value = processCollection(world, request.Player, request.EntityId)
		
		if value then
			-- Get current sun count
			local placementAPI = getPlacementAPI()
			placementAPI.AddSun(request.Player, value)
			local newTotal = placementAPI.GetPlayerSun(request.Player)
			
			-- Broadcast SunCollected to all clients
			Network.SunCollected.FireAll({
				SunEntityId = request.EntityId,
				CollectorId = request.Player.UserId,
				NewTotal = newTotal,
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
	table.clear(_collectionQueue)
end

return {
	system = SunCollectionSystem,
	priority = 310, -- After sun spawning
	API = SunCollectionAPI,
}
