--!strict
--[[
    GameSignals.luau - Centralized event signals for Arena client
    
    PURPOSE:
    Decouples Systems from UI/Modules using the Observer pattern.
    Systems FIRE signals, UI/Modules LISTEN via Trove:Connect().
    
    USAGE:
    -- Emitter (System or Network listener):
    GameSignals.OnWaveChanged:Fire({ WaveNumber = 1, MaxWaves = 10, IsPreparation = true })
    
    -- Consumer (UI Controller):
    _trove:Connect(GameSignals.OnWaveChanged, function(data)
        self:SetWaveNumber(data.WaveNumber)
    end)
    
    CATEGORIES:
    1. HUD Updates (Wave, Health, Resources)
    2. Battle Events (Start, End, Teleport)
    3. Combat Events (Damage, Death, Shoot, Impact)
    4. Economy Events (Coins, Sun)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Signal = require(Packages:WaitForChild("Signal"))

local GameSignals = {}

--------------------------------------------------------------------------------
-- HUD UPDATE SIGNALS
--------------------------------------------------------------------------------

--[[
    Fired when wave state changes.
    Payload: { WaveNumber: number, MaxWaves: number, IsPreparation: boolean }
]]
GameSignals.OnWaveChanged = Signal.new()

--[[
    Fired when base health changes.
    Payload: { Current: number, Max: number }
]]
GameSignals.OnBaseHealthChanged = Signal.new()

--[[
    Fired when sun count changes.
    Payload: { Amount: number }
]]
GameSignals.OnSunChanged = Signal.new()

--[[
    Fired when preparation time updates (client-side countdown).
    Payload: { TimeRemaining: number }
]]
GameSignals.OnPreparationTimeChanged = Signal.new()

--[[
    Fired when intermission time updates.
    Payload: { TimeRemaining: number }
]]
GameSignals.OnIntermissionTimeChanged = Signal.new()

--[[
    Fired when a wave is completed (triggers intermission).
    Payload: { WaveNumber: number, IntermissionDuration: number }
]]
GameSignals.OnWaveCompleted = Signal.new()

--------------------------------------------------------------------------------
-- BATTLE EVENT SIGNALS
--------------------------------------------------------------------------------

--[[
    Fired when battle ends (victory or defeat).
    Payload: { Victory: boolean, Stars: number, CoinsEarned: number, XPEarned: number, WorldId: string, Difficulty: string }
]]
GameSignals.OnBattleEnded = Signal.new()

--[[
    Fired during teleport countdown.
    Payload: { TimeRemaining: number }
]]
GameSignals.OnTeleportCountdown = Signal.new()

--------------------------------------------------------------------------------
-- COMBAT EVENT SIGNALS (VFX/Audio consumers)
--------------------------------------------------------------------------------

--[[
    Fired when damage is dealt to an entity.
    Payload: { Position: Vector3, Amount: number, IsCritical: boolean? }
]]
GameSignals.OnDamageDealt = Signal.new()

--[[
    Fired when a zombie dies.
    Payload: { Position: Vector3, ZombieType: string }
]]
GameSignals.OnZombieDeath = Signal.new()

--[[
    Fired when a plant shoots.
    Payload: { Position: Vector3, PlantType: string, IsFrozen: boolean? }
]]
GameSignals.OnPlantShoot = Signal.new()

--[[
    Fired when a plant dies.
    Payload: { Position: Vector3, PlantType: string }
]]
GameSignals.OnPlantDeath = Signal.new()

--[[
    Fired when a projectile impacts.
    Payload: { Position: Vector3, ProjectileType: string, IsFrozen: boolean? }
]]
GameSignals.OnProjectileImpact = Signal.new()

--[[
    Fired when an explosion occurs.
    Payload: { Position: Vector3, Radius: number }
]]
GameSignals.OnExplosion = Signal.new()

--[[
    Fired when slow effect is applied.
    Payload: { Position: Vector3 }
]]
GameSignals.OnSlowApplied = Signal.new()

--------------------------------------------------------------------------------
-- ECONOMY EVENT SIGNALS
--------------------------------------------------------------------------------

--[[
    Fired when coins are gained.
    Payload: { Amount: number, PositionX: number?, PositionZ: number? }
]]
GameSignals.OnCoinGained = Signal.new()

--[[
    Fired when sun is collected.
    Payload: { Position: Vector3, Amount: number }
]]
GameSignals.OnSunCollected = Signal.new()

--------------------------------------------------------------------------------
-- PLANT PLACEMENT SIGNALS
--------------------------------------------------------------------------------

--[[
    Fired when a plant is successfully placed.
    Payload: { Position: Vector3, PlantType: string }
]]
GameSignals.OnPlantPlaced = Signal.new()

return table.freeze(GameSignals)
