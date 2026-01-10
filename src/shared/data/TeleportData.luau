--!strict
--[[
    TeleportData.luau
    Structure for passing data between Lobby and Arena places via TeleportService
    
    Usage:
    - Lobby: TeleportService:Teleport(ARENA_PLACE_ID, player, teleportOptions)
    - Arena: TeleportService:GetLocalPlayerTeleportData()
    
    NEW SYSTEM (v2):
    - WorldId: Which map/world to play (reads from WorldData)
    - Difficulty: How hard the game is (reads from DifficultyData)
    - 100% DATA-DRIVEN: Add worlds/difficulties in their respective files only!
]]

-- Import data modules (single source of truth)
local WorldData = require(script.Parent.WorldData)
local DifficultyData = require(script.Parent.DifficultyData)

local TeleportData = {}

-- Place IDs (à configurer avec les vrais IDs après publication)
TeleportData.PlaceIds = {
    Lobby = 74774650768633,
    Arena = 105231625317605,
}

-- ============================================
-- NEW SYSTEM (v2): World + Difficulty
-- ============================================

-- Structure des données de téléportation Lobby → Arena
export type ArenaJoinData = {
    WorldId: string,           -- Any valid world from WorldData
    Difficulty: string,        -- Any valid difficulty from DifficultyData
    Deck: { string },          -- Liste des PlantTypes sélectionnés (max 6)
    EquippedMutations: { [string]: {string} }, -- [PlantType] -> {MutationType, ...}
    Timestamp: number,         -- os.time() pour validation timeout
}

-- Structure des données de téléportation Arena → Lobby (retour après match)
export type LobbyReturnData = {
    WorldId: string,           -- World qui vient d'être joué
    Difficulty: string,        -- Difficulté jouée
    Victory: boolean,          -- Résultat du match
    Stars: number,             -- Star rating (0-3)
    WavesSurvived: number,     -- Vagues survivées (pour les stats)
    CoinsEarned: number,       -- Coins gagnés durant le match
    XPEarned: number,          -- XP gagnée
    Timestamp: number,
}

-- Validation uses the data modules directly (no hardcoded lists!)
local function isValidWorld(worldId: string): boolean
    return WorldData.GetWorld(worldId) ~= nil
end

local function isValidDifficulty(difficultyId: string): boolean
    return DifficultyData.GetDifficulty(difficultyId) ~= nil
end

-- Valide les données de téléportation vers l'Arena
function TeleportData.ValidateArenaJoinData(data: any): (boolean, string?)
    if type(data) ~= "table" then
        return false, "TeleportData is not a table"
    end
    
    if type(data.WorldId) ~= "string" or not isValidWorld(data.WorldId) then
        return false, "Invalid WorldId"
    end
    
    if type(data.Difficulty) ~= "string" or not isValidDifficulty(data.Difficulty) then
        return false, "Invalid Difficulty"
    end
    
    if type(data.Deck) ~= "table" then
        return false, "Invalid Deck"
    end
    
    if #data.Deck < 1 or #data.Deck > 6 then
        return false, "Deck must have 1-6 plants"
    end
    
    for i = 1, #data.Deck do
        if type(data.Deck[i]) ~= "string" then
            return false, "Deck contains invalid plant type"
        end
    end
    
    if type(data.Timestamp) ~= "number" then
        return false, "Invalid Timestamp"
    end
    
    -- Timeout: données valides pendant 60 secondes max
    local MAX_AGE = 60
    if os.time() - data.Timestamp > MAX_AGE then
        return false, "TeleportData expired"
    end
    
    return true, nil
end

-- Valide les données de retour au Lobby
function TeleportData.ValidateLobbyReturnData(data: any): (boolean, string?)
    if type(data) ~= "table" then
        return false, "TeleportData is not a table"
    end
    
    if type(data.WorldId) ~= "string" then
        return false, "Invalid WorldId"
    end
    
    if type(data.Difficulty) ~= "string" then
        return false, "Invalid Difficulty"
    end
    
    if type(data.Victory) ~= "boolean" then
        return false, "Invalid Victory flag"
    end
    
    if type(data.WavesSurvived) ~= "number" or data.WavesSurvived < 0 then
        return false, "Invalid WavesSurvived count"
    end
    
    return true, nil
end

-- Crée les données de téléportation vers l'Arena
function TeleportData.CreateArenaJoinData(
    worldId: string,
    difficulty: string,
    deck: { string },
    equippedMutations: { [string]: {string} }?
): ArenaJoinData
    return {
        WorldId = worldId,
        Difficulty = difficulty,
        Deck = deck,
        EquippedMutations = equippedMutations or {},
        Timestamp = os.time(),
    }
end

-- Crée les données de retour au Lobby
function TeleportData.CreateLobbyReturnData(
    worldId: string,
    difficulty: string,
    victory: boolean,
    stars: number,
    wavesSurvived: number,
    coinsEarned: number,
    xpEarned: number
): LobbyReturnData
    return {
        WorldId = worldId,
        Difficulty = difficulty,
        Victory = victory,
        Stars = stars,
        WavesSurvived = wavesSurvived,
        CoinsEarned = coinsEarned,
        XPEarned = xpEarned,
        Timestamp = os.time(),
    }
end

return table.freeze(TeleportData)
