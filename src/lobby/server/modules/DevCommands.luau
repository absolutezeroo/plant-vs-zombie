--!strict
--[[
    DevCommands.luau - Development/Admin Commands
    
    Provides commands for testing and development:
    - Give coins/gems
    - Set level
    - Unlock plants
    - Add mutations
    - Reset data
    
    SECURITY: Only works in Studio or for whitelisted UserIds
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.utils.Logger)
local PlantData = require(Shared.data.PlantData)
local MutationData = require(Shared.data.MutationData)

-- Import services
local PlayerDataService

-- Whitelisted UserIds (add your UserId here for production testing)
local WHITELISTED_USERS: {number} = {
    -- Add your Roblox UserId here for production testing
    -- Example: 12345678,
}

local DevCommands = {}

-- Check if player can use dev commands
local function canUseDevCommands(player: Player): boolean
    -- Always allow in Studio
    if RunService:IsStudio() then
        return true
    end
    
    -- Check whitelist for production
    for _, userId in WHITELISTED_USERS do
        if player.UserId == userId then
            return true
        end
    end
    
    return false
end

-- Command handlers
local CommandHandlers: {[string]: (player: Player, stringArg: string?, numberArg: number?) -> (boolean, string)} = {}

-- Give coins
CommandHandlers["GiveCoins"] = function(player, stringArg, numberArg)
    local amount = numberArg or 1000
    local profile = PlayerDataService.GetProfile(player)
    if not profile then
        return false, "Profile not loaded"
    end
    
    profile.Data.Coins = (profile.Data.Coins or 0) + amount
    Logger.Info("DevCommands", `Gave {amount} coins to {player.Name}`)
    return true, `+{amount} coins (total: {profile.Data.Coins})`
end

-- Give gems
CommandHandlers["GiveGems"] = function(player, stringArg, numberArg)
    local amount = numberArg or 100
    local profile = PlayerDataService.GetProfile(player)
    if not profile then
        return false, "Profile not loaded"
    end
    
    profile.Data.Gems = (profile.Data.Gems or 0) + amount
    Logger.Info("DevCommands", `Gave {amount} gems to {player.Name}`)
    return true, `+{amount} gems (total: {profile.Data.Gems})`
end

-- Set level
CommandHandlers["SetLevel"] = function(player, stringArg, numberArg)
    local level = numberArg or 10
    level = math.clamp(level, 1, 100)
    
    local profile = PlayerDataService.GetProfile(player)
    if not profile then
        return false, "Profile not loaded"
    end
    
    profile.Data.Level = level
    profile.Data.XP = 0
    Logger.Info("DevCommands", `Set {player.Name} level to {level}`)
    return true, `Level set to {level}`
end

-- Give XP
CommandHandlers["GiveXP"] = function(player, stringArg, numberArg)
    local amount = numberArg or 500
    local profile = PlayerDataService.GetProfile(player)
    if not profile then
        return false, "Profile not loaded"
    end
    
    profile.Data.XP = (profile.Data.XP or 0) + amount
    
    -- Level up logic
    local xpNeeded = profile.Data.TotalXPForNextLevel or 100
    while profile.Data.XP >= xpNeeded do
        profile.Data.XP = profile.Data.XP - xpNeeded
        profile.Data.Level = (profile.Data.Level or 1) + 1
        xpNeeded = 100 + (profile.Data.Level * 50) -- Increase XP requirement per level
        profile.Data.TotalXPForNextLevel = xpNeeded
    end
    
    Logger.Info("DevCommands", `Gave {amount} XP to {player.Name}, now level {profile.Data.Level}`)
    return true, `+{amount} XP (Level {profile.Data.Level})`
end

-- Unlock all plants
CommandHandlers["UnlockAllPlants"] = function(player, stringArg, numberArg)
    local profile = PlayerDataService.GetProfile(player)
    if not profile then
        return false, "Profile not loaded"
    end
    
    local count = 0
    for plantType, _ in PlantData do
        if not profile.Data.UnlockedPlants[plantType] then
            profile.Data.UnlockedPlants[plantType] = true
            count += 1
        end
    end
    
    Logger.Info("DevCommands", `Unlocked all plants for {player.Name} (+{count} new)`)
    return true, `Unlocked all plants (+{count} new)`
end

-- Unlock specific plant
CommandHandlers["UnlockPlant"] = function(player, stringArg, numberArg)
    local plantType = stringArg
    if not plantType then
        return false, "Plant type required"
    end
    
    if not PlantData[plantType] then
        return false, `Unknown plant: {plantType}`
    end
    
    local profile = PlayerDataService.GetProfile(player)
    if not profile then
        return false, "Profile not loaded"
    end
    
    if profile.Data.UnlockedPlants[plantType] then
        return false, `{plantType} already unlocked`
    end
    
    profile.Data.UnlockedPlants[plantType] = true
    Logger.Info("DevCommands", `Unlocked {plantType} for {player.Name}`)
    return true, `Unlocked {plantType}`
end

-- Add mutation to a plant
CommandHandlers["AddMutation"] = function(player, stringArg, numberArg)
    -- Format: "PlantType:MutationType" e.g. "Peashooter:Fire"
    if not stringArg then
        return false, "Format: PlantType:MutationType"
    end
    
    local parts = string.split(stringArg, ":")
    if #parts ~= 2 then
        return false, "Format: PlantType:MutationType"
    end
    
    local plantType = parts[1]
    local mutationType = parts[2]
    
    if not PlantData[plantType] then
        return false, `Unknown plant: {plantType}`
    end
    
    if not MutationData.Get(mutationType) then
        return false, `Unknown mutation: {mutationType}`
    end
    
    local profile = PlayerDataService.GetProfile(player)
    if not profile then
        return false, "Profile not loaded"
    end
    
    if not profile.Data.PlantOwnedMutations then
        profile.Data.PlantOwnedMutations = {}
    end
    if not profile.Data.PlantEquippedMutations then
        profile.Data.PlantEquippedMutations = {}
    end
    
    if not profile.Data.PlantOwnedMutations[plantType] then
        profile.Data.PlantOwnedMutations[plantType] = {}
    end
    if not profile.Data.PlantEquippedMutations[plantType] then
        profile.Data.PlantEquippedMutations[plantType] = {}
    end
    
    -- Check if already owns this mutation
    if table.find(profile.Data.PlantOwnedMutations[plantType], mutationType) then
        return false, `{plantType} already owns {mutationType}`
    end
    
    -- Add to both owned AND equipped
    table.insert(profile.Data.PlantOwnedMutations[plantType], mutationType)
    table.insert(profile.Data.PlantEquippedMutations[plantType], mutationType)
    Logger.Info("DevCommands", `Added {mutationType} to {plantType} for {player.Name} (owned + equipped)`)
    return true, `Added {mutationType} to {plantType}`
end

-- Max resources (coins, gems, level)
CommandHandlers["MaxResources"] = function(player, stringArg, numberArg)
    local profile = PlayerDataService.GetProfile(player)
    if not profile then
        return false, "Profile not loaded"
    end
    
    profile.Data.Coins = 999999
    profile.Data.Gems = 9999
    profile.Data.Level = 50
    profile.Data.XP = 0
    profile.Data.TotalXPForNextLevel = 100 + (50 * 50)
    
    Logger.Info("DevCommands", `Maxed resources for {player.Name}`)
    return true, "Max resources: 999999 coins, 9999 gems, level 50"
end

-- Reset all data
CommandHandlers["ResetData"] = function(player, stringArg, numberArg)
    local profile = PlayerDataService.GetProfile(player)
    if not profile then
        return false, "Profile not loaded"
    end
    
    -- Reset to defaults
    profile.Data.Coins = 500
    profile.Data.Gems = 50
    profile.Data.Level = 1
    profile.Data.XP = 0
    profile.Data.TotalXPForNextLevel = 100
    profile.Data.GamesPlayed = 0
    profile.Data.GamesWon = 0
    profile.Data.ZombiesKilled = 0
    profile.Data.PlantsPlaced = 0
    profile.Data.UnlockedPlants = {
        Sunflower = true,
        Peashooter = true,
        WallNut = true,
    }
    profile.Data.Deck = {"Sunflower", "Peashooter", "WallNut"}
    profile.Data.PlantOwnedMutations = {}
    profile.Data.PlantEquippedMutations = {}
    
    Logger.Info("DevCommands", `Reset all data for {player.Name}`)
    return true, "Data reset to defaults"
end

-- Handle dev command from client
function DevCommands.HandleCommand(player: Player, command: string, stringArg: string?, numberArg: number?): (boolean, string)
    -- Security check
    if not canUseDevCommands(player) then
        Logger.Warn("DevCommands", `{player.Name} tried to use dev commands but is not authorized`)
        return false, "Not authorized"
    end
    
    -- Debug: log available commands
    Logger.Info("DevCommands", `Looking for command: "{command}" (len={#command})`)
    local available = {}
    for cmd, _ in CommandHandlers do
        table.insert(available, cmd)
    end
    Logger.Info("DevCommands", `Available commands: {table.concat(available, ", ")}`)
    
    -- Find handler
    local handler = CommandHandlers[command]
    if not handler then
        return false, `Unknown command: {command}`
    end
    
    -- Execute command
    local success, message = handler(player, stringArg, numberArg)
    return success, message
end

-- Get list of available commands (for help)
function DevCommands.GetCommandList(): {string}
    local commands = {}
    for cmd, _ in CommandHandlers do
        table.insert(commands, cmd)
    end
    table.sort(commands)
    return commands
end

-- Initialize with PlayerDataService reference
function DevCommands.Initialize(playerDataServiceRef: any)
    PlayerDataService = playerDataServiceRef
    Logger.Info("DevCommands", "DevCommands initialized")
end

return DevCommands
