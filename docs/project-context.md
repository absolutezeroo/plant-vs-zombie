---
project_name: 'plant-vs-zombie'
user_name: 'Clayton'
date: '2026-01-12'
game_engine: 'Roblox'
architecture_doc: '_bmad-output/game-architecture.md'
status: 'Production (Content & VFX)'
sections_completed: ['technology_stack', 'engine_rules', 'networking_rules', 'performance_rules', 'organization_rules', 'critical_rules']
---

# Project Context: Roblox PvZ Ultimate Warfare (ECS)

**Purpose:** Critical implementation rules for AI agents working on this Roblox tower defense game. This file captures unobvious patterns, performance constraints, and anti-patterns that prevent implementation mistakes.

**Status:** Production (Content & VFX) — Architecture refactoring complete. Matter V2 patterns (Isolated State, Frozen Config, Services) are fully implemented.

---

## Technology Stack & Versions

**Game Engine:**
- Roblox (Luau with `--!strict` type checking REQUIRED on all files)

**Core Framework Stack:**
- **Matter** v0.8.0+ — ECS framework (archetype-based component storage)
- **Zap** v0.5.0+ — Type-safe networking with IDL schema
- **Fusion** v0.3.0+ — Reactive UI framework (Value, Computed, Scope pattern)
- **ProfileStore** v1.0.0+ — Session-locked DataStore wrapper
- **Promise** v4.0.0+ — Async/await for Luau (data loading, teleports)
- **Trove** v1.8.0+ — Connection/instance cleanup manager
- **Sift** v0.0.11+ — Immutable table utilities (required by Matter)
- **Signal** v2.0.3+ — Custom event emitter (UI/Manager communication)
- **Cmdr** v1.12.0+ — Developer console & command framework (replaces custom debug console)

**Development Toolchain:**
- **Rojo** v7.4.0+ — Filesystem-to-Studio sync
- **Wally** v0.3.2+ — Package manager
- **Rokit** v0.1.0+ — Toolchain manager
- **Selene** — Luau linter (MANDATORY)

**Linting Rule (MANDATORY):**
- Run `selene src/` before every commit
- Fix ALL warnings and errors before testing or committing
- Do not ignore selene diagnostics — they catch syntax errors, unused variables, and shadowing

**Critical Version Constraints:
- Matter 0.8.0+ required for archetype storage performance
- Zap 0.5.0+ required for Vector3 quantization support
- All libraries MUST support Luau `--!strict` mode

---

## Roblox/Matter ECS-Specific Rules

### Matter ECS Lifecycle Rules

- Systems execute in strict priority order: Input (0-99), Simulation (100-299), Presentation (300-399), Cleanup (400+)
- NEVER assume system execution order within the same priority range
- Components are pure data structures — NEVER add methods or functions to components
- Use `world:query()` for entity iteration, NEVER cache entity references across frames

### System Priority Rules (MANDATORY)

- **SpatialHashingSystem:** Priority 100 (rebuilds lane cache FIRST)
- **TargetingSystem:** Priority 120+ (consumes fresh lane cache)
- **CombatSystem/ProjectileSystem:** Priority 140-150 (after targeting)
- **VFXSystem/AudioSystem:** Priority 300+ (after game logic)
- **GarbageCollectionSystem:** Priority 400 (LAST system, cleanup)

### Component Schema Rules

- Every component file returns a factory function: `return function() return { field = value } end`
- Components live in `src/shared/components/` (shared across server/client)
- NEVER attach behavior to components — systems own all logic
- Event components (DamageEvent, DeathEvent) are ephemeral — spawn as entities, not attached to targets

### World API Rules

- Use `world:spawn()` to create entities, `world:despawn()` to destroy
- Use `world:insert()` to add components, `world:remove()` to strip
- Use `world:contains(id)` before accessing potentially dead entities
- NEVER store World references in components — pass World through system functions only

### 🎭 ANIMATION STRATEGY (HYBRID APPROACH)

**Server Logic (STRICT):**
- Server systems MUST NOT use `Humanoid` — logic is driven purely by `GridPositionComponent` + ECS components
- Server authority relies on component data only (HealthComponent, MovementComponent, etc.)

**Client Rendering (FLEXIBLE):**
- **Preferred:** Use `AnimationController` for animations (no physics overhead, no Humanoid state machine)
- **Allowed:** Optimized `Humanoid` with `PlatformStand = true` and physics disabled for complex animation rigs
- **Rule:** Client rendering systems can use either approach based on animation complexity

**Performance Guidelines:**
- `AnimationController` has ~0.1ms overhead per entity (preferred for 200+ entities)
- Optimized `Humanoid` (PlatformStand, no physics) has ~0.3ms overhead per entity
- At 150+ entities, prefer `AnimationController` to maintain 60 FPS

**Why Hybrid:** Full animation support (Roblox animations require Humanoid or AnimationController) while maintaining server authority and performance targets.

### Logic vs. Visuals Separation (Server Authority)

- Server systems MUST NOT access workspace or Roblox Instances directly
- Server logic updates Component data ONLY (HealthComponent, GridPositionComponent, etc.)
- Client systems read Component data and update workspace Instances (Parts, Models, GUIs)
- Example: CombatSystem (server) sets `Health.Current = 0`; VFXSystem (client) plays death animation

### Matter Hot-Reloading Compliance

- Systems MUST be stateless outside their loop function
- NEVER use top-level mutable variables in system files (`local cache = {}` at file level = BAD)
- State belongs in Components or Services, not System file scope
- This enables Matter's hot-reloading during development without corruption

---

## Networking & Zap-Specific Rules

### Zap Packet Design Rules

- Define all packet schemas in `src/shared/network/packets.zap` using Zap IDL syntax
- Use Vector3 quantization for position data: `pos: vec3(i16)` (saves ~60% bandwidth vs f32)
- Server MUST validate ALL client packets — NEVER trust client data for gameplay state
- Client sends requests (PlacePlant, SelectCard), server sends authoritative state updates

### Client Prediction Rules (Ghost Unit Pattern)

- Client spawns "ghost" entities with `GhostComponent` for optimistic prediction
- Ghost entities have `GhostComponent { RequestId, TimeCreated, Cost }` for reconciliation
- Server response triggers swap (success) or rollback (failure) via RequestId matching
- Ghost timeout: 5 seconds maximum before auto-rollback (assume packet loss)

### Server Authority Boundaries (Anti-Cheat)

- Server owns ALL authoritative state: Health, GridOccupancy, PlayerSun, WaveProgress
- Client NEVER sends "set health" or "deduct sun" — sends "place plant at (X,Y)" with validation
- Server validates: sun cost, grid availability, cooldowns BEFORE accepting placement
- Client prediction can be wrong — server response is final truth

### Replication System Rules

- ReplicationSystem (server, Priority 200) broadcasts entity updates via Zap
- Only replicate entities with `ReplicatedComponent` — not all entities need sync
- Use priority queues: combat events > movement > cosmetic updates
- Bandwidth cap: <50 KB/s average enforced by NetworkConfig.lua throttling

### Reconciliation Rules

- Client PredictionSystem listens for server responses matching RequestId
- On success: destroy ghost entity silently (server entity already replicated, seamless swap)
- On failure: destroy ghost, refund resources, play error FX (red X particle + bonk sound)
- NEVER let ghost entities persist beyond 5 seconds (GhostTimeoutSystem enforces)

### NetworkConfig Constants

```lua
-- src/shared/config/NetworkConfig.lua
TICK_RATE = 60              -- Server tick rate (Hz)
BANDWIDTH_CAP = 50000       -- Bytes per second (average)
BANDWIDTH_PEAK = 60000      -- Bytes per second (absolute max)
GHOST_TIMEOUT = 5.0         -- Seconds before ghost auto-rollback
RECONCILE_BUFFER = 0.1      -- Seconds of input buffer for rollback
```

### Zap Event Naming

- Use PascalCase for events: `PlacePlant`, `SpawnWave`, `DealDamage`
- Server callbacks: `ZapServer.PlacePlant:SetCallback(function(player, request) ... end)`
- Client listeners: `ZapClient.PlacePlantResponse:On(function(response) ... end)`
- ALWAYS include `RequestId` in request/response pairs for reconciliation

---

## Async & Cleanup Rules (Promise + Trove)

### Promise Usage Rules (MANDATORY for Async)

**Doc:** https://eryn.io/roblox-lua-promise/api/Promise

- Use `Promise` for ALL async operations: data loading, teleports, HTTP requests
- NEVER use raw `pcall` loops — use `Promise.retry(callback, maxAttempts, delay)` instead
- NEVER use `wait()` or `task.wait()` in ECS systems — systems must be synchronous
- Use `Promise:andThen()` for chaining, `Promise:catch()` for error handling
- Use `Promise.all({...})` for parallel async operations

```lua
-- ✅ CORRECT: Promise for data loading
local function loadPlayerData(player: Player)
    return Promise.new(function(resolve, reject)
        local profile = PlayerStore:StartSessionAsync(`Player_{player.UserId}`)
        if profile then
            resolve(profile)
        else
            reject("Failed to load profile")
        end
    end)
end

loadPlayerData(player)
    :andThen(function(profile)
        -- Profile loaded successfully
    end)
    :catch(function(err)
        Logger.Error("PlayerData", `Failed: {err}`)
    end)

-- ✅ CORRECT: Promise.retry for network operations
Promise.retry(function()
    return TeleportService:TeleportAsync(placeId, {player})
end, 3, 2) -- 3 attempts, 2 second delay

-- ❌ WRONG: Raw pcall loop
for i = 1, 3 do
    local success = pcall(function()
        TeleportService:TeleportAsync(placeId, {player})
    end)
    if success then break end
    task.wait(2)
end
```

### Trove Usage Rules (MANDATORY for Connections)

**Doc:** https://sleitnick.github.io/RbxUtil/api/Trove/

- Use `Trove` for ALL `:Connect()` calls in Services, Controllers, and Managers
- NEVER use raw `:Connect()` without Trove (causes memory leaks)
- One `_trove` per module/class, call `_trove:Destroy()` in cleanup
- Use `_trove:Connect(signal, callback)` instead of `signal:Connect(callback)`
- Use `_trove:Add(instance)` for instances that need cleanup

```lua
-- ✅ CORRECT: Trove pattern in Services
local Trove = require(Packages:WaitForChild("Trove"))

local _trove = Trove.new()

function MyService.Initialize()
    _trove:Connect(Players.PlayerAdded, onPlayerAdded)
    _trove:Connect(Players.PlayerRemoving, onPlayerRemoving)
    _trove:Connect(RunService.Heartbeat, onHeartbeat)
end

function MyService.Dispose()
    _trove:Destroy()
end

-- In BindToClose or cleanup
game:BindToClose(function()
    _trove:Destroy()
    -- Other cleanup...
end)

-- ❌ WRONG: Raw :Connect without cleanup
Players.PlayerAdded:Connect(onPlayerAdded) -- Memory leak!
```

### Exceptions (No Trove Required)

- **One-shot connections:** `tween.Completed:Connect()`, `sound.Ended:Connect()` (auto-disconnect)
- **Generated code:** `src/shared/network/generated/*.luau` (Zap manages these)
- **ProfileStore API:** `profile.OnSessionEnd:Connect()` (library-managed)
- **Trove:Add pattern:** When storing connection in variable first, use `_trove:Add(conn)`

### Sift for Immutability (Matter Requirement)

**Doc:** https://cxmeel.github.io/sift/api/Sift

- Use Sift for ALL table manipulations in ECS contexts
- Matter requires immutable component updates — NEVER mutate tables directly
- Use `Sift.Array.push()` instead of `table.insert()`
- Use `Sift.Array.removeIndex()` instead of `table.remove()`
- Use `Sift.Dictionary.merge()` for component updates

```lua
-- ✅ CORRECT: Immutable array operations
local Sift = require(Packages.Sift)

local items = {"a", "b", "c"}
local newItems = Sift.Array.push(items, "d")  -- ["a", "b", "c", "d"]
local filtered = Sift.Array.filter(items, function(v) return v ~= "b" end)

-- ✅ CORRECT: Immutable component update in Matter
world:insert(entityId, HealthComponent(Sift.Dictionary.merge(
    world:get(entityId, HealthComponent),
    { Current = newHealth }
)))

-- ❌ WRONG: Direct mutation
local data = world:get(entityId, HealthComponent)
data.Current = newHealth  -- BREAKS MATTER CHANGE DETECTION!
```

### Signal for Custom Events

**Doc:** https://sleitnick.github.io/RbxUtil/api/Signal/

- Use `Signal` instead of `BindableEvent` for internal communication
- Use Signal for UI Controller ↔ Manager communication (non-ECS)
- Always clean up Signal connections with Trove

```lua
-- ✅ CORRECT: Signal pattern
local Signal = require(Packages.Signal)

local MyService = {}
MyService.OnDataChanged = Signal.new()

function MyService.UpdateData(player, newData)
    -- ... update logic
    MyService.OnDataChanged:Fire(player, newData)
end

-- Consumer with Trove cleanup
_trove:Connect(MyService.OnDataChanged, function(player, data)
    -- Handle event
end)
```

### Frame Budget Rules (HARD CONSTRAINTS)

- Total frame budget: **15ms maximum** (60 FPS target)
- Input Phase (0-99): 1ms budget
- Simulation Phase (100-299): 10ms budget
- Presentation Phase (300-399): 3ms budget
- Cleanup Phase (400+): 1ms budget
- SafetySystem monitors frame time and triggers emergency protocols at 16.6ms

### Entity Cap Enforcement

- **HARD CAP: 200 active entities** simultaneously in Matter World
- Target: 150 entities (25% safety margin for performance spikes)
- Breakdown: 100-120 zombies, 45 plants max (full 9×5 grid), 25 projectiles, 10 resources
- SafetySystem MUST block entity spawning when cap reached

### Memory Management Rules

- Maximum RAM: 600 MB total allocation
- Warning threshold: 500 MB (80%, logs warning to ErrorHandler)
- Emergency GC trigger: 550 MB (force garbage collection)
- Crash prevention: 600 MB (force-end match, save player data)
- PerformanceMonitorSystem polls memory every 10 seconds (NOT every frame)

### Lane-Based Spatial Hashing (O(1) Targeting)

- ALWAYS use `LaneCache.GetEntitiesInLane(row)` for targeting queries
- NEVER iterate `world:query()` inside targeting logic (O(N²) death)
- LaneCache rebuilds from scratch every frame (Priority 100, "Rebuild Don't Maintain" philosophy)
- Iterating 10-40 zombies per lane is faster than maintaining dirty flags

### Entity Pooling (Mandatory)

- Pre-spawn 200 inactive entities at server boot with `InactiveTag()`
- NEVER use `world:spawn()` during gameplay after initialization
- Use `EntityPool.Acquire()` to recycle inactive entities
- Use `EntityPool.Release()` to return entities to pool (strip components, add InactiveTag)
- Pool exhaustion is a fatal error (should never happen with 200 cap)

### Logging Performance Rules

- NEVER log inside loops or per-entity iteration
- NEVER log every frame (max once per second for non-critical info)
- Use `Logger.Debug()` for hot paths (stripped in production builds)
- PerformanceMonitorSystem logs throttled to every 10 seconds
- Critical errors use `ErrorHandler.Report()` (always logged regardless of throttle)

### VFX/Audio Dynamic LOD

- At 50+ entities: disable particle trails, reduce audio channels to 8
- At 100+ entities: disable all non-critical VFX, reduce audio to 4 channels
- At 150+ entities: emergency mode — disable all cosmetic effects
- LODSystem (Priority 310) checks entity count and adjusts quality settings

### Luau Performance Patterns

- Use `table.clear(t)` instead of creating new tables (recycles memory)
- Avoid `table.insert()` in hot loops — use direct indexing: `t[#t+1] = value`
- Use local variables for frequently accessed globals: `local math_floor = math.floor`
- NEVER use `pairs()` or `ipairs()` — use numeric for loops with `#table`

### Sacred Constants (IMMUTABLE — Performance Tuned)

```lua
-- src/shared/config/GridConfig.lua
CELL_SIZE = 6          -- Studs per grid cell (DO NOT CHANGE)
GRID_COLUMNS = 9       -- 9×5 grid layout (DO NOT CHANGE)
GRID_LANES = 5         -- 5 lanes for spatial hashing (DO NOT CHANGE)

-- src/shared/config/PerformanceConfig.lua
ENTITY_CAP = 200       -- Hard cap enforced by SafetySystem
MEMORY_LIMIT = 600     -- MB, emergency GC at 550 MB
FRAME_BUDGET = 15      -- Milliseconds per frame (60 FPS)
BANDWIDTH_CAP = 50000  -- Bytes per second average
```

### What Agents MUST NEVER Do

- ❌ NEVER use `wait()` or `task.wait()` in systems (breaks 60 Hz loop)
- ❌ NEVER spawn entities during gameplay (use EntityPool only)
- ❌ NEVER iterate all entities for targeting (use LaneCache)
- ❌ NEVER log in per-entity loops (massive frame time spikes)
- ❌ NEVER create tables in hot paths (use table.clear() for reuse)
- ❌ NEVER access workspace on server (server logic = component data only)

---

## Code Organization & Naming Rules

### Project Architecture (Multi-Place)

**Pattern:** Monorepo Multi-Place (Lobby + Arena) with Domain-Driven organization.

```
src/
├── arena/              # Arena place (gameplay)
│   ├── server/         # Server-authoritative systems
│   │   └── systems/    # Domain-organized systems
│   │       ├── combat/     # BossSystem, CombatSystem, ProjectileSystem, etc.
│   │       ├── core/       # SafetySystem, PerformanceMonitor, EventCleanup
│   │       ├── economy/    # SunCollection, SunflowerProduction, SunSpawn
│   │       ├── mutations/  # Burn, Freeze, Poison, Lightning, etc. (8 systems)
│   │       ├── units/      # Placement, Movement, Death, Mushroom
│   │       └── wave/       # WaveManagerSystem
│   └── client/         # Client presentation
│       └── systems/    # Domain-organized systems
│           ├── input/      # GhostPreviewSystem
│           ├── presentation/ # VFXAudioSystem
│           └── rendering/  # PlantRender, ZombieRender, Projectile, Sun, Grid
├── lobby/              # Lobby place (menus, deck builder)
│   ├── server/
│   └── client/
└── shared/             # Cross-realm shared code
    ├── components/     # Domain-organized components (init.luau as registry)
    │   ├── core/       # Position, Health, Movement, Owner, Tags
    │   ├── combat/     # Armed, Projectile, Slow, Target, Splash, Stun, etc.
    │   ├── units/      # PlantType, ZombieType, Ghost, Jumping, Sleeping
    │   ├── economy/    # Sun, Coin
    │   ├── events/     # DamageEvent, DeathEvent, SpawnEvent, etc.
    │   └── mutations/  # Burn, Freeze, Poison, Lightning, Lifesteal, etc.
    ├── config/         # Configuration modules (GridConfig, PerformanceConfig)
    ├── data/           # Game data (PlantData, ZombieData, MutationData, etc.)
    ├── network/        # Zap schema (packets.zap + generated/)
    ├── services/       # PlayerDataCore, TeleportDataHandler
    ├── signals/        # Custom Signal events
    ├── ui/             # Shared Fusion components (LoaderUI)
    ├── utils/          # Utilities (NEW)
    │   ├── SystemManager.luau      # System lifecycle management
    │   ├── Logger.luau             # Structured logging with throttling
    │   ├── ErrorHandler.luau       # Hybrid error handling
    │   ├── EntityPool.luau         # Pre-spawned entity pool
    │   ├── ServiceLoader.luau      # Service initialization orchestration
    │   ├── AttachmentUtils.luau    # Attachment-based positioning
    │   ├── GridUtils.luau          # Grid coordinate calculations
    │   ├── LaneCache.luau          # Lane-based spatial hashing
    │   └── MathUtils.luau          # Math helpers
    └── Types.luau      # Shared type definitions
```

### File Location Rules (Non-Negotiable)

- **Server-Only Code:** `src/server/` — authority validation, ProfileStore operations, wave generation
- **Client-Only Code:** `src/client/` — input handling, VFX/Audio, UI rendering, prediction
- **Shared Code:** `src/shared/` — ONLY components (pure data), config modules, utilities, type definitions
- **Rojo Mapping:** Server → ServerScriptService, Client → StarterPlayerScripts, Shared → ReplicatedStorage

### System Location Rules

- All server systems: `src/server/systems/SystemName.lua`
- All client systems: `src/client/systems/SystemName.lua`
- Singleton services: `src/server/services/ServiceName.lua`
- UI controllers: `src/client/controllers/ControllerName.lua`

### File Naming Conventions (Strict)

- ECS Systems: `PascalCase + "System.lua"` (e.g., `GridSystem.lua`, `WaveSystem.lua`)
- Services: `PascalCase + "Service.lua"` (e.g., `DataService.lua`, `NetworkService.lua`)
- Controllers: `PascalCase + "Controller.lua"` (e.g., `HUDController.lua`)
- Components: `PascalCase + "Component.lua"` (e.g., `HealthComponent.lua`)
- Config Modules: `PascalCase + "Config.lua"` (e.g., `GridConfig.lua`, `PerformanceConfig.lua`)
- Utilities: `PascalCase.lua` (e.g., `ErrorHandler.lua`, `Logger.lua`)

### Code Style Rules

- EVERY file MUST start with `--!strict` pragma (first line, no exceptions)
- All function parameters MUST have type annotations: `function foo(x: number, y: string): boolean`
- All component fields MUST be typed: `{ Health: number, MaxHealth: number }`
- Use `camelCase` for functions and local variables
- Use `UPPER_SNAKE_CASE` for constants
- Use `PascalCase` for types and ECS queries

### Module Export Pattern

```lua
--!strict

local MySystem = {}

function MySystem.system(world)
    -- System logic here
end

MySystem.priority = 100 -- Document priority number

return MySystem
```

### Component Export Pattern

```lua
--!strict

return function()
    return {
        FieldName: 0,      -- Default value
        AnotherField: "",  -- Type inference via default
    }
end
```

### Component Registry Pattern (NEW - Central Import)

**File:** `src/shared/components/init.luau`

All components are registered in the central init.luau file:

```lua
-- Import from registry
local Components = require(Shared.components)

-- Access components directly
local HealthComponent = Components.HealthComponent
local PositionComponent = Components.PositionComponent
local Tags = Components.Tags

-- Tag usage
world:spawn(
    Tags.PlantTag(),
    HealthComponent({ Current = 100, Max = 100 }),
    PositionComponent({ X = 0, Y = 0 })
)
```

**Available Tags (from Tags.luau):**
- `PlantTag` - marks entity as a plant
- `ZombieTag` - marks entity as a zombie
- `ProjectileTag` - marks entity as a projectile
- `ResourceTag` - marks entity as a resource (sun drop)
- `InactiveTag` - marks entity as pooled/inactive
- `ReplicatedTag` - marks entity for network replication

### Config Module Pattern (Frozen/Immutable)

```lua
--!strict

local GridConfig = {
    CELL_SIZE = 6,
    GRID_COLUMNS = 9,
    GRID_LANES = 5,
}

return table.freeze(GridConfig) -- Make immutable
```

### Architectural Boundary Rules (Anti-Cheat Critical)

- NEVER put validation logic in `src/shared/` — server-only only
- NEVER put ProfileStore schemas in `src/shared/` — server-only only
- NEVER put balance formulas with anti-cheat significance in `src/shared/`
- Components in `src/shared/` are data-only — no behavior, no secrets

### Import Pattern (Rojo Paths)

```lua
-- Server code
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.Packages.Matter)
local GridConfig = require(ReplicatedStorage.Shared.Config.GridConfig)

-- Client code
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HUDController = require(script.Parent.Controllers.HUDController)
```

### System Priority Documentation (Mandatory in File)

```lua
-- Every system file MUST document its priority
MySystem.priority = 100 -- WHY: Rebuilds spatial cache before targeting

-- Systems without explicit priority default to 0 (runs first)
```

---

## Critical Don't-Miss Rules (Anti-Patterns & Gotchas)
### ⚔️ MUTATION SYSTEM ARCHITECTURE (NEW)

**19 mutations defined in `MutationData.luau`**, processed by 8 specialized systems:

| System | Component | Effect |
|--------|-----------|--------|
| BurnDamageSystem | BurningComponent | DoT damage over time |
| ChainLightningSystem | ChainLightningComponent | Chain to nearby enemies |
| FreezeSystem | FrozenComponent | Slow/freeze movement |
| LifestealSystem | LifestealComponent | Heal on damage dealt |
| MutationApplySystem | MutationsComponent | Apply mutations from data |
| PoisonCloudSystem | PoisonCloudComponent | AoE poison damage |
| SplashDamageSystem | SplashDamageComponent | AoE splash on hit |
| SunOnKillSystem | SunOnKillComponent | Generate sun on kill |

**Mutation Application Pattern:**
```lua
-- Mutations are applied via MutationsComponent
world:insert(plantId, MutationsComponent({
    ActiveMutations = { "Burn", "Splash" },
    MutationData = MutationData.Burn,
}))
```

---
### ❌ FATAL MISTAKES (Will Break "The Swarm" Performance)

1. **Using Humanoid/HumanoidRootPart for Plants or Zombies**
   - Why fatal: Humanoid overhead makes 200 entities impossible (drops to 20 FPS)
   - Correct: Use GridPositionComponent + MovementSystem for logic, separate visual Models

2. **Iterating All Entities for Targeting**
   - Why fatal: O(N²) complexity (100 plants × 100 zombies = 10,000 checks per frame)
   - Correct: ALWAYS use `LaneCache.GetEntitiesInLane(row)` for O(1) lookups

3. **Spawning Entities During Gameplay**
   - Why fatal: Causes GC pressure, frame spikes, potential pool exhaustion
   - Correct: ONLY use `EntityPool.Acquire()` to recycle pre-spawned entities

4. **Accessing workspace on Server Systems**
   - Why fatal: Breaks server authority, creates instance dependencies, kills performance
   - Correct: Server updates Components ONLY, client reads Components to update workspace

5. **Logging in Per-Entity Loops**
   - Why fatal: 100 entities × 60 FPS = 6,000 logs/sec crashes Studio/production
   - Correct: Log once per system iteration max, throttle to 10 seconds for monitoring

### 🔥 ROBLOX-SPECIFIC GOTCHAS

1. **RemoteEvent/RemoteFunction Instead of Zap**
   - Gotcha: Manual remotes bypass type safety and quantization
   - Correct: Define ALL network packets in `packets.zap` schema

2. **Using :GetChildren() in Loops**
   - Gotcha: Returns new array every call, causes GC pressure
   - Correct: Cache children arrays or use Matter queries

3. **Not Checking world:contains() Before Access**
   - Gotcha: Entity may be despawned between query and component access
   - Correct: Always `if world:contains(id) then ... end` when using cached entity IDs

4. **Mutating Config Tables at Runtime**
   - Gotcha: Shared configs become inconsistent between server/client
   - Correct: Use `table.freeze()` on all config modules

5. **Using task.spawn() or coroutines in Systems**
   - Gotcha: Breaks 60 Hz deterministic loop, creates race conditions
   - Correct: Systems MUST be synchronous, complete work in one frame

### ⚠️ MATTER ECS ANTI-PATTERNS

1. **Storing Entity References in Components**
   - Wrong: `TargetComponent({ Target = zombieEntity })` — entity is table, not ID
   - Correct: `TargetComponent({ Target = zombieEntityId })` — store numeric ID only

2. **Attaching DamageEvent to Target Entity**
   - Wrong: `world:insert(zombieId, DamageEvent({ Amount = 20 }))` — breaks multi-hit
   - Correct: `world:spawn(DamageEvent({ Target = zombieId, Amount = 20 }))` — event is entity

3. **Top-Level Mutable State in System Files**
   - Wrong: `local cache = {}` at file level — breaks Matter hot-reloading
   - Correct: State in Components or Services, Systems are stateless functions

4. **Assuming System Execution Order Within Same Priority**
   - Wrong: CombatSystem (150) depending on ProjectileSystem (140) running first
   - Correct: Use different priorities (140 vs 150) for guaranteed order

5. **Not Cleaning Up Event Components**
   - Wrong: DamageEvent persists, gets processed multiple times
   - Correct: GarbageCollectionSystem (Priority 400) despawns ALL event entities

### 🎯 GHOST PREDICTION EDGE CASES

1. **Not Setting Ghost Timeout**
   - Edge case: Packet loss causes ghost to persist forever
   - Correct: GhostTimeoutSystem despawns ghosts after 5 seconds

2. **Not Checking Target Exists During Rollback**
   - Edge case: Server rejected placement, but cell now occupied by zombie
   - Correct: Check `GridState[x][y].Occupied` before showing error FX

3. **Not Refunding Resources on Rollback**
   - Edge case: Client shows 0 sun, but server rejected purchase
   - Correct: `updateSunDisplay(currentSun + ghost.Cost)` on failure response

4. **Assuming Ghost and Server Entity Don't Coexist**
   - Edge case: Server entity replicates before success response arrives
   - Correct: Destroy ghost silently when response arrives (seamless swap)

### 📏 SACRED CONSTANTS (NEVER MUTATE)

These values are performance-tuned and balance-calibrated. Changing them breaks gameplay:

```lua
-- NEVER change these values in code
CELL_SIZE = 6          -- Grid math depends on this
GRID_COLUMNS = 9       -- All wave budgets calibrated for 45 plant slots
GRID_LANES = 5         -- Lane hashing assumes 5 lanes
ENTITY_CAP = 200       -- Pool size, safety system enforcement
MEMORY_LIMIT = 600     -- iPhone 11 crash threshold
```

If you need to change these, update `GridConfig.lua` or `PerformanceConfig.lua` and retest ENTIRE game.

### 🛡️ ANTI-CHEAT CRITICAL

- NEVER expose validation logic to client (enables exploits)
- NEVER trust client data for gameplay state (health, resources, grid occupancy)
- NEVER put balance formulas in `src/shared/` (exploiters can read them)
- ALWAYS validate server-side: sun cost, cooldowns, grid availability
- Ghost prediction can be wrong — server response is ALWAYS final authority

---

## Quick Reference for AI Agents

**Before implementing ANY system:**
1. Check architecture document for system location and priority
2. Verify component schemas exist in `src/shared/components/`
3. Confirm config constants are in appropriate Config module
4. Review this file for relevant anti-patterns
5. Ensure `--!strict` pragma and type annotations present

**When stuck:**
- Architecture doc has 10 implementation patterns with code examples
- This context file captures edge cases architecture doc doesn't cover
- Sacred constants are IMMUTABLE — never hardcode or mutate them
- Server authority is non-negotiable — client prediction must gracefully rollback

**Performance checks:**
- Am I logging in a loop? (NO)
- Am I spawning entities during gameplay? (NO, use pool)
- Am I iterating all entities for targeting? (NO, use LaneCache)
- Am I accessing workspace on server? (NO, components only)
- Is my system priority documented? (YES, always)
