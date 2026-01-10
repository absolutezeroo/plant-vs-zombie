# 📐 Standard Architecture: ECS System V2.0

**Version:** 2.0
**Scope:** All scripts in `src/arena/server/systems/`
**Goal:** Enforce structural uniformity, isolate state, and enable Hot-Reloading.

---

## 1. The 3 Core Rules
1.  **No Public API:** A System **NEVER** returns functions. It returns a table `{ priority, Init, Dispose, system }`.
2.  **Encapsulated State:** No loose `local` variables for state. Everything mutable must be inside a `local State = {}` table.
3.  **Frozen Config:** No magic numbers ("Zombie", 100, 0.5) inside the logic. Everything must be in `local CONFIG = table.freeze({})`.

---

## 2. The Mandatory Template
All new or refactored systems MUST follow this exact structure:

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.Packages.Matter)

-- 1. IMPORTS
-- (Order: Roblox Service -> Packages -> Shared -> Server)
local Shared = ReplicatedStorage.Shared
local Components = require(Shared.components)

-- 2. CONFIGURATION (Immutable & Centralized)
-- Magic numbers and tuning constants go here.
local CONFIG = table.freeze({
    INTERVAL = 0.1,
    CHECK_RADIUS = 15,
})

-- 3. SYSTEM STATE (Mutable & Encapsulated)
-- The ONLY place allowed to store data between frames.
local State = {
    IsInitialized = false,
    LastCheckTime = 0,
    Cache = {} :: {[number]: any},
    -- Managers (Lazy Loaded)
    Managers = {} :: any, 
}

-- 4. LIFECYCLE: INIT (Runs once)
-- Can yield. Use this to load Managers or connect Events (Trove/Zap).
local function Init(world)
    if State.IsInitialized then return end
    
    -- Example: State.Managers.WaveSpawner = require(Server.managers.WaveSpawner)
    
    State.IsInitialized = true
end

-- 5. LIFECYCLE: DISPOSE (Cleanup)
-- Called before Hot-Reload or Shutdown.
local function Dispose()
    table.clear(State.Cache)
    State.IsInitialized = false
end

-- 6. MAIN LOOP (ECS)
-- MUST NEVER yield (no task.wait). Pure logic only.
local function OnStep(world)
    -- Safety Check
    if not State.IsInitialized then Init(world) end

    -- Logic...
    for id, comp in world:query(Components.MyComponent) do
        -- ...
    end
end

-- 7. EXPORT
return {
    priority = 100, -- Check GAME-ARCHITECTURE.md for priority list
    Init = Init,
    Dispose = Dispose,
    system = OnStep,
}
---

## 3. Naming Convention

Systems are **automatically named** by the bootstrapper (`init.server.luau` / `init.client.luau`) based on the ModuleScript name.

```lua
-- In init.server.luau / init.client.luau:
SystemManager.Register(system, moduleScript.Name)
```

**DO NOT** add `_name` to the export table - it's handled automatically.

---

## 4. Services vs Systems

| Concept | Purpose | State | API |
|---------|---------|-------|-----|
| **System** | ECS loop (pure logic) | Encapsulated in `State = {}` | ❌ NEVER |
| **Service** | Shared state manager | Module-level state | ✅ Public methods |

**When to create a Service:**
- Multiple systems need to read/write the same state
- External modules (handlers, managers) need access to game state
- The functionality is not ECS-loop based

**Services Location:** `src/arena/server/services/`

**Current Services:**
| Service | Purpose |
|---------|---------|
| `WaveService` | Game state, wave management |
| `SunService` | Player sun economy |
| `MutationService` | Player mutation cache |
| `PlantFoodService` | Plant Food charges |
| `StatsService` | Session statistics |
| `GridService` | Grid occupancy |
| `PlayerDataService` | Player profiles/persistence |

---

## 5. MapConfig Caching Pattern (CRITICAL)

**Problem:** `MapConfig.GetConfig()`, `MapConfig.GetZombieDirection()`, etc. can trigger `Initialize()` which uses `WaitForChild()` → **yields in OnStep = CRASH**.

**Solution:** Cache MapConfig values in `State` during `Init()`, use cached values in `OnStep()`.

```lua
-- 3. STATE
local State = {
    IsInitialized = false,
    -- Cache MapConfig values to avoid yield in OnStep
    CachedZombieDir = Vector3.zero,
    CachedGridOrigin = Vector3.zero,
    CachedCellWidth = 0,
}

-- 4. INIT (can yield)
local function Init(_world)
    if State.IsInitialized then return end
    
    -- Safe: Init phase can yield
    State.CachedZombieDir = MapConfig.GetZombieDirection()
    State.CachedGridOrigin = MapConfig.GetGridOrigin()
    State.CachedCellWidth = MapConfig.GetCellSize()
    
    State.IsInitialized = true
end

-- 5. DISPOSE
local function Dispose()
    State.IsInitialized = false
    State.CachedZombieDir = Vector3.zero
    State.CachedGridOrigin = Vector3.zero
    State.CachedCellWidth = 0
end

-- 6. ONSTEP (CANNOT yield)
local function OnStep(world)
    -- ✅ GOOD: Use cached value
    local zombieDir = State.CachedZombieDir
    
    -- ❌ BAD: This could yield if MapConfig not initialized!
    -- local zombieDir = MapConfig.GetZombieDirection()
end
```

**Note:** `MapConfig.Initialize()` is called in server bootstrap (`init.server.luau`) before the Matter loop. Functions like `MapConfig.GridToWorld()` are safe to call in OnStep after bootstrap, but caching is still preferred for consistency.
