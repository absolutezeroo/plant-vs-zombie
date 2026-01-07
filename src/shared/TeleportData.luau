--!strict
--[[
    TeleportData.luau
    Structure for passing data between Lobby and Arena places via TeleportService
    
    Usage:
    - Lobby: TeleportService:Teleport(ARENA_PLACE_ID, player, teleportOptions)
    - Arena: TeleportService:GetLocalPlayerTeleportData()
]]

local TeleportData = {}

-- Place IDs (à configurer avec les vrais IDs après publication)
TeleportData.PlaceIds = {
    Lobby = 74774650768633,
    Arena = 89747004814506,
}

-- Structure des données de téléportation Lobby → Arena
export type ArenaJoinData = {
    StageId: string,           -- Ex: "1-1"
    Deck: { string },          -- Liste des PlantTypes sélectionnés (max 6)
    Timestamp: number,         -- os.time() pour validation timeout
}

-- Structure des données de téléportation Arena → Lobby (retour après match)
export type LobbyReturnData = {
    StageId: string,           -- Stage qui vient d'être joué
    Victory: boolean,          -- Résultat du match
    Stars: number,             -- Étoiles gagnées (0-3)
    CoinsEarned: number,       -- Coins gagnés durant le match
    XPEarned: number,          -- XP gagnée
    Timestamp: number,
}

-- Valide les données de téléportation vers l'Arena
function TeleportData.ValidateArenaJoinData(data: any): (boolean, string?)
    if type(data) ~= "table" then
        return false, "TeleportData is not a table"
    end
    
    if type(data.StageId) ~= "string" or data.StageId == "" then
        return false, "Invalid StageId"
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
    
    if type(data.StageId) ~= "string" then
        return false, "Invalid StageId"
    end
    
    if type(data.Victory) ~= "boolean" then
        return false, "Invalid Victory flag"
    end
    
    if type(data.Stars) ~= "number" or data.Stars < 0 or data.Stars > 3 then
        return false, "Invalid Stars count"
    end
    
    return true, nil
end

-- Crée les données de téléportation vers l'Arena
function TeleportData.CreateArenaJoinData(stageId: string, deck: { string }): ArenaJoinData
    return {
        StageId = stageId,
        Deck = deck,
        Timestamp = os.time(),
    }
end

-- Crée les données de retour au Lobby
function TeleportData.CreateLobbyReturnData(
    stageId: string,
    victory: boolean,
    stars: number,
    coinsEarned: number,
    xpEarned: number
): LobbyReturnData
    return {
        StageId = stageId,
        Victory = victory,
        Stars = stars,
        CoinsEarned = coinsEarned,
        XPEarned = xpEarned,
        Timestamp = os.time(),
    }
end

return table.freeze(TeleportData)
