# Instructions for GitHub Copilot - Garden Swarm Project

I am working on a Roblox Project with a **Monorepo Multi-Place Architecture** (Lobby + Arena).
**Core Principle:** Do not reinvent the wheel. Use the Roblox Engine API (C++) and the specific libraries below.

**IMPORTANT:** All ECS Systems MUST strictly follow the architecture defined in `docs/SYSTEM-STANDARD.md`. This is the single source of truth for system structure.

---

## 📚 Documentation Sources of Truth (STRICT ADHERENCE)
For every implementation, refer to these specific API docs. Do not hallucinate APIs.

1.  **Data Persistence: ProfileStore**
    * **Doc:** https://madstudioroblox.github.io/ProfileStore/api/
    * **Rule:** Use strict typing. Always handle `Profile:Release()` properly before teleporting. Use `Mock` mode for Studio testing.

2.  **UI Framework: Fusion 0.3 (NOT 0.2)**
    * **Doc:** https://elttob.uk/Fusion/0.3/api-reference/
    * **Rule:** We are using Fusion 0.3. Do NOT use `Fusion.State`. Use `Fusion.Value`, `Fusion.Computed`, and `Fusion.Scope`. Use `Fusion.New` syntax.

3.  **ECS Engine: Matter**
    * **Doc:** https://matter-ecs.github.io/matter/api/Matter
    * **Rule:** Never mutate components directly. Use `world:insert(id, Component({ patched_data }))`. Components are pure data.

4.  **Table Utilities: Sift**
    * **Doc:** https://cxmeel.github.io/sift/api/Sift
    * **Rule:** Use Sift for all table manipulations (Dictionaries/Arrays) to maintain immutability required by Matter. Ex: `Sift.Dictionary.merge`, `Sift.Array.filter`.

5.  **Async Logic: Promise**
    * **Doc:** https://eryn.io/roblox-lua-promise/api/Promise
    * **Rule:** Use Promises for ALL async operations (Data loading, Teleports, HTTP).
    * **Pattern:** `Promise.new() :andThen() :catch()` for chaining.
    * **Retry:** Use `Promise.retry(fn, maxAttempts, delay)` instead of pcall loops.
    * **NEVER** use `wait()` or `task.wait()` in ECS systems.

6.  **Networking: Zap**
    * **Doc:** https://zap.redblox.dev/usage/generated-api.html
    * **Rule:** Never edit `generated.luau`. Use the generated API strictly for typesafe networking.

7.  **Cleanup: Trove**
    * **Doc:** https://sleitnick.github.io/RbxUtil/api/Trove/
    * **Rule:** Use Trove for ALL `:Connect()` calls in Services/Controllers.
    * **Pattern:** `local _trove = Trove.new()` then `_trove:Connect(event, callback)`.

8.  **Events: Signal**
    * **Doc:** https://sleitnick.github.io/RbxUtil/api/Signal/
    * **Rule:** Use Signal instead of BindableEvent for internal communication.

---

## 🚀 ROBLOX ENGINE MASTERY (PERFORMANCE RULES)
**Rule:** Do not write complex Lua math if a Roblox C++ API exists.

### 1. Spatial Queries vs. Math Loops
* **❌ BAD:** Looping through all entities to check `(pos1 - pos2).Magnitude < 10`.
* **✅ GOOD (Physics):** Use `workspace:GetPartBoundsInBox()`, `workspace:GetPartsInPart()`, or `WorldRoot:Raycast()`.
* **✅ GOOD (Game Logic):** Use the custom **`LaneCache`** for targeting (See below).

### 2. Geometry-Blind Code (Attachment Pattern)
* **Rule:** Never hardcode Vector3 offsets (e.g., `Vector3.new(0, 5, 0)`). Visuals change, code shouldn't break.
* **✅ GOOD:** Use **Attachments**. Look for attachments named "Muzzle", "Overhead", or "Center" inside the model.
    ```lua
    local AttachmentUtils = require(Shared.utils.AttachmentUtils)
    local muzzlePos = AttachmentUtils.GetWorldPosition(model, "Muzzle")
    ```

### 3. Bulk Operations
* **Rule:** Minimize Crossing the C++/Lua Bridge.
* **✅ GOOD:** Use `workspace:BulkMoveTo(parts, cframes)` instead of setting CFrames one by one in a loop.
* **✅ GOOD:** Use `CollectionService` for tagging instead of checking names.

---

## 🧠 GARDEN SWARM SPECIALTIES (PROJECT RULES)

### 1. The "No Humanoid" Rule
* **STRICT:** Never use `Humanoid` or `HumanoidRootPart` for zombies or plants.
* **Alternative:** Use `GridPositionComponent` + `MovementSystem`. Visuals are just anchored Parts/MeshParts moved via CFrame.

### 2. Targeting Strategy (O(1) Complexity)
* **❌ BAD:** Iterating `world:query()` to find targets.
* **✅ GOOD:** Use **`LaneCache`**.
    ```lua
    local LaneCache = require(Shared.utils.LaneCache)
    -- Get only zombies in the same row
    local zombies = LaneCache.GetEntitiesInLane(row)
    ```

### 3. Entity Health Manipulation (ECSUtils)
* **❌ BAD:** Direct `world:insert(id, HealthComponent({...}))` for damage/heal.
* **✅ GOOD:** Use **`ECSUtils`** for consistent behavior.
    ```lua
    local ECSUtils = require(Shared.utils.ECSUtils)
    local actualDamage, isDead = ECSUtils.DamageEntity(world, zombieId, 50, Components)
    ECSUtils.KillEntity(world, zombieId, Components)  -- Instant kill
    ECSUtils.BoostHealth(world, plantId, 100, Components)  -- Armor boost
    ```

### 4. Random Number Generation (ChanceUtils)
* **❌ BAD:** Raw `math.random()` calls scattered everywhere.
* **✅ GOOD:** Use **`ChanceUtils`** for consistent RNG.
    ```lua
    local ChanceUtils = require(Shared.utils.ChanceUtils)
    if ChanceUtils.Roll(0.3) then  -- 30% chance
    local lane = ChanceUtils.RandomLane()
    local offset = ChanceUtils.RandomOffset(2)  -- -2 to +2
    local item = ChanceUtils.PickRandom(itemArray)
    ```

### 5. Visual Effects (VFXUtils)
* **❌ BAD:** Creating anchor Parts and cloning emitters inline.
* **✅ GOOD:** Use **`VFXUtils`** for standardized VFX patterns.
    ```lua
    local VFXUtils = require(Shared.utils.VFXUtils)
    VFXUtils.CloneAndEmit(particleEmitter, position)  -- Clone, emit, auto-cleanup
    VFXUtils.PlayFromModel(model, "Death")  -- Play VFX from model's VFX folder
    VFXUtils.AttachIdleVFX(model)  -- Persistent idle particles
    ```

### 6. System Lifecycle (SystemManager Pipeline)
* **Pattern:** Systems have `Init` (can yield) and `OnStep` (cannot yield).
* **Reference:** See `src/shared/utils/SystemManager.luau` for implementation details.

### 7. Data-Driven Content
* **Rule:** Never hardcode stats (Damage, Health, Speed).
* **Source:** Always require from `src/shared/data/` (e.g., `PlantData`, `ZombieData`, `DifficultyData`).

### 8. Asset-First Visuals (NO `Instance.new` for Art)
* **STRICT:** Never create visual elements (Parts, ParticleEmitters, Beams, Lights, Models) using `Instance.new()` in code.
* **✅ GOOD:** Create the asset in Roblox Studio, store it in `ReplicatedStorage.Assets`, and `Clone()` it.
    ```lua
    -- ❌ BAD:
    local p = Instance.new("Part")
    p.Color = Color3.new(1,0,0)

    -- ✅ GOOD:
    local p = ReplicatedStorage.Assets.Projectiles.Pea:Clone()
    ```
* **Why:** Artists must be able to change visuals without touching code.

---

## 🏗️ CODING STANDARDS

* **Strict Typing:** Every file MUST start with `--!strict`. All functions must have type annotations.
* **Linting (MANDATORY):**
    * **Action:** Run `selene src/` (or `rokit run selene src/`) after every modification.
    * **Rule:** Fix ALL warnings/errors reported by Selene before testing or committing. Do not ignore them.
    * **Goal:** Catch syntax errors, unused variables, and shadowing instantly.
* **Directory Awareness:**
    * `src/shared/network/packets.zap` -> Source of truth for networking.
    * `src/shared/components/` -> All component definitions.
    * `src/arena/server/systems/` -> Server Logic (Authority).
    * `src/arena/client/systems/` -> Visuals (Prediction/Rendering).