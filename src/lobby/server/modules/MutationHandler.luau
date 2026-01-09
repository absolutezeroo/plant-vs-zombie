--!strict
--[[
    MutationHandler.luau - Network handler for mutation system
    
    Handles:
    - PurchaseMutationRequest
    - EquipMutationRequest
    - UnequipMutationRequest
    - Syncing mutations on player join
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Trove = require(Packages:WaitForChild("Trove"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)

-- Network (unified Zap schema in shared/network)
local ZapServer = require(Shared.network.generated.server)

local script_parent = script.Parent.Parent
local PlayerDataService = require(script_parent.services.PlayerDataService)

local MutationHandler = {}

-- Trove for connection cleanup
local _trove = Trove.new()

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
    local allOwned = PlayerDataService.GetAllOwnedMutations(player)
    local allEquipped = PlayerDataService.GetAllEquippedMutations(player)
    
    -- Build arrays of plant-mutation pairs for owned
    local ownedArray = {}
    for plantType, mutations in allOwned do
        if #mutations > 0 then
            table.insert(ownedArray, {
                PlantType = plantType,
                Mutations = mutations,
            })
        end
    end
    
    -- Build arrays for equipped
    local equippedArray = {}
    for plantType, mutations in allEquipped do
        if #mutations > 0 then
            table.insert(equippedArray, {
                PlantType = plantType,
                Mutations = mutations,
            })
        end
    end
    
    -- Send all mutations at once
    ZapServer.SyncAllMutations.Fire(player, {
        OwnedMutations = ownedArray,
        EquippedMutations = equippedArray,
    })
    Logger.Info("MutationHandler", `Synced mutations to {player.Name}: {#ownedArray} owned, {#equippedArray} equipped`)
end

-- Sync single plant mutations
function MutationHandler.SyncPlantMutations(player: Player, plantType: string)
    local owned = PlayerDataService.GetOwnedMutations(player, plantType)
    local equipped = PlayerDataService.GetEquippedMutations(player, plantType)
    
    ZapServer.SyncPlantMutations.Fire(player, {
        PlantType = plantType,
        OwnedMutations = owned,
        EquippedMutations = equipped,
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
    
    -- Handle equip mutation request
    ZapServer.EquipMutationRequest.SetCallback(function(player, data)
        local plantType = data.PlantType
        local mutationType = data.MutationType
        
        Logger.Info("MutationHandler", `{player.Name} equipping {mutationType} on {plantType}`)
        
        local success, errorMsg = PlayerDataService.EquipMutation(player, plantType, mutationType)
        
        local errorCode = 0
        if not success and errorMsg then
            local mapping = {
                NotOwned = 1,
                AlreadyEquipped = 2,
                Incompatible = 3,
            }
            errorCode = mapping[errorMsg] or 0
        end
        
        ZapServer.EquipMutationResponse.Fire(player, {
            Success = success,
            PlantType = plantType,
            MutationType = mutationType,
            ErrorCode = if success then nil else errorCode,
        })
        
        if success then
            MutationHandler.SyncPlantMutations(player, plantType)
        end
    end)
    
    -- Handle unequip mutation request
    ZapServer.UnequipMutationRequest.SetCallback(function(player, data)
        local plantType = data.PlantType
        local mutationType = data.MutationType
        
        Logger.Info("MutationHandler", `{player.Name} unequipping {mutationType} from {plantType}`)
        
        local success = PlayerDataService.UnequipMutation(player, plantType, mutationType)
        
        ZapServer.UnequipMutationResponse.Fire(player, {
            Success = success,
            PlantType = plantType,
            MutationType = mutationType,
        })
        
        if success then
            MutationHandler.SyncPlantMutations(player, plantType)
        end
    end)
    
    -- Sync mutations when player data loads
    _trove:Connect(Players.PlayerAdded, function(player)
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
