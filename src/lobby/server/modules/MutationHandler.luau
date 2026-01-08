--!strict
--[[
    MutationHandler.luau - Network handler for mutation system
    
    Handles:
    - PurchaseMutationRequest
    - RemoveMutationRequest
    - Syncing mutations on player join
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local MutationData = require(Shared.data.MutationData)

local script_parent = script.Parent.Parent
local PlayerDataService = require(script_parent.services.PlayerDataService)
local ZapServer = require(script_parent.network.generated)

local MutationHandler = {}

-- Error codes for responses
local ErrorCodes = {
    None = 0,
    AlreadyHas = 1,
    NotEnoughCoins = 2,
    InvalidMutation = 3,
    Incompatible = 4,
    LevelTooLow = 5,
    PlantNotUnlocked = 6,
}

-- Convert error string to code
local function errorToCode(errorStr: string?): number
    if not errorStr then return ErrorCodes.None end
    
    local mapping: {[string]: number} = {
        AlreadyHas = ErrorCodes.AlreadyHas,
        NotEnoughCoins = ErrorCodes.NotEnoughCoins,
        InvalidMutation = ErrorCodes.InvalidMutation,
        Incompatible = ErrorCodes.Incompatible,
        LevelTooLow = ErrorCodes.LevelTooLow,
        PlantNotUnlocked = ErrorCodes.PlantNotUnlocked,
    }
    
    return mapping[errorStr] or ErrorCodes.InvalidMutation
end

-- Sync all mutations to a player
function MutationHandler.SyncMutationsToPlayer(player: Player)
    local allMutations = PlayerDataService.GetAllPlantMutations(player)
    
    -- Build array of plant-mutation pairs
    local plantMutationsArray = {}
    for plantType, mutations in allMutations do
        if #mutations > 0 then
            table.insert(plantMutationsArray, {
                PlantType = plantType,
                Mutations = mutations,
            })
        end
    end
    
    -- Send all mutations at once
    if #plantMutationsArray > 0 then
        ZapServer.SyncAllMutations.Fire(player, {
            PlantMutations = plantMutationsArray,
        })
        Logger.Info("MutationHandler", `Synced {#plantMutationsArray} plant mutations to {player.Name}`)
    end
end

-- Sync single plant mutations
function MutationHandler.SyncPlantMutations(player: Player, plantType: string)
    local mutations = PlayerDataService.GetPlantMutations(player, plantType)
    
    ZapServer.SyncPlantMutations.Fire(player, {
        PlantType = plantType,
        Mutations = mutations,
    })
end

function MutationHandler.Initialize()
    Logger.Info("MutationHandler", "Initializing mutation network handlers")
    
    -- Handle purchase mutation request
    ZapServer.PurchaseMutationRequest.SetCallback(function(player, data)
        local plantType = data.PlantType
        local mutationType = data.MutationType
        
        Logger.Info("MutationHandler", `{player.Name} requesting {mutationType} for {plantType}`)
        
        local success, errorMsg, newCoins = PlayerDataService.PurchaseMutation(player, plantType, mutationType)
        
        ZapServer.PurchaseMutationResponse.Fire(player, {
            Success = success,
            PlantType = plantType,
            MutationType = mutationType,
            ErrorCode = if success then nil else errorToCode(errorMsg),
            NewCoins = newCoins,
        })
        
        -- Sync updated mutations if successful
        if success then
            MutationHandler.SyncPlantMutations(player, plantType)
        end
    end)
    
    -- Handle remove mutation request
    ZapServer.RemoveMutationRequest.SetCallback(function(player, data)
        local plantType = data.PlantType
        local mutationType = data.MutationType
        
        Logger.Info("MutationHandler", `{player.Name} removing {mutationType} from {plantType}`)
        
        local success = PlayerDataService.RemoveMutation(player, plantType, mutationType)
        
        ZapServer.RemoveMutationResponse.Fire(player, {
            Success = success,
            PlantType = plantType,
            MutationType = mutationType,
        })
        
        -- Sync updated mutations if successful
        if success then
            MutationHandler.SyncPlantMutations(player, plantType)
        end
    end)
    
    -- Sync mutations when player data loads
    Players.PlayerAdded:Connect(function(player)
        -- Wait a bit for profile to load
        task.delay(1, function()
            if player.Parent then
                MutationHandler.SyncMutationsToPlayer(player)
            end
        end)
    end)
    
    -- Sync to existing players (Studio testing)
    task.delay(1, function()
        for _, player in Players:GetPlayers() do
            MutationHandler.SyncMutationsToPlayer(player)
        end
    end)
    
    Logger.Info("MutationHandler", "Mutation handlers initialized")
end

return MutationHandler
