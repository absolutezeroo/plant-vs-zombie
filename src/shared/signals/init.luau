--!strict
--[[
    signals/init.luau - Central export for all game signals
    
    USAGE:
    local Signals = require(Shared.signals)
    Signals.Game.OnWaveChanged:Fire(...)
    Signals.Lobby.OnPlayerDataSync:Fire(...)
]]

local GameSignals = require(script.GameSignals)
local LobbySignals = require(script.LobbySignals)

return table.freeze({
	Game = GameSignals,
	Lobby = LobbySignals,
})
