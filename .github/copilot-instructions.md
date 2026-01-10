# Instructions for GitHub Copilot - Garden Swarm Project

I am working on a Roblox Project with a **Monorepo Multi-Place Architecture** (Lobby + Arena).
**Core Principle:** Do not reinvent the wheel. Use the Roblox Engine API (C++) and the specific libraries below.

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

### 3. System Lifecycle (SystemManager Pipeline)
* **Pattern:** Systems have `Init` (can yield) and `OnStep` (cannot yield).
    ```lua
    local MySystem = {}
    MySystem.priority = 100

    function MySystem.Init(world)
        -- Safe to WaitForChild or require configs here
        MySystem.Config = require(Shared.config.SomeConfig)
    end

    function MySystem.OnStep(world, dt)
        -- PURE LOGIC ONLY. No yields.
    end

    return MySystem
    ```

### 4. Data-Driven Content
* **Rule:** Never hardcode stats (Damage, Health, Speed).
* **Source:** Always require from `src/shared/data/` (e.g., `PlantData`, `ZombieData`, `DifficultyData`).

---

## 🏗️ CODING STANDARDS

* **Strict Typing:** Every file MUST start with `--!strict`. All functions must have type annotations.
* **Directory Awareness:**
    * `src/shared/network/packets.zap` -> Source of truth for networking.
    * `src/shared/components/` -> All component definitions.
    * `src/arena/server/systems/` -> Server Logic (Authority).
    * `src/arena/client/systems/` -> Visuals (Prediction/Rendering).