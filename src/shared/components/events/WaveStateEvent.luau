--!strict
--[[
    WaveStateEvent - Ephemeral event for wave state changes
    
    Fired when: Wave starts, ends, or phase changes
    Consumed by: UI systems (wave counter), Audio (wave start sound), VFX (flag zombie alert)
    Lifetime: One frame (cleaned by EventCleanupSystem)
    
    StateType values:
    - "Start": New wave beginning
    - "End": Wave completed (all zombies dead)
    - "Phase": Phase transition (Trickle -> Assault -> Flag)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Matter = require(Packages:WaitForChild("Matter"))

export type WaveStateEvent = {
    StateType: string,       -- "Start" | "End" | "Phase"
    WaveNumber: number,      -- Current wave number
    Phase: string?,          -- Current phase (for Phase events): "Trickle" | "Assault" | "Flag"
    TotalWaves: number?,     -- For UI display (e.g., "Wave 3/10")
}

return Matter.component("WaveStateEvent")
