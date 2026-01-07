--!strict
--[[
    LobbyConfig.luau - Configuration for physical lobby system
    
    Defines constants for teleport pads, countdown timers, and lobby behavior
]]

local LobbyConfig = {
    -- Teleport Pad Defaults
    DEFAULT_MIN_PLAYERS = 1,        -- Minimum players to start countdown
    DEFAULT_MAX_PLAYERS = 4,        -- Maximum players per match
    
    -- Countdown Settings
    COUNTDOWN_DURATION = 10,        -- Seconds before teleport
    INSTANT_TELEPORT_THRESHOLD = 4, -- If MaxPlayers reached, instant teleport
    
    -- Pad Detection
    PAD_CHECK_INTERVAL = 0.5,       -- How often to check players on pads (seconds)
    PAD_PLATFORM_TAG = "TeleportPad", -- CollectionService tag for pad platforms
    
    -- Deck Settings
    MIN_DECK_SIZE = 1,
    MAX_DECK_SIZE = 6,
    
    -- AFK Settings
    AFK_TIMEOUT = 30,               -- Kick from pad after 30 seconds of inactivity
    
    -- UI Update Rate
    UI_UPDATE_INTERVAL = 0.5,       -- Update BillboardGui every 0.5 seconds
}

return table.freeze(LobbyConfig)
